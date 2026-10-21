import Foundation
import CryptoKit
// import AppleTVLogging

/// Drives the Companion pair-setup (SRP) and pair-verify (ECDH) state machines.
///
/// Owns `HAPPairing`, `CompanionPairVerify`, and the pending-M2 buffer. Knows
/// nothing about sockets, `ConnectionState`, or session logic — it communicates
/// entirely via the `PairingFlowDelegate` callbacks.
///
/// Lifetime: one instance per `CompanionConnection`, reset via `reset()` between
/// connections. `@MainActor` so it shares the connection's isolation domain.
@MainActor
public final class PairingFlow {

    // MARK: - Delegate

    /// Callbacks the flow fires back to `CompanionConnection`.
    public struct Delegate {
        /// Send a raw Companion frame (e.g. `.psStart`, `.psNext`, `.pvStart`, `.pvNext`).
        public var sendFrame: (CompanionFrame.FrameType, Data) -> Void
        /// The flow needs to change the connection's published state.
        public var setState: (ConnectionState) -> Void
        /// Pair-verify M4 succeeded — install these session keys into the transport.
        public var installKeys: (SymmetricKey, SymmetricKey) -> Void
        /// Pair-setup M6 completed successfully — reconnect to start pair-verify.
        public var reconnect: (AppleTVDevice) -> Void
        /// Save credentials after successful pair-setup.
        public var saveCredentials: (PairingCredentials, String) -> Void
        /// Delete credentials after a definitive pair-verify server rejection.
        public var deleteCredentials: (String) -> Void

        public init(
            sendFrame: @escaping (CompanionFrame.FrameType, Data) -> Void,
            setState: @escaping (ConnectionState) -> Void,
            installKeys: @escaping (SymmetricKey, SymmetricKey) -> Void,
            reconnect: @escaping (AppleTVDevice) -> Void,
            saveCredentials: @escaping (PairingCredentials, String) -> Void,
            deleteCredentials: @escaping (String) -> Void
        ) {
            self.sendFrame = sendFrame
            self.setState = setState
            self.installKeys = installKeys
            self.reconnect = reconnect
            self.saveCredentials = saveCredentials
            self.deleteCredentials = deleteCredentials
        }
    }

    // MARK: - State

    private var pairing: HAPPairing?
    private var pairVerify: CompanionPairVerify?
    private var pendingM2Data: Data?
    /// In-flight SRP M3 computation kicked off by `submitPin`. Tracked so
    /// `reset()` can cancel it before its completion lands on a torn-down flow.
    private var pinTask: Task<Void, Never>?
    private let delegate: Delegate

    public init(delegate: Delegate) {
        self.delegate = delegate
    }

    /// Discard all in-progress pairing state. Called from `disconnect()`.
    public func reset() {
        pairing    = nil
        pairVerify = nil
        pendingM2Data = nil
        pinTask?.cancel()
        pinTask = nil
    }

    // MARK: - Entry points (called by CompanionConnection)

    /// Begin pair-setup: generate M1 and send PS_Start.
    public func startPairSetup() {
        let p = HAPPairing()
        pairing = p
        let payload = p.m1Payload()
        delegate.sendFrame(.psStart, OPACK.wrapPsStartData(payload))
    }

    /// Begin pair-verify with stored credentials: generate M1 and send PV_Start.
    public func startPairVerify(credentials: PairingCredentials) {
        let verify = CompanionPairVerify(credentials: credentials)
        pairVerify = verify
        delegate.sendFrame(.pvStart, OPACK.wrapPvStartData(verify.m1Payload()))
    }

    /// Handle an incoming PS_Next frame (pair-setup steps M2/M4/M6).
    public func handlePsNext(_ payload: Data, device: AppleTVDevice) {
        let opackExtracted = OPACK.extractPairingData(from: payload)
        let extracted = opackExtracted ?? payload
        if opackExtracted == nil {
            let hex = payload.prefix(32).map { String(format: "%02x", $0) }.joined(separator: " ")
            Log.companion.fail("Companion psNext: OPACK extraction failed, raw payload hex: \(hex)")
        }
        let tlv: TLV8
        do {
            tlv = try TLV8.decode(extracted)
        } catch {
            NSLog("[ATV_CONNECT] Pairing PS_Next malformed TLV8: %@", "\(error)")
            delegate.setState(.error("Pairing PS_Next: malformed TLV8 (\(error))"))
            return
        }
        let step = tlv[.state]?.first ?? 0
        NSLog("[ATV_CONNECT] PairingFlow.handlePsNext received step: %d, extracted bytes: %d", Int(step), extracted.count)
        
        // 优先检查 Apple TV 返回的错误码（例如 0x03 退避频控锁定期）
        if let errByte = tlv[.error]?.first {
            var errorMsg = "Apple TV 配对错误 (代码: \(errByte))"
            if errByte == 0x03 {
                var delaySec = 60
                if let delayData = tlv[.retryDelay] {
                    if delayData.count >= 2 {
                        delaySec = Int(UInt16(delayData[0]) | (UInt16(delayData[1]) << 8))
                    } else if delayData.count == 1 {
                        delaySec = Int(delayData[0])
                    }
                }
                errorMsg = "Apple TV 正在配对安全保护期（频控锁定中，还剩 \(delaySec) 秒）。请稍候再试，或将 Apple TV 重启即可立即解除锁定并弹出 PIN 码。"
            }
            NSLog("[ATV_CONNECT] PairingFlow error: %@", errorMsg)
            Log.companion.fail("Companion PS_Next error \(errByte): \(errorMsg)")
            delegate.setState(.error(errorMsg))
            return
        }

        switch step {
        case 2:  // M2: ATV sent salt + public key → need PIN
            NSLog("[ATV_CONNECT] M2 received from ATV! PIN code is now showing on TV screen.")
            pendingM2Data = extracted
            delegate.setState(.awaitingPairingPin)

        case 4:  // M4: server proof verified → send M5
            do {
                NSLog("[ATV_CONNECT] M4 received from ATV! Verifying server proof...")
                let m5 = try pairing?.processM4(extracted) ?? Data()
                NSLog("[ATV_CONNECT] Server proof verified! Sending M5 payload (%d bytes)...", m5.count)
                delegate.sendFrame(.psNext, OPACK.wrapPsNextData(m5))
            } catch {
                NSLog("[ATV_CONNECT] Pairing M4 failed: %@", "\(error)")
                delegate.setState(.error("Pairing M4 failed: \(error)"))
            }

        case 6:  // M6: ATV identity → pairing complete, reconnect for verify
            do {
                NSLog("[ATV_CONNECT] M6 received from ATV! Processing ATV credentials...")
                let creds = try pairing?.processM6(extracted)
                guard let creds = creds as PairingCredentials? else {
                    NSLog("[ATV_CONNECT] Pairing M6 failed: missing credentials")
                    delegate.setState(.error("Pairing M6: missing credentials"))
                    return
                }
                NSLog("[ATV_CONNECT] Pairing M6 succeeded! Saving credentials for device: %@", device.id)
                delegate.saveCredentials(creds, device.id)
                // Companion protocol requires pair-verify on a fresh TCP connection.
                NSLog("[ATV_CONNECT] Reconnecting to ATV for pair-verify...")
                delegate.reconnect(device)
            } catch {
                NSLog("[ATV_CONNECT] Pairing M6 failed: %@", "\(error)")
                delegate.setState(.error("Pairing M6 failed: \(error)"))
            }

        default:
            Log.companion.fail("Companion: unexpected PS_Next state \(step)")
        }
    }

