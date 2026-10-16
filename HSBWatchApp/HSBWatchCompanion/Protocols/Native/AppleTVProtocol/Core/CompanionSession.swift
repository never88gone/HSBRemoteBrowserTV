import Foundation
import Darwin
// import AppleTVLogging

// Installed once on first use of CompanionSession. Without this, a Darwin.write
// to a socket whose peer has already closed (extremely common on tvOS reboots /
// idle drops) raises SIGPIPE and the kernel default-action terminates the
// process — no crash report, just `launchd: exited due to SIGPIPE`. Ignoring
// the signal turns it into a normal write() == -1, errno == EPIPE that the
// existing error path in sendFrame handles cleanly.
private let _installSigPipeIgnore: Void = {
    signal(SIGPIPE, SIG_IGN)
    return ()
}()
// MARK: - CompanionSession

/// Owns the live Companion session: the TCP socket fd, the blocking read loop,
/// the encrypted frame transport, the transaction counter, pending-callback
/// dispatch, keepalive timer, and all feature-level send methods (HID, swipe,
/// text-input, app-list, launch).
///
/// `CompanionSession` is ignorant of SwiftUI, `@Published` state, pairing, and
/// device discovery — those stay in `CompanionConnection`. Events flow back via
/// `CompanionSessionDelegate`.
///
/// Threading: created and torn down on `@MainActor`. The blocking read loop
/// runs on `readQueue`; writes run on `writeQueue`. State mutations (txnCounter,
/// pendingCallbacks, keepaliveTimer, etc.) always happen on the main actor.
@MainActor
public final class CompanionSession {

    // MARK: - Init / teardown

    public weak var delegate: (any CompanionSessionDelegate)?

    private let transport: EncryptedFrameTransport
    private let fd: Int32
    public let epoch: Int
    private let writeQueue: DispatchQueue
    private let readQueue: DispatchQueue

    private var receiveBuffer = Data()
    private var txnCounter: UInt32
    private var pendingCallbacks: [UInt32: ([String: Any]) -> Void] = [:]
    private var sessionStartTxn: UInt32?
    public private(set) lazy var textInputController = CompanionTextInputController(session: self)
    public private(set) lazy var appLauncher = CompanionAppLauncher(session: self)
    public private(set) lazy var keepaliveManager = CompanionKeepaliveManager(session: self)

    public var currentTextInputData: Data? {
        get { textInputController.currentTextInputData }
        set { textInputController.currentTextInputData = newValue }
    }
    public var lastTextOpAt: Date? {
        get { textInputController.lastTextOpAt }
        set { textInputController.lastTextOpAt = newValue }
    }

    public func registerCallback(txn: UInt32, callback: @escaping ([String: Any]) -> Void) {
        pendingCallbacks[txn] = callback
    }

    @discardableResult
    public func removeCallback(txn: UInt32) -> (([String: Any]) -> Void)? {
        return pendingCallbacks.removeValue(forKey: txn)
    }

    /// Create a session over an already-connected socket fd.
    /// - Parameters:
    ///   - fd: Connected TCP socket. `CompanionSession` takes ownership; it will
    ///     close the fd when `close()` is called.
    ///   - epoch: Connection epoch from `CompanionConnection` — read-loop
    ///     callbacks bail if the epoch changes (i.e. we reconnected).
    ///   - transport: Encryption layer with keys already installed.
    ///   - writeQueue: Serial queue for Darwin.write calls.
    ///   - readQueue: Serial queue for the blocking Darwin.read loop.
    public init(fd: Int32,
                epoch: Int,
                transport: EncryptedFrameTransport,
                writeQueue: DispatchQueue,
                readQueue: DispatchQueue) {
        _ = _installSigPipeIgnore
        self.fd = fd
        self.epoch = epoch
        self.transport = transport
        self.writeQueue = writeQueue
        self.readQueue = readQueue
        self.txnCounter = UInt32.random(in: 1...65535)
    }

