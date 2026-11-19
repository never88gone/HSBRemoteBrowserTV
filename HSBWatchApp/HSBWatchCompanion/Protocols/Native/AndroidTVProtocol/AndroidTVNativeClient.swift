//
//  AndroidTVNativeClient.swift
//  HSBWatchCompanion
//
//  纯原生 Android TV 系统遥控客户端 (Android TV Remote Control Protocol v2)。
//  支持 mTLS 双向证书认证、6467 端口 PIN 码配对、6466 端口 Protobuf 控制长连接、
//  Ping/Pong 心跳保活、短按/长按全量 KeyEvent、文本输入法直传以及 Deep Link 应用唤起。
//

import Foundation
import Network
import Security
#if canImport(UIKit)
import UIKit
#endif

public protocol AndroidTVNativeClientDelegate: AnyObject {
    func androidClient(_ client: AndroidTVNativeClient, didChangeState state: HSBConnectionState)
    func androidClient(_ client: AndroidTVNativeClient, didRequirePINCompletion completion: @escaping (String) -> Void)
}

@MainActor
public final class AndroidTVNativeClient: NSObject {
    public weak var delegate: AndroidTVNativeClientDelegate?
    
    private let networkQueue = DispatchQueue(label: "com.tanghulu.androidtv.remote", qos: .userInitiated)
    
    public private(set) var isConnected: Bool = false
    public private(set) var isPairing: Bool = false
    public private(set) var isTVOn: Bool = true
    public private(set) var currentDeviceName: String?
    public private(set) var currentHost: String?
    public private(set) var currentControlPort: UInt16 = 6466
    public private(set) var currentAppPackage: String = ""
    public private(set) var currentVolumeLevel: UInt32 = 0
    public private(set) var currentVolumeMax: UInt32 = 0
    public private(set) var isMuted: Bool = false
    public private(set) var deviceVendor: String = ""
    public private(set) var deviceModel: String = ""
    public private(set) var userInitiatedDisconnect: Bool = false
    
    private var controlConnection: NWConnection?
    private var pairingSession: AndroidTVPairingSession?
    private var receiveBuffer = Data()
    private var connectionEpoch: Int = 0
    private var activeFeatures: Int32 = AndroidTVFeature.standardClient.rawValue
    private var imeCounter: Int32 = 0
    private var imeFieldCounter: Int32 = 0
    private var hasImeCounter: Bool = false
    private var hasImeFieldCounter: Bool = false
    private var didReceiveRemoteStart: Bool = false
    
    private var connectTimeoutItem: DispatchWorkItem?
    private var idleWatchdogTimer: DispatchSourceTimer?
    private var lastServerActivity: Date = Date()
    private var autoReconnectWorkItem: DispatchWorkItem?
    private var pendingPINCompletion: ((String) -> Void)?
    
    public let certificateManager = AndroidTVCertificateManager.shared
    
    public override init() {
        super.init()
    }
    
    // MARK: - Device Key Helper
    
    public func deviceKey(host: String, deviceName: String) -> String {
        let trimmedName = deviceName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName.isEmpty ? host : trimmedName
    }
    
    // MARK: - Connection Lifecycle
    
