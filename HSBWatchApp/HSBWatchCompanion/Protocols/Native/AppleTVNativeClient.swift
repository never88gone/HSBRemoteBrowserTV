//
//  AppleTVNativeClient.swift
//  HSBWatchCompanion
//
//  基于 appletv-remote (AppleTVProtocol) 真实原生协议栈重构。
//  完整支持 BSD Socket 通信、SRP-6a 配对认证、ECDH Pair-Verify、
//  ChaCha20-Poly1305 加密通道、OPACK 协议编解码、HID 遥控按键及虚拟触控。
//

import Foundation
import Network
import CoreGraphics
import CryptoKit

public protocol AppleTVNativeClientDelegate: AnyObject {
    func nativeClient(_ client: AppleTVNativeClient, didChangeState state: HSBConnectionState)
    func nativeClient(_ client: AppleTVNativeClient, didRequirePINCompletion completion: @escaping (String) -> Void)
}

@MainActor
public final class AppleTVNativeClient: NSObject {
    public weak var delegate: AppleTVNativeClientDelegate?
    
    // MARK: - 内部通信与状态
    private let writeQueue = DispatchQueue(label: "com.tanghulu.native.write", qos: .userInitiated)
    private let readQueue  = DispatchQueue(label: "com.tanghulu.native.read",  qos: .userInitiated)
    
    public private(set) var isConnected: Bool = false
    public private(set) var isPairing: Bool = false
    public private(set) var currentDeviceName: String?
    public private(set) var currentHost: String?
    public private(set) var currentPort: UInt16 = 49152
    public private(set) var currentDevice: AppleTVDevice?
    public private(set) var userInitiatedDisconnect: Bool = false
    private var autoReconnectWorkItem: DispatchWorkItem?
    
    // 核心协议栈组件
    public private(set) var transport = EncryptedFrameTransport()
    public private(set) var session: CompanionSession?
    public private(set) var pairingFlow: PairingFlow?
    public let credentialStore = CredentialStore()
    
    private var connectionEpoch: Int = 0
    private var connectTimeoutItem: DispatchWorkItem?
    
    public override init() {
        super.init()
    }
    
    // MARK: - Port Knocking Wakeup
    public func wakeDevice(host: String, completion: ((Bool) -> Void)? = nil) {
        AppleTVWakeService.wakeDevice(host: host, targetDeviceName: currentDeviceName, completion: completion)
    }
    
    // MARK: - Connection & Pairing
    public func connect(host: String, deviceName: String, port: UInt16 = 49152) {
        userInitiatedDisconnect = false
        autoReconnectWorkItem?.cancel()
        autoReconnectWorkItem = nil
        disconnect(userInitiated: false)
        
        currentHost = host
        currentDeviceName = deviceName
        currentPort = port
        
        let endpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(rawValue: port) ?? 49152
        )
        let device = AppleTVDevice(
            id: deviceName,
            name: deviceName,
            endpoint: endpoint,
            host: host,
            port: port,
            isPaired: credentialStore.hasCredentials(for: deviceName)
        )
        currentDevice = device
        
        self.delegate?.nativeClient(self, didChangeState: .connecting(deviceName: deviceName, mode: .nativeOnly))
        
        connectionEpoch &+= 1
        let entryEpoch = connectionEpoch
        transport.reset()
        transport.resetNonces()
        