    /// Handle an incoming PV_Next frame (pair-verify steps M2/M4).
    public func handlePvNext(_ payload: Data, deviceID: String) {
        let extracted = OPACK.extractPairingData(from: payload) ?? payload
        let tlv: TLV8
        do {
            tlv = try TLV8.decode(extracted)
        } catch {
            delegate.setState(.error("Pair verify PV_Next: malformed TLV8 (\(error))"))
            return
        }
        let step = tlv[.state]?.first ?? 0
        Log.companion.trace("Companion pvNext step=\(step) (\(extracted.count) bytes TLV8)")
        
        if let errByte = tlv[.error]?.first {
            if errByte == 0x02 { // 仅当 Apple TV 显式返回身份认证失效时才删除凭据
                delegate.deleteCredentials(deviceID)
            }
            delegate.setState(.error("Pair verify rejected by ATV (error: \(errByte))"))
            return
        }

        switch step {
        case 2:  // M2: ATV sent ephemeral key + encrypted identity
            do {
                let m3 = try pairVerify?.processM2(extracted) ?? Data()
                delegate.sendFrame(.pvNext, OPACK.wrapPairingData(m3))
            } catch {
                NSLog("[ATV_CONNECT] Pair verify M2 processing failed: %@", "\(error)")
                delegate.setState(.error("Pair verify M2 failed: \(error)"))
            }

        case 4:  // M4: success or explicit server rejection
            do {
                try pairVerify?.verifyM4(extracted)
                if let enc = pairVerify?.sessionEncryptKey,
                   let dec = pairVerify?.sessionDecryptKey {
                    delegate.installKeys(enc, dec)
                }
                delegate.setState(.connected)
            } catch {
                NSLog("[ATV_CONNECT] Pair verify M4 failed: %@", "\(error)")
                delegate.setState(.error("Pair verify failed: \(error)"))
            }

        default:
            Log.companion.fail("Companion: unexpected PV_Next state \(step)")
        }
    }

    /// Called from `CompanionConnection.submitPairingPin(_:)` after the user
    /// enters their PIN. Runs SRP off-main to avoid beachballing.
    public func submitPin(_ pin: String, onSend: @escaping @Sendable @MainActor (Data) -> Void, onError: @escaping @Sendable @MainActor (String) -> Void) {
        guard let m2 = pendingM2Data else {
            NSLog("[ATV_CONNECT] submitPin failed: pendingM2Data is nil!")
            return
        }
        guard let capturedPairing = pairing else {
            NSLog("[ATV_CONNECT] submitPin failed: pairing is nil!")
            return
        }
        NSLog("[ATV_CONNECT] submitPin: starting SRP calculation for PIN: %@", pin)
        pinTask?.cancel()
        pinTask = Task.detached { [weak self] in
            do {
                NSLog("[ATV_CONNECT] processM2 starting on background task...")
                let m3 = try capturedPairing.processM2(m2, pin: pin)
                NSLog("[ATV_CONNECT] processM2 completed successfully! M3 size: %d bytes", m3.count)
                if Task.isCancelled {
                    NSLog("[ATV_CONNECT] pinTask was cancelled, aborting.")
                    return
                }
                await MainActor.run {
                    guard let self, self.pairing != nil else {
                        NSLog("[ATV_CONNECT] MainActor callback aborted: self or pairing was reset")
                        return
                    }
                    self.pinTask = nil
                    NSLog("[ATV_CONNECT] Calling onSend with M3 data...")
                    onSend(m3)
                }
            } catch {
                NSLog("[ATV_CONNECT] processM2 failed with error: %@", "\(error)")
                if Task.isCancelled { return }
                await MainActor.run {
                    guard let self, self.pairing != nil else { return }
                    self.pinTask = nil
                    onError("Pairing M3 failed: \(error)")
                }
            }
        }
    }
}