    public func connect(host: String, deviceName: String, port: UInt16 = 6466) {
        let controlPort = port > 0 ? port : 6466
        if isConnected && currentHost == host && currentControlPort == controlPort {
            NSLog("[AndroidTV_CONNECT] Already connected to %@ at %@:%d", deviceName, host, controlPort)
            delegate?.androidClient(self, didChangeState: .ready(deviceName: deviceName, mode: .nativeOnly))
            return
        }
        if isPairing && currentHost == host {
            NSLog("[AndroidTV_CONNECT] Pairing already in progress for %@", deviceName)
            return
        }
        
        cleanupConnectionState(userInitiated: false)
        
        userInitiatedDisconnect = false
        currentHost = host
        currentDeviceName = deviceName
        currentControlPort = controlPort
        connectionEpoch &+= 1
        let epoch = connectionEpoch
        
        delegate?.androidClient(self, didChangeState: .connecting(deviceName: deviceName, mode: .nativeOnly))
        
        let key = deviceKey(host: host, deviceName: deviceName)
        if certificateManager.isPaired(deviceKey: key) {
            NSLog("[AndroidTV_CONNECT] Found existing pairing record for %@ (%@), connecting to control port %d", deviceName, host, controlPort)
            connectToControlPort(host: host, deviceName: deviceName, port: controlPort, epoch: epoch, fallbackToPairingOnAuthFailure: true)
        } else {
            NSLog("[AndroidTV_CONNECT] No pairing record for %@ (%@), starting Polo pairing on port %d", deviceName, host, controlPort &+ 1)
            startPairingFlow(host: host, deviceName: deviceName, pairingPort: controlPort &+ 1, epoch: epoch)
        }
    }
    
    public func disconnect(userInitiated: Bool = true) {
        NSLog("[AndroidTV_CONNECT] disconnect(userInitiated=%d)", userInitiated ? 1 : 0)
        cleanupConnectionState(userInitiated: userInitiated)
        delegate?.androidClient(self, didChangeState: .disconnected)
    }
    
    public func clearCredentials(for deviceKey: String) {
        certificateManager.removePairedRecord(for: deviceKey)
        if currentDeviceName == deviceKey || currentHost == deviceKey {
            disconnect(userInitiated: true)
        }
    }
    
    private func cleanupConnectionState(userInitiated: Bool) {
        userInitiatedDisconnect = userInitiated
        connectionEpoch &+= 1
        
        connectTimeoutItem?.cancel()
        connectTimeoutItem = nil
        autoReconnectWorkItem?.cancel()
        autoReconnectWorkItem = nil
        
        stopIdleWatchdog()
        
        pairingSession?.cancel()
        pairingSession = nil
        
        let conn = controlConnection
        controlConnection = nil
        networkQueue.async {
            conn?.cancel()
        }
        
        receiveBuffer.removeAll(keepingCapacity: false)
        isConnected = false
        isPairing = false
        didReceiveRemoteStart = false
        pendingPINCompletion = nil
    }
    
    // MARK: - Pairing Flow (Port 6467)
    