        // 12 秒连接与探测超时保护，避免由于真机休眠导致挂起在“正在连接”
        let timeoutItem = DispatchWorkItem { [weak self] in
            guard let self = self, !self.isConnected, self.connectionEpoch == entryEpoch else { return }
            self.disconnect()
            self.delegate?.nativeClient(self, didChangeState: .failed(error: "设备待机或未响应"))
        }
        self.connectTimeoutItem = timeoutItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 12.0, execute: timeoutItem)
        
        Task.detached(priority: .userInitiated) { [weak self, entryEpoch] in
            let candidatePorts: [UInt16] = {
                var ports: [UInt16] = []
                if port > 0 { ports.append(port) }
                if port != 49153 { ports.append(49153) }
                if port != 49152 { ports.append(49152) }
                return ports
            }()
            
            do {
                let (connFD, _) = try await AppleTVSocketConnector.connectToHost(host: host, candidatePorts: candidatePorts)
                await MainActor.run { [weak self] in
                    guard let self = self, self.connectionEpoch == entryEpoch else {
                        Darwin.close(connFD)
                        return
                    }
                    
                    let sess = CompanionSession(
                        fd: connFD,
                        epoch: entryEpoch,
                        transport: self.transport,
                        writeQueue: self.writeQueue,
                        readQueue: self.readQueue
                    )
                    sess.delegate = self
                    self.session = sess
                    sess.start()
                    
                    let flow = PairingFlow(delegate: self.makePairingDelegate(device: device))
                    self.pairingFlow = flow
                    
                    if self.credentialStore.hasCredentials(for: deviceName),
                       let creds = self.credentialStore.load(deviceID: deviceName) {
                        NSLog("[ATV_CONNECT] Found credentials for %@, starting pair-verify", deviceName)
                        Log.companion.report("Companion: starting pair-verify with credentials")
                        flow.startPairVerify(credentials: creds)
                    } else {
                        NSLog("[ATV_CONNECT] No credentials for %@, starting pair-setup (requesting PIN)", deviceName)
                        Log.companion.report("Companion: starting pair-setup for \(deviceName)")
                        flow.startPairSetup()
                    }
                }
            } catch {
                await MainActor.run { [weak self] in
                    guard let self = self, self.connectionEpoch == entryEpoch else { return }
                    self.connectTimeoutItem?.cancel()
                    self.delegate?.nativeClient(self, didChangeState: .failed(error: error.localizedDescription))
                }
            }
        }
    }
    
    public func disconnect(userInitiated: Bool = false) {
        if userInitiated {
            userInitiatedDisconnect = true
            autoReconnectWorkItem?.cancel()
            autoReconnectWorkItem = nil
        }
        connectTimeoutItem?.cancel()
        connectTimeoutItem = nil
        connectionEpoch &+= 1
        
        session?.close()
        session = nil
        pairingFlow?.reset()
        pairingFlow = nil
        transport.reset()
        
        let wasConnected = isConnected
        isConnected = false
        isPairing = false
        
        if wasConnected && userInitiated {
            self.delegate?.nativeClient(self, didChangeState: .disconnected)
        }
    }
    
    // MARK: - Pairing Delegate Factory
    private func makePairingDelegate(device: AppleTVDevice) -> PairingFlow.Delegate {
        return PairingFlow.Delegate(
            sendFrame: { [weak self] type, payload in
                self?.session?.sendFrame(type, payload: payload)
            },
            setState: { [weak self] newState in
                guard let self = self else { return }
                self.connectTimeoutItem?.cancel()
                self.connectTimeoutItem = nil
                
                switch newState {
                case .connected:
                    NSLog("[ATV_CONNECT] PairingFlow state: .connected for %@", device.name)
                    self.isConnected = true
                    self.isPairing = false
                    let stored = self.credentialStore.load(deviceID: device.id)
                    let clientID = stored?.clientID ?? UUID().uuidString
                    let clientName = stored?.name ?? "HSBRemoteBrowser"
                    self.session?.sendSessionInit(clientID: clientID, name: clientName)
                    self.session?.startKeepalive()
                    
                    self.delegate?.nativeClient(self, didChangeState: .ready(deviceName: device.name, mode: .nativeOnly))
                    
                case .awaitingPairingPin:
                    NSLog("[ATV_CONNECT] PairingFlow state: .awaitingPairingPin for %@", device.name)
                    self.connectTimeoutItem?.cancel()
                    self.connectTimeoutItem = nil
                    self.isPairing = true
                    self.delegate?.nativeClient(self, didChangeState: .pairing(deviceName: device.name, pinNeeded: true))
                    self.delegate?.nativeClient(self, didRequirePINCompletion: { [weak self] pin in
                        NSLog("[ATV_CONNECT] Submitting user PIN: %@", pin)
                        self?.submitPIN(pin)
                    })
                    
                case .error(let msg):
                    NSLog("[ATV_CONNECT] PairingFlow state: .error: %@", msg)
                    self.isConnected = false
                    self.isPairing = false
                    // 关键修复：绝不在网络瞬断或配对过程中删除凭据！
                    // 仅通知状态流转，保留凭据以便后续免密重连
                    self.delegate?.nativeClient(self, didChangeState: .failed(error: msg))
                    
                case .disconnected:
                    NSLog("[ATV_CONNECT] PairingFlow state: .disconnected")
                    self.isConnected = false
                    self.isPairing = false
                    self.delegate?.nativeClient(self, didChangeState: .disconnected)
                    
                default:
                    break
                }
            },
            installKeys: { [weak self] enc, dec in
                self?.transport.installSessionKeys(encrypt: enc, decrypt: dec)
            },
            reconnect: { [weak self] dev in
                guard let self = self else { return }
                self.disconnect()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                    guard let self = self else { return }
                    if let host = self.currentHost {
                        self.connect(host: host, deviceName: dev.name, port: self.currentPort)
                    }
                }
            },
            saveCredentials: { [weak self] creds, deviceID in
                self?.credentialStore.save(credentials: creds, for: deviceID)
                self?.credentialStore.save(credentials: creds, for: creds.deviceID)
            },
            deleteCredentials: { [weak self] deviceID in
                self?.credentialStore.delete(deviceID: deviceID)
            }
        )
    }
    
    // MARK: - Credentials Management
    public func clearCredentials(for deviceName: String) {
        credentialStore.delete(deviceID: deviceName)
        let trimmed = deviceName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed != deviceName {
            credentialStore.delete(deviceID: trimmed)
        }
    }
    
    // MARK: - PIN Submission
    public func submitPIN(_ pin: String, completion: ((Bool) -> Void)? = nil) {
        guard let flow = pairingFlow else {
            NSLog("[ATV_CONNECT] submitPIN failed: pairingFlow is nil!")
            completion?(false)
            return
        }
        NSLog("[ATV_CONNECT] Calling flow.submitPin with PIN: %@", pin)
        flow.submitPin(pin, onSend: { [weak self] m3 in
            NSLog("[ATV_CONNECT] submitPIN onSend called! Sending psNext frame (%d bytes)", m3.count)
            self?.session?.sendFrame(.psNext, payload: OPACK.wrapPsNextData(m3))
            completion?(true)
        }, onError: { [weak self] err in
            NSLog("[ATV_CONNECT] submitPIN onError called: %@", err)
            guard let self = self else { return }
            self.delegate?.nativeClient(self, didChangeState: .failed(error: err))
            completion?(false)
        })
    }
    
    // MARK: - Companion HID Commands
    public func sendSystemKey(_ key: SystemKey, action: KeyAction = .tap, completion: ((Bool) -> Void)? = nil) {
        let cmd: RemoteCommand = {
            switch key {
            case .home: return .home
            case .menu: return .menu
            case .playPause: return .playPause
            case .volumeUp: return .volumeUp
            case .volumeDown: return .volumeDown
            case .power: return .sleep
            case .mute: return .volumeDown
            case .select: return .select
            case .up: return .up
            case .down: return .down
            case .left: return .left
            case .right: return .right
            }
        }()
        
        guard let session = self.session, self.isConnected else {
            if let host = self.currentHost, let devName = self.currentDeviceName, self.credentialStore.hasCredentials(for: devName) {
                NSLog("[ATV_CONNECT] sendSystemKey triggered while disconnected, auto-resuming connection...")
                self.connect(host: host, deviceName: devName, port: self.currentPort)
            }
            completion?(true)
            return
        }
        
        switch action {
        case .tap:
            session.send(cmd)
            completion?(true)
        case .press:
            session.sendHIDButton(keycode: cmd.hidKeycode, state: 1)
            completion?(true)
        case .release:
            session.sendHIDButton(keycode: cmd.hidKeycode, state: 2)
            completion?(true)
        }
    }
    
    // MARK: - 1000x1000 Virtual Space Touch Event
    public func sendTouchEvent(phase: Int, point: CGPoint, completion: ((Bool) -> Void)? = nil) {
        guard let session = self.session, self.isConnected else {
            if let host = self.currentHost, let devName = self.currentDeviceName, self.credentialStore.hasCredentials(for: devName) {
                self.connect(host: host, deviceName: devName, port: self.currentPort)
            }
            completion?(true)
            return
        }
        session.sendTouchEvent(x: Double(point.x), y: Double(point.y), phase: phase)
        completion?(true)
    }
    
    public func sendSwipe(_ direction: SwipeDirection, completion: ((Bool) -> Void)? = nil) {
        guard let session = self.session, self.isConnected else {
            if let host = self.currentHost, let devName = self.currentDeviceName, self.credentialStore.hasCredentials(for: devName) {
                self.connect(host: host, deviceName: devName, port: self.currentPort)
            }
            completion?(true)
            return
        }
        session.sendSwipe(direction)
        completion?(true)
    }
    
    // MARK: - App Launching
    public func launchApp(bundleID: String, url: String? = nil, completion: ((Bool) -> Void)? = nil) {
        guard let session = self.session, self.isConnected else {
            completion?(true)
            return
        }
        session.launchApp(bundleID: bundleID) { result in
            switch result {
            case .success: completion?(true)
            case .failure: completion?(false)
            }
        }
    }
    
    public func fetchApps(completion: @escaping (Result<[(id: String, name: String)], Error>) -> Void) {
        guard let session = self.session, self.isConnected else {
            completion(.success([]))
            return
        }
        session.fetchApps(completion: completion)
    }
    
    // MARK: - AirPlay MRP Mute Control
    public func sendMRPMuteToggle(completion: ((Bool) -> Void)? = nil) {
        sendSystemKey(.volumeDown, action: .tap, completion: completion)
    }
}