    /// Start the blocking read loop. Call once immediately after init.
    public func start() {
        startReadLoop()
    }

    /// Tear down the session: cancel keepalive, close the socket, clear callbacks.
    /// Safe to call multiple times.
    public func close() {
        keepaliveManager.stop()
        pendingCallbacks.removeAll()
        currentTextInputData = nil
        // Closing the fd unblocks the blocking read() in startReadLoop.
        Darwin.shutdown(fd, SHUT_RDWR)
        Darwin.close(fd)
    }

    // MARK: - Session startup

    /// Send the session-init messages the ATV requires before it considers the session open:
    /// _systemInfo, _touchStart, _sessionStart, TVRCSessionStart, _tiStart.
    /// TVRCSessionStart registers a TV Remote Client session with tvremoted —
    /// without it tvOS silently ignores FetchAttentionState and
    /// FetchLaunchableApplicationsEvent. See pyatv api.py `_tv_rc_session_start`.
    public func sendSessionInit(clientID: String, name: String) {
        let txn1 = nextTxn()
        sendEncrypted(OPACK.encodeSystemInfo(clientID: clientID, name: name, txn: txn1))

        let txn2 = nextTxn()
        sendEncrypted(OPACK.encodeTouchStart(txn: txn2))

        let txn3 = nextTxn()
        let localSID = UInt32.random(in: 0..<UInt32.max)
        sessionStartTxn = txn3
        sendEncrypted(OPACK.encodeSessionStart(txn: txn3, localSID: localSID))

        let txnRC = nextTxn()
        sendEncrypted(OPACK.encodeTVRCSessionStart(txn: txnRC))

        let txn4 = nextTxn()
        pendingCallbacks[txn4] = { [weak self] response in
            guard let self else { return }
            let tiD = (response["_c"] as? [String: Any])?["_tiD"] as? Data
            self.currentTextInputData = tiD
            self.delegate?.sessionDidChangeKeyboardActive(tiD != nil, data: tiD)
        }
        sendEncrypted(OPACK.encodeTextInputStart(txn: txn4))
    }

    // MARK: - Keepalive

    public func startKeepalive() {
        keepaliveManager.start()
    }

    // MARK: - Remote Commands

    public func send(_ command: RemoteCommand) {
        let keycode = command.hidKeycode
        if command.sendReleaseOnly {
            let txn = nextTxn()
            sendEncrypted(OPACK.encodeHIDCommand(keycode: keycode, state: 2, txn: txn))
        } else {
            let txn = nextTxn()
            sendEncrypted(OPACK.encodeHIDCommand(keycode: keycode, state: 1, txn: txn))
            let txn2 = nextTxn()
            sendEncrypted(OPACK.encodeHIDCommand(keycode: keycode, state: 2, txn: txn2))
        }
    }