    private func startPairingFlow(host: String, deviceName: String, pairingPort: UInt16, epoch: Int) {
        guard epoch == connectionEpoch else { return }
        isPairing = true
        delegate?.androidClient(self, didChangeState: .pairing(deviceName: deviceName, pinNeeded: true))
        
        let session = AndroidTVPairingSession(host: host, pairingPort: pairingPort, clientName: "糖葫芦遥控器")
        self.pairingSession = session
        
        session.onRequirePIN = { [weak self] in
            Task { @MainActor [weak self] in
                guard let self = self, epoch == self.connectionEpoch else { return }
                let pinHandler: (String) -> Void = { [weak self] pin in
                    self?.submitPIN(pin, completion: nil)
                }
                self.pendingPINCompletion = pinHandler
                self.delegate?.androidClient(self, didRequirePINCompletion: pinHandler)
            }
        }
        
        session.onComplete = { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self = self, epoch == self.connectionEpoch else { return }
                self.pairingSession = nil
                self.isPairing = false
                self.pendingPINCompletion = nil
                
                switch result {
                case .success(let serverCertDER):
                    let key = self.deviceKey(host: host, deviceName: deviceName)
                    self.certificateManager.savePairedRecord(
                        deviceKey: key,
                        deviceName: deviceName,
                        host: host,
                        port: self.currentControlPort,
                        serverCertDER: serverCertDER
                    )
                    NSLog("[AndroidTV_CONNECT] Pairing completed for %@, transitioning to control port %d", deviceName, self.currentControlPort)
                    self.delegate?.androidClient(self, didChangeState: .connecting(deviceName: deviceName, mode: .nativeOnly))
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                        guard let self = self, epoch == self.connectionEpoch else { return }
                        self.connectToControlPort(
                            host: host,
                            deviceName: deviceName,
                            port: self.currentControlPort,
                            epoch: epoch,
                            fallbackToPairingOnAuthFailure: false
                        )
                    }
                    
                case .failure(let error):
                    if error is CancellationError {
                        self.delegate?.androidClient(self, didChangeState: .disconnected)
                    } else {
                        let msg = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                        NSLog("[AndroidTV_CONNECT] Pairing failed: %@", msg)
                        self.delegate?.androidClient(self, didChangeState: .failed(error: msg))
                    }
                }
            }
        }
        
        session.start()
    }
    
    public func submitPIN(_ pin: String, completion: ((Bool) -> Void)? = nil) {
        let trimmed = pin.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let session = pairingSession else {
            completion?(false)
            return
        }
        if trimmed.isEmpty {
            session.cancel()
            completion?(false)
            return
        }
        // 提交后结果将由 session.onComplete 驱动，这里先立即同步下发给会话
        session.submitPIN(trimmed)
        completion?(true)
    }
    
    // MARK: - Control Port (Port 6466)
    
    private func connectToControlPort(
        host: String,
        deviceName: String,
        port: UInt16,
        epoch: Int,
        fallbackToPairingOnAuthFailure: Bool
    ) {
        guard epoch == connectionEpoch else { return }
        
        let identity: SecIdentity
        do {
            let pair = try certificateManager.loadOrCreateClientIdentity()
            identity = pair.identity
        } catch {
            delegate?.androidClient(self, didChangeState: .failed(error: error.localizedDescription))
            return
        }
        
        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            delegate?.androidClient(self, didChangeState: .failed(error: "无效控制端口 \(port)"))
            return
        }
        
        didReceiveRemoteStart = false
        imeCounter = 0
        imeFieldCounter = 0
        hasImeCounter = false
        hasImeFieldCounter = false
        activeFeatures = AndroidTVFeature.standardClient.rawValue
        
        let params = AndroidTVTLSFactory.makeTLSParameters(identity: identity, queue: networkQueue) { _ in }
        let conn = NWConnection(host: NWEndpoint.Host(host), port: nwPort, using: params)
        self.controlConnection = conn
        
        connectTimeoutItem?.cancel()
        let timeoutItem = DispatchWorkItem { [weak self] in
            guard let self = self, epoch == self.connectionEpoch, !self.isConnected else { return }
            NSLog("[AndroidTV_CONNECT] Control handshake timed out on %@:%d", host, port)
            self.handleControlDisconnect(
                host: host,
                deviceName: deviceName,
                port: port,
                epoch: epoch,
                reason: "连接 Android TV 控制通道超时",
                canFallbackToPairing: fallbackToPairingOnAuthFailure
            )
        }
        connectTimeoutItem = timeoutItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 8.0, execute: timeoutItem)
        
        conn.stateUpdateHandler = { [weak self] state in
            Task { @MainActor [weak self] in
                guard let self = self, epoch == self.connectionEpoch else { return }
                switch state {
                case .ready:
                    NSLog("[AndroidTV_CONNECT] Control TLS ready on %@:%d", host, port)
                    self.startControlReceiveLoop(conn: conn, host: host, deviceName: deviceName, port: port, epoch: epoch, fallbackToPairing: fallbackToPairingOnAuthFailure)
                case .failed(let err):
                    NSLog("[AndroidTV_CONNECT] Control TLS failed: %@", "\(err)")
                    self.handleControlDisconnect(
                        host: host,
                        deviceName: deviceName,
                        port: port,
                        epoch: epoch,
                        reason: err.localizedDescription,
                        canFallbackToPairing: fallbackToPairingOnAuthFailure
                    )
                case .cancelled:
                    break
                default:
                    break
                }
            }
        }
        
        conn.start(queue: networkQueue)
    }
    
    nonisolated private func startControlReceiveLoop(
        conn: NWConnection,
        host: String,
        deviceName: String,
        port: UInt16,
        epoch: Int,
        fallbackToPairing: Bool
    ) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }
            if let data = data, !data.isEmpty {
                Task { @MainActor [weak self] in
                    guard let self = self, epoch == self.connectionEpoch else { return }
                    self.lastServerActivity = Date()
                    self.receiveBuffer.append(data)
                    self.drainControlBuffer(host: host, deviceName: deviceName, port: port, epoch: epoch)
                }
            }
            if let error = error {
                Task { @MainActor [weak self] in
                    guard let self = self, epoch == self.connectionEpoch else { return }
                    self.handleControlDisconnect(
                        host: host,
                        deviceName: deviceName,
                        port: port,
                        epoch: epoch,
                        reason: error.localizedDescription,
                        canFallbackToPairing: fallbackToPairing && !self.didReceiveRemoteStart
                    )
                }
                return
            }
            if isComplete {
                Task { @MainActor [weak self] in
                    guard let self = self, epoch == self.connectionEpoch else { return }
                    self.handleControlDisconnect(
                        host: host,
                        deviceName: deviceName,
                        port: port,
                        epoch: epoch,
                        reason: "Android TV 主动断开了控制通道",
                        canFallbackToPairing: fallbackToPairing && !self.didReceiveRemoteStart
                    )
                }
                return
            }
            self.networkQueue.async {
                self.startControlReceiveLoop(conn: conn, host: host, deviceName: deviceName, port: port, epoch: epoch, fallbackToPairing: fallbackToPairing)
            }
        }
    }
    
    private func drainControlBuffer(host: String, deviceName: String, port: UInt16, epoch: Int) {
        do {
            while let rawFrame = try ProtobufCodec.popLengthPrefixedFrame(from: &receiveBuffer) {
                let message = try AndroidTVRemoteMessage.decode(from: rawFrame)
                handleControlMessage(message, host: host, deviceName: deviceName, port: port, epoch: epoch)
            }
        } catch {
            NSLog("[AndroidTV_CONNECT] Protobuf decode error on control stream: %@", "\(error)")
            handleControlDisconnect(host: host, deviceName: deviceName, port: port, epoch: epoch, reason: "协议帧解析失败", canFallbackToPairing: false)
        }
    }
    
    private func handleControlMessage(_ message: AndroidTVRemoteMessage, host: String, deviceName: String, port: UInt16, epoch: Int) {
        switch message {
        case .remoteConfigure(let code1, let info):
            self.deviceVendor = info.vendor
            self.deviceModel = info.model
            if code1 != 0 {
                self.activeFeatures = AndroidTVFeature.standardClient.rawValue & code1
            }
            NSLog("[AndroidTV_CONNECT] Server remote_configure: vendor=%@, model=%@, serverFeatures=0x%x, activeFeatures=0x%x",
                  info.vendor, info.model, code1, activeFeatures)
            let deviceModelName: String = {
                #if canImport(UIKit)
                return UIDevice.current.model
                #else
                return "iPhone"
                #endif
            }()
            let clientVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.3"
            let clientInfo = AndroidTVDeviceInfo(
                model: deviceModelName,
                vendor: "Apple",
                unknown1: 1,
                unknown2: "1",
                packageName: Bundle.main.bundleIdentifier ?? "com.never88gone.thlbrowserios",
                appVersion: clientVersion
            )
            sendRemoteMessage(.remoteConfigure(code1: activeFeatures, deviceInfo: clientInfo))
            
        case .remoteSetActive:
            NSLog("[AndroidTV_CONNECT] Server remote_set_active, replying activeFeatures=0x%x", activeFeatures)
            sendRemoteMessage(.remoteSetActive(active: activeFeatures))
            
        case .remoteStart(let started):
            self.isTVOn = started
            if !didReceiveRemoteStart {
                didReceiveRemoteStart = true
                connectTimeoutItem?.cancel()
                connectTimeoutItem = nil
                isConnected = true
                lastServerActivity = Date()
                startIdleWatchdog(host: host, deviceName: deviceName, port: port, epoch: epoch)
                NSLog("[AndroidTV_CONNECT] Server remote_start(started=%d) — Android TV READY!", started ? 1 : 0)
                delegate?.androidClient(self, didChangeState: .ready(deviceName: deviceName, mode: .nativeOnly))
            }
            
        case .remotePingRequest(let val1, _):
            sendRemoteMessage(.remotePingResponse(val1: val1))
            
        case .remoteImeKeyInject(let imeInfo):
            self.currentAppPackage = imeInfo.appPackage
            self.imeCounter = imeInfo.counter
            self.imeFieldCounter = imeInfo.fieldCounter
            self.hasImeCounter = imeInfo.counter != 0
            self.hasImeFieldCounter = imeInfo.fieldCounter != 0
            
        case .remoteImeShowRequest(let fieldCounter):
            self.imeFieldCounter = fieldCounter
            self.hasImeFieldCounter = true
            
        case .remoteImeBatchEdit(let ic, let fc, _):
            if !hasImeCounter { self.imeCounter = ic }
            if !hasImeFieldCounter { self.imeFieldCounter = fc }
            
        case .remoteSetVolumeLevel(let vol):
            self.currentVolumeMax = vol.volumeMax
            self.currentVolumeLevel = vol.volumeLevel
            self.isMuted = vol.volumeMuted
            
        case .remoteError(let errVal):
            NSLog("[AndroidTV_CONNECT] Server sent remote_error(value=%d)", errVal ? 1 : 0)
            
        default:
            break
        }
    }
    
    private func handleControlDisconnect(
        host: String,
        deviceName: String,
        port: UInt16,
        epoch: Int,
        reason: String,
        canFallbackToPairing: Bool
    ) {
        guard epoch == connectionEpoch else { return }
        
        connectTimeoutItem?.cancel()
        connectTimeoutItem = nil
        stopIdleWatchdog()
        
        let conn = controlConnection
        controlConnection = nil
        networkQueue.async { conn?.cancel() }
        receiveBuffer.removeAll(keepingCapacity: false)
        
        let wasConnected = isConnected
        isConnected = false
        
        if userInitiatedDisconnect {
            delegate?.androidClient(self, didChangeState: .disconnected)
            return
        }
        
        if canFallbackToPairing {
            NSLog("[AndroidTV_CONNECT] Control auth failed before start (%@). Clearing stale pairing record and falling back to Polo pairing.", reason)
            let key = deviceKey(host: host, deviceName: deviceName)
            certificateManager.removePairedRecord(for: key)
            startPairingFlow(host: host, deviceName: deviceName, pairingPort: port &+ 1, epoch: epoch)
            return
        }
        
        if wasConnected {
            // 运行中意外断线，静默自动重连
            delegate?.androidClient(self, didChangeState: .connecting(deviceName: deviceName, mode: .nativeOnly))
            scheduleAutoReconnect(host: host, deviceName: deviceName, port: port, epoch: epoch)
        } else {
            delegate?.androidClient(self, didChangeState: .failed(error: reason))
        }
    }
    
    private func scheduleAutoReconnect(host: String, deviceName: String, port: UInt16, epoch: Int) {
        autoReconnectWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self = self, epoch == self.connectionEpoch, !self.userInitiatedDisconnect else { return }
            self.connectToControlPort(host: host, deviceName: deviceName, port: port, epoch: epoch, fallbackToPairingOnAuthFailure: false)
        }
        autoReconnectWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: item)
    }
    
    // MARK: - Idle Watchdog (对应服务端 5s ping / 16s 超时)
    
    private func startIdleWatchdog(host: String, deviceName: String, port: UInt16, epoch: Int) {
        stopIdleWatchdog()
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + 6.0, repeating: 5.0)
        timer.setEventHandler { [weak self] in
            guard let self = self, epoch == self.connectionEpoch, self.isConnected else { return }
            if Date().timeIntervalSince(self.lastServerActivity) > 18.0 {
                NSLog("[AndroidTV_CONNECT] Idle watchdog triggered (>18s without server ping/activity), reconnecting")
                self.handleControlDisconnect(host: host, deviceName: deviceName, port: port, epoch: epoch, reason: "心跳超时", canFallbackToPairing: false)
            }
        }
        timer.resume()
        idleWatchdogTimer = timer
    }
    
    private func stopIdleWatchdog() {
        idleWatchdogTimer?.cancel()
        idleWatchdogTimer = nil
    }
    
    // MARK: - Outbound Remote Commands
    
    private func sendRemoteMessage(_ message: AndroidTVRemoteMessage) {
        guard let conn = controlConnection else { return }
        let framed = ProtobufCodec.wrapLengthPrefixed(message.encode())
        networkQueue.async {
            conn.send(content: framed, completion: .contentProcessed { _ in })
        }
    }
    
    public func sendKey(_ keyCode: AndroidTVKeyCode, direction: AndroidTVKeyDirection = .short) {
        guard isConnected else { return }
        lastServerActivity = Date()
        sendRemoteMessage(.remoteKeyInject(keyCode: keyCode.rawValue, direction: direction))
    }
    
    private func mapDirection(_ action: KeyAction) -> AndroidTVKeyDirection {
        switch action {
        case .press: return .startLong
        case .release: return .endLong
        case .tap: return .short
        }
    }
    
    public func sendDPad(direction: DPadDirection, action: KeyAction = .tap) {
        let code: AndroidTVKeyCode = {
            switch direction {
            case .up: return .dpadUp
            case .down: return .dpadDown
            case .left: return .dpadLeft
            case .right: return .dpadRight
            }
        }()
        sendKey(code, direction: mapDirection(action))
    }
    
    public func sendSelect(action: KeyAction = .tap) {
        sendKey(.dpadCenter, direction: mapDirection(action))
    }
    
    public func sendSystemKey(_ key: SystemKey, action: KeyAction = .tap) {
        let dir = mapDirection(action)
        let code: AndroidTVKeyCode = {
            switch key {
            case .home: return .home
            case .menu: return .back
            case .volumeUp: return .volumeUp
            case .volumeDown: return .volumeDown
            case .mute: return .volumeMute
            case .playPause: return .mediaPlayPause
            case .up: return .dpadUp
            case .down: return .dpadDown
            case .left: return .dpadLeft
            case .right: return .dpadRight
            case .select: return .dpadCenter
            case .power: return .power
            }
        }()
        sendKey(code, direction: dir)
    }
    
    public func sendSpecialKey(_ key: SpecialKey) {
        switch key {
        case .enter:
            sendKey(.enter, direction: .short)
        case .escape:
            sendKey(.back, direction: .short)
        case .backspace:
            sendKey(.del, direction: .short)
        case .space:
            sendKey(.space, direction: .short)
        }
    }
    
    public func sendMediaAction(_ action: MediaAction, value: Double? = nil) {
        switch action {
        case .play:
            sendKey(.mediaPlay)
        case .pause:
            sendKey(.mediaPause)
        case .stop:
            sendKey(.mediaStop)
        case .seekRelative:
            if let v = value {
                sendKey(v >= 0 ? .mediaFastForward : .mediaRewind)
            }
        case .seekPercent, .setRate, .toggleSubtitle:
            break
        }
    }
    
    public func sendText(_ text: String) {
        guard isConnected, !text.isEmpty else { return }
        lastServerActivity = Date()
        sendRemoteMessage(.remoteImeBatchEdit(imeCounter: imeCounter, fieldCounter: imeFieldCounter, text: text))
    }
    
    public func sendLaunchApp(appLink: String, completion: ((Bool) -> Void)? = nil) {
        guard isConnected, !appLink.isEmpty else {
            completion?(false)
            return
        }
        lastServerActivity = Date()
        sendRemoteMessage(.remoteAppLinkLaunchRequest(appLink: appLink))
        completion?(true)
    }
}