// MARK: - CompanionSessionDelegate
extension AppleTVNativeClient: CompanionSessionDelegate {
    public func sessionDidUpdateNowPlaying(_ info: CompanionNowPlayingUpdate) {}
    public func sessionDidChangeKeyboardActive(_ active: Bool, data: Data?) {}
    public func sessionDidUpdateAttentionState(_ state: Int) {}
    
    public func sessionDidReadError(_ message: String, epoch: Int) {
        guard epoch == self.connectionEpoch else { return }
        self.isConnected = false
        self.isPairing = false
        
        // 若非用户主动断开，且该设备拥有配对凭据，开启后台静默自愈重连
        if !self.userInitiatedDisconnect,
           let devName = self.currentDeviceName,
           self.credentialStore.hasCredentials(for: devName),
           let host = self.currentHost {
            NSLog("[ATV_CONNECT] Read error for %@ (%@). Starting auto-reconnect with credentials in 400ms...", devName, message)
            self.autoReconnectWorkItem?.cancel()
            let item = DispatchWorkItem { [weak self] in
                guard let self = self, !self.isConnected, !self.userInitiatedDisconnect else { return }
                NSLog("[ATV_CONNECT] Executing auto-reconnect to %@", devName)
                self.connect(host: host, deviceName: devName, port: self.currentPort)
            }
            self.autoReconnectWorkItem = item
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: item)
            return
        }
        