    public func sendLongPress(_ command: RemoteCommand, ms: Int = 1000) {
        let keycode = command.hidKeycode
        let txn = nextTxn()
        sendEncrypted(OPACK.encodeHIDCommand(keycode: keycode, state: 1, txn: txn))
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(ms))
            guard let self else { return }
            let txn2 = self.nextTxn()
            self.sendEncrypted(OPACK.encodeHIDCommand(keycode: keycode, state: 2, txn: txn2))
        }
    }

    public func sendSwipe(_ direction: SwipeDirection) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let (start, end) = direction.coordinates
            let baseNs = DispatchTime.now().uptimeNanoseconds

            self.sendEncrypted(OPACK.encodeTouchEvent(x: start.x, y: start.y, phase: 1,
                                                      txn: self.nextTxn(),
                                                      nanoseconds: DispatchTime.now().uptimeNanoseconds - baseNs))
            for pt in direction.interpolatedSteps() {
                self.sendEncrypted(OPACK.encodeTouchEvent(x: pt.x, y: pt.y, phase: 3,
                                                          txn: self.nextTxn(),
                                                          nanoseconds: DispatchTime.now().uptimeNanoseconds - baseNs))
                try? await Task.sleep(for: .milliseconds(18))
            }
            self.sendEncrypted(OPACK.encodeTouchEvent(x: end.x, y: end.y, phase: 4,
                                                      txn: self.nextTxn(),
                                                      nanoseconds: DispatchTime.now().uptimeNanoseconds - baseNs))
            try? await Task.sleep(for: .milliseconds(50))
            self.sendEncrypted(OPACK.encodeTouchStop(txn: self.nextTxn()))
        }
    }

    public func sendHIDButton(keycode: UInt8, state: Int) {
        let txn = nextTxn()
        sendEncrypted(OPACK.encodeHIDCommand(keycode: keycode, state: state, txn: txn))
    }

    public func sendTouchEvent(x: Double, y: Double, phase: Int) {
        let txn = nextTxn()
        let ns = DispatchTime.now().uptimeNanoseconds
        sendEncrypted(OPACK.encodeTouchEvent(x: x, y: y, phase: phase, txn: txn, nanoseconds: ns))
    }

    // MARK: - Text Input

    public func sendText(_ text: String, completion: @escaping (Error?) -> Void) {
        textInputController.sendText(text, completion: completion)
    }

    public func sendBackspace(completion: @escaping (Error?) -> Void) {
        textInputController.sendBackspace(completion: completion)
    }

    public func sendClearText(completion: @escaping (Error?) -> Void) {
        textInputController.sendClearText(completion: completion)
    }

    // MARK: - App List / Launch

    public func fetchApps(completion: ((Result<[(id: String, name: String)], Error>) -> Void)? = nil) {
        appLauncher.fetchApps(completion: completion)
    }

    public func launchApp(bundleID: String,
                          completion: ((Result<Void, Error>) -> Void)? = nil) {
        appLauncher.launchApp(bundleID: bundleID, completion: completion)
    }

    // MARK: - Encrypted send

    public func sendEncrypted(_ opackData: Data) {
        if Log.verbose {
            let peek = OPACK.decodeDict(opackData).map { d -> String in
                let i = d["_i"] as? String ?? "?"
                let t = d["_t"] as? Int ?? -1
                let x = d["_x"] as? Int ?? -1
                return "_i=\(i) _t=\(t) _x=\(x)"
            } ?? "<undecodable \(opackData.count)B>"
            Log.companion.report("Companion → OPACK[\(opackData.count)B]: \(peek)")
        }
        do {
            let body = try transport.seal(opackData)
            sendFrame(.eOPACK, payload: body)
        } catch {
            Log.companion.fail("Companion: encrypt failed: \(error)")
        }
    }

    // MARK: - Frame send

    public func sendFrame(_ type: CompanionFrame.FrameType, payload: Data) {
        let fd = self.fd
        guard fd >= 0 else {
            Log.companion.fail("Companion: sendFrame called with no socket")
            return
        }
        Log.companion.trace("Companion → sending \(type) (\(payload.count) bytes)")
        let frameData = CompanionFrame(type: type, payload: payload).encoded
        writeQueue.async {
            frameData.withUnsafeBytes { rawBuf in
                var offset = 0
                let base   = rawBuf.baseAddress!
                let total  = rawBuf.count
                while offset < total {
                    let n = Darwin.write(fd, base + offset, total - offset)
                    if n <= 0 {
                        Log.companion.fail("Companion send error (errno \(errno))")
                        return
                    }
                    offset += n
                }
            }
        }
    }

    // MARK: - Test injection

    /// Feed a raw OPACK-encoded message directly into the session's dispatch
    /// logic, bypassing the socket and transport layer. Tests only.
    #if DEBUG
    public func injectOPACKForTesting(_ data: Data) {
        handleOPACKMessage(data)
    }
    #endif

    // MARK: - Read loop

    private func startReadLoop() {
        readQueue.async { [weak self] in
            var buf = [UInt8](repeating: 0, count: 65536)
            while true {
                guard let self else { return }
                let fd = self.fd
                let n = Darwin.read(fd, &buf, buf.count)
                if n <= 0 {
                    let err = n < 0 ? errno : 0
                    if err == EINTR {
                        continue
                    }
                    if err == EAGAIN || err == EWOULDBLOCK {
                        var pfd = pollfd(fd: fd, events: Int16(POLLIN), revents: 0)
                        let ret = poll(&pfd, 1, 1000)
                        if ret >= 0 {
                            continue
                        }
                    }
                    let reason = err == 0 ? "EOF (ATV closed connection)" :
                                 "errno \(err): \(String(cString: strerror(err)))"
                    Log.companion.report("Companion: read loop ended — \(reason)")
                    DispatchQueue.main.async { [weak self] in
                        guard let self else { return }
                        if err != 0 {
                            self.delegate?.sessionDidReadError("Read error: \(reason)", epoch: self.epoch)
                        } else {
                            self.delegate?.sessionDidClose(epoch: self.epoch)
                        }
                    }
                    return
                }
                let chunk = Data(buf[..<n])
                Log.companion.trace("Companion ← \(n) bytes")
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    self.receiveBuffer.append(chunk)
                    self.processBuffer()
                }
            }
        }
    }

    private func processBuffer() {
        while true {
            let frame: CompanionFrame?
            do {
                frame = try CompanionFrame.read(from: &receiveBuffer)
            } catch {
                // Oversize / desynchronised frame header — there's no safe
                // recovery; advertised payload would never arrive as a valid
                // frame. Log + tear down the session so AutoReconnector can
                // bring up a fresh one.
                Log.companion.fail("Companion: \(error) — dropping connection")
                delegate?.sessionDidReadError("Malformed frame: \(error)", epoch: epoch)
                return
            }
            guard let frame else { return }
            Log.companion.trace("Companion ← frame \(frame.type) (\(frame.payload.count) bytes)")
            switch frame.type {
            case .psNext, .pvNext:
                delegate?.sessionDidReceivePairingFrame(frame)
            case .eOPACK:
                handleEOPACK(frame.payload)
            default:
                Log.companion.fail("Companion: unhandled frame 0x\(String(frame.type.rawValue, radix: 16))")
            }
        }
    }

    // MARK: - E_OPACK handling

    private func handleEOPACK(_ payload: Data) {
        do {
            let plain = try transport.open(payload)
            handleOPACKMessage(plain)
        } catch {
            Log.companion.fail("Companion: E_OPACK decrypt failed: \(error)")
        }
    }

    private func handleOPACKMessage(_ data: Data) {
        let isLarge = data.count > 2000
        guard let msg = isLarge
            ? OPACK.decodeDictShallow(data)
            : OPACK.decodeDict(data)
        else {
            Log.companion.fail("Companion: E_OPACK decode failed (\(data.count)B) hex: \(data.prefix(32).map{String(format:"%02x",$0)}.joined(separator:" "))")
            return
        }
        let identifier = msg["_i"] as? String ?? ""
        let txn        = (msg["_x"] as? Int).map { UInt32($0) } ?? 0

        func fullMsg() -> [String: Any] {
            if isLarge, identifier != "_systemInfo" {
                return OPACK.decodeDict(data) ?? msg
            }
            return msg
        }

        if Log.verbose {
            func describeValue(_ v: Any?) -> String {
                switch v {
                case let s as String:           return "\"\(s)\""
                case let i as Int:              return "\(i)"
                case let f as Double:           return "\(f)"
                case let d as Data:             return "<\(d.count)B>"
                case let dict as [String: Any]:
                    let inner = dict.keys.sorted().map { "\($0)=\(describeValue(dict[$0]))" }.joined(separator: ",")
                    return "{\(inner)}"
                default:                        return "?"
                }
            }
            let kvDesc = msg.keys.sorted().map { k in "\(k)=\(describeValue(msg[k]))" }.joined(separator: " ")
            Log.companion.report("Companion ← OPACK[\(data.count)B]: \(kvDesc)")
        }

        switch identifier {
        case "_heartbeat":
            sendEncrypted(OPACK.encodeHeartbeatResponse(txn: txn))
            Log.companion.trace("Companion → _heartbeat response txn=\(txn) ✓")
        case "_ping":
            sendEncrypted(OPACK.encodePong(txn: txn))
            Log.companion.trace("Companion → _pong txn=\(txn) ✓")
        case "_pong":
            break
        case "_tiStarted":
            let c = fullMsg()["_c"] as? [String: Any]
            let tiD = c?["_tiD"] as? Data
            currentTextInputData = tiD
            delegate?.sessionDidChangeKeyboardActive(true, data: tiD)
            Log.companion.report("Companion: keyboard active (text field focused)")
            if tiD == nil {
                let tiTxn = nextTxn()
                pendingCallbacks[tiTxn] = { [weak self] resp in
                    guard let self else { return }
                    let d = (resp["_c"] as? [String: Any])?["_tiD"] as? Data
                    self.currentTextInputData = d
                    if d != nil {
                        self.delegate?.sessionDidChangeKeyboardActive(true, data: d)
                    }
                }
                sendEncrypted(OPACK.encodeTextInputStart(txn: tiTxn))
            }
        case "_tiStopped":
            currentTextInputData = nil
            delegate?.sessionDidChangeKeyboardActive(false, data: nil)
            Log.companion.report("Companion: keyboard inactive (text field lost focus)")
        case "_iMC":
            let inner = (fullMsg()["_c"] as? [String: Any]) ?? fullMsg()
            delegate?.sessionDidUpdateNowPlaying(CompanionNowPlayingUpdate(inner))
        case "FetchAttentionState":
            if let inner = msg["_c"] as? [String: Any],
               let st = inner["state"] as? Int {
                delegate?.sessionDidUpdateAttentionState(st)
                Log.companion.trace("Companion: attentionState=\(st)")
            }
        default:
            let msgType = msg["_t"] as? Int ?? 0
            if let cb = pendingCallbacks.removeValue(forKey: txn) {
                cb(fullMsg())
            }
            if let sst = sessionStartTxn, txn == sst, msgType == 3 {
                sessionStartTxn = nil
                Log.companion.report("Companion: session confirmed, subscribing to events")
                let t = nextTxn()
                sendEncrypted(OPACK.encodeInterest(
                    events: ["_iMC", "SystemStatus", "TVSystemStatus",
                             "_tiStarted", "_tiStopped"], txn: t))
                // Confirm the session as soon as it's up — do NOT gate this on
                // the FetchAttentionState reply. On wake the ATV frequently acks
                // _sessionStart but never answers FetchAttentionState, so gating
                // here left the app list (and anything else keyed off confirm)
                // stuck "loading" forever. FetchAttentionState is now fire-and-
                // forget; its reply (when it arrives) updates attention state via
                // the `case "FetchAttentionState"` / msgType==3 paths below.
                delegate?.sessionDidConfirmStart()
                let attnTxn = nextTxn()
                sendEncrypted(OPACK.encodeFetchAttentionState(txn: attnTxn))
            }
            if msgType == 3,
               let inner = msg["_c"] as? [String: Any],
               let st = inner["state"] as? Int {
                delegate?.sessionDidUpdateAttentionState(st)
                Log.companion.trace("Companion: attentionState=\(st)")
            }
        }
    }

    // MARK: - Helpers

    public func registerCallback(for txn: UInt32, callback: @escaping ([String: Any]) -> Void) {
        pendingCallbacks[txn] = callback
    }

    public func nextTxn() -> UInt32 {
        let t = txnCounter; txnCounter &+= 1; return t
    }
}