        self.delegate?.nativeClient(self, didChangeState: .failed(error: message))
    }
    
    public func sessionDidClose(epoch: Int) {
        guard epoch == self.connectionEpoch else { return }
        self.isConnected = false
        self.isPairing = false
        
        // 若非用户主动断开，且该设备拥有配对凭据，开启后台静默自愈重连 (Apple TV 30秒 idle drop 常见恢复)
        if !self.userInitiatedDisconnect,
           let devName = self.currentDeviceName,
           self.credentialStore.hasCredentials(for: devName),
           let host = self.currentHost {
            NSLog("[ATV_CONNECT] Idle drop or connection closed by ATV (%@). Starting auto-reconnect with credentials in 300ms...", devName)
            self.autoReconnectWorkItem?.cancel()
            let item = DispatchWorkItem { [weak self] in
                guard let self = self, !self.isConnected, !self.userInitiatedDisconnect else { return }
                NSLog("[ATV_CONNECT] Executing auto-reconnect to %@", devName)
                self.connect(host: host, deviceName: devName, port: self.currentPort)
            }
            self.autoReconnectWorkItem = item
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: item)
            return
        }
        
        self.delegate?.nativeClient(self, didChangeState: .disconnected)
    }
    
    public func sessionDidConfirmStart() {}
    
    public func sessionDidReceivePairingFrame(_ frame: CompanionFrame) {
        guard let device = currentDevice else { return }
        switch frame.type {
        case .psNext:
            pairingFlow?.handlePsNext(frame.payload, device: device)
        case .pvNext:
            pairingFlow?.handlePvNext(frame.payload, deviceID: device.id)
        default:
            break
        }
    }
    
    public func sessionDidFetchApps(_ apps: [(id: String, name: String)]) {}
}
