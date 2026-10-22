//
//  DualModeRemoteCoordinator.swift
//  HSBWatchCompanion
//

import Foundation
import CoreGraphics
import Network

@MainActor
public final class DualModeRemoteCoordinator: NSObject, DualModeRemoteCoordinatorProtocol {
    public static let shared = DualModeRemoteCoordinator()
    
    public weak var delegate: DualModeRemoteCoordinatorDelegate?
    
    public let screenClient = HSBBrowserProtocolClient()
    public let nativeClient = AppleTVNativeClient()
    public let stateMachine = HSBConnectionStateMachine()
    public private(set) lazy var router = RemoteCommandRouter(coordinator: self)
    
    // 纯原生通道单连接模式 (Single Unified Native Connection)
    public var currentMode: HSBRemoteMode = .nativeOnly
    
    // 当前目标设备是否为 Mac 终端 (方案 A: 原生媒体控制)
    public var isCurrentTargetMac: Bool = false
    public var currentTargetDeviceName: String = ""
    public var currentTargetHost: String = "127.0.0.1"
    
    public func setCurrentTarget(device: HSBDiscoveredAppleTV) {
        self.isCurrentTargetMac = device.isMacDevice
        self.currentTargetDeviceName = device.name
        self.currentTargetHost = device.host
        if device.isMacDevice {
            self.nativeClient.disconnect()
            MacMediaCommandDispatcher.currentTargetHost = device.host
            self.currentMode = .nativeOnly
            self.stateMachine.handle(event: .socketConnected(deviceName: device.name, mode: .nativeOnly))
            NotificationCenter.default.post(
                name: Notification.Name("HSBConnectionStateDidChangeNotification"),
                object: self,
                userInfo: ["state": HSBConnectionState.ready(deviceName: device.name, mode: .nativeOnly)]
            )
        }
    }
    
    public var currentState: HSBConnectionState {
        return stateMachine.currentState
    }
    
    private var pendingPINCompletion: ((String) -> Void)?
    private var pendingPINDeviceName: String?
    
    public override init() {
        super.init()
        screenClient.delegate = self
        nativeClient.delegate = self
        stateMachine.delegate = self
        
        setupUnifiedConnectionObserver()
    }
    
    // MARK: - Unified Connection Lifecycle & Bonding
    private func setupUnifiedConnectionObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleUnifiedConnectionStateChanged(_:)),
            name: .HSBTVOSConnectionState,
            object: nil
        )
        
        let legacyMgr = HSBTVOSConnectionManager.shared()
        if legacyMgr.isConnected {
            let deviceName = legacyMgr.deviceName ?? "Apple TV"
            self.stateMachine.handle(event: .requestConnect(deviceName: deviceName, mode: self.currentMode))
            self.stateMachine.handle(event: .socketConnected(deviceName: deviceName, mode: self.currentMode))
        }
    }
    
    @objc private func handleUnifiedConnectionStateChanged(_ note: Notification) {
        guard !isCurrentTargetMac else {
            return
        }
        let legacyMgr = HSBTVOSConnectionManager.shared()
        let deviceName = legacyMgr.deviceName ?? "Apple TV"
        
        if legacyMgr.isConnected {
            if !self.nativeClient.isConnected {
                self.currentMode = .dual
            }
            self.stateMachine.handle(event: .requestConnect(deviceName: deviceName, mode: self.currentMode))
            self.stateMachine.handle(event: .socketConnected(deviceName: deviceName, mode: self.currentMode))
            
            // 自动并发连接/唤醒 Native 系统通道（实现一键双模聚合）
            if !self.nativeClient.isConnected {
                var host = "apple-tv.local"
                if let ep = legacyMgr.currentEndpoint {
                    if nw_endpoint_get_type(ep) == nw_endpoint_type_host {
                        host = String(cString: nw_endpoint_get_hostname(ep))
                    } else if nw_endpoint_get_type(ep) == nw_endpoint_type_bonjour_service {
                        host = "\(String(cString: nw_endpoint_get_bonjour_service_name(ep))).local"
                    }
                }
                self.connectToNative(host: host, deviceName: deviceName)
            }
        } else {
            if currentMode == .screenOnly || !nativeClient.isConnected {
                self.stateMachine.handle(event: .requestDisconnect(reason: "Unified display disconnected"))
            }
        }
    }
    
    /// 统一连接入口：单次触发，双模静默聚合
    public func unifiedConnect(endpoint: nw_endpoint_t, deviceName: String) {
        let legacyMgr = HSBTVOSConnectionManager.shared()
        legacyMgr.connect(to: endpoint, deviceName: deviceName)
        
        var host = "apple-tv.local"
        var port: UInt16 = 49152
        if nw_endpoint_get_type(endpoint) == nw_endpoint_type_host {
            host = String(cString: nw_endpoint_get_hostname(endpoint))
            let p = nw_endpoint_get_port(endpoint)
            if p > 0 { port = p }
        } else if nw_endpoint_get_type(endpoint) == nw_endpoint_type_bonjour_service {
            host = "\(String(cString: nw_endpoint_get_bonjour_service_name(endpoint))).local"
        }
        connectToNative(host: host, deviceName: deviceName, port: port)
    }
    
    public func connectToScreen(endpoint: nw_endpoint_t, deviceName: String) {
        stateMachine.handle(event: .requestConnect(deviceName: deviceName, mode: currentMode))
        screenClient.connect(to: endpoint, deviceName: deviceName)
    }
    
    public func connectToNative(host: String, deviceName: String, port: UInt16 = 49152) {
        nativeClient.connect(host: host, deviceName: deviceName, port: port)
    }
    
    // MARK: - Auto Discovery & Quick Reconnect
    @MainActor
    public func startAutoDiscoveryAndConnect() {
        guard !isCurrentTargetMac else {
            return
        }
        guard !nativeClient.isConnected, !nativeClient.isPairing else {
            return
        }
        
        // 1. 如果有上次成功连接的 IP 与名字，且已有配对凭据，先尝试快速重连
        if let lastHost = UserDefaults.standard.string(forKey: "HSBLastConnectedTVHost"),
           let lastName = UserDefaults.standard.string(forKey: "HSBLastConnectedTVName"),
           nativeClient.credentialStore.hasCredentials(for: lastName) {
            NSLog("[DualMode] Quick reconnecting to cached Apple TV: %@ at %@", lastName, lastHost)
            currentTargetDeviceName = lastName
            connectToNative(host: lastHost, deviceName: lastName)
        }
        
        // 2. 同时启动局域网 Bonjour 硬件扫描，供设备列表选择
        NSLog("[DualMode] Starting Apple TV Bonjour hardware scan...")
        HSBAppleTVDiscovery.shared.startScanning { [weak self] devices in
            guard let self = self else { return }
            guard !self.isCurrentTargetMac else { return }
            guard !self.nativeClient.isConnected, !self.nativeClient.isPairing else { return }
            
            let tvCandidates = devices.filter { !$0.isMacDevice }
            // 仅对已配对过的设备自动恢复连接
            if let paired = tvCandidates.first(where: { self.nativeClient.credentialStore.hasCredentials(for: $0.name) }) {
                NSLog("[DualMode] Auto-reconnecting to paired device: %@", paired.name)
                self.currentTargetDeviceName = paired.name
                self.connectToNative(host: paired.host, deviceName: paired.name, port: paired.port)
            }
        }
    }
    
    public func disconnectAll() {
        screenClient.disconnect()
        nativeClient.disconnect(userInitiated: true)
        let legacyMgr = HSBTVOSConnectionManager.shared()
        if legacyMgr.isConnected {
            legacyMgr.disconnect()
        }
        self.isCurrentTargetMac = false
        self.currentTargetDeviceName = ""
        self.currentTargetHost = ""
        stateMachine.handle(event: .requestDisconnect(reason: "User requested disconnect"))
    }
    
    // MARK: - Router Delegated Remote Commands
    public func sendDPad(direction: DPadDirection, action: KeyAction = .tap) {
        router.sendDPad(direction: direction, action: action)
    }
    
    public func sendSelect(action: KeyAction = .tap) {
        router.sendSelect(action: action)
    }
    
    public func sendCursorPan(dx: CGFloat, dy: CGFloat) {
        router.sendCursorPan(dx: dx, dy: dy)
    }
    
    public func sendTap(mode: Int = 1, point: CGPoint? = nil) {
        router.sendTap(mode: mode, point: point)
    }
    
    public func sendScroll(dx: CGFloat, dy: CGFloat) {
        router.sendScroll(dx: dx, dy: dy)
    }
    
    public func sendDrag(state: DragState, dx: CGFloat, dy: CGFloat) {
        router.sendDrag(state: state, dx: dx, dy: dy)
    }
    
    public func sendZoom(scale: CGFloat) {
        router.sendZoom(scale: scale)
    }
    
    public func sendTextInput(text: String, isAtomicReplace: Bool = false) {
        router.sendTextInput(text: text, isAtomicReplace: isAtomicReplace)
    }
    
    public func sendKeyCommand(key: SpecialKey) {
        router.sendKeyCommand(key: key)
    }
    
    public func sendSystemKey(_ key: SystemKey) {
        router.sendSystemKey(key)
    }
    
    public func wakeDevice(host: String, completion: ((Bool) -> Void)? = nil) {
        nativeClient.wakeDevice(host: host, completion: completion)
    }
    
    public func sendPageAction(_ action: PageAction) {
        router.sendPageAction(action)
    }
    
    public func executeJavaScript(_ script: String, completion: ((Result<String, Error>) -> Void)? = nil) {
        screenClient.send(command: .executeJS(script: script)) { success in
            if success {
                completion?(.success("dispatched"))
            } else {
                completion?(.failure(NSError(domain: "DualModeCoordinator", code: -1, userInfo: [NSLocalizedDescriptionKey: "Execute JS failed"])))
            }
        }
    }
    
    public func sendMediaControl(_ action: MediaAction, value: Double? = nil) {
        screenClient.send(command: .media(action: action, value: value))
    }
    
    public func launchApp(bundleID: String, url: String? = nil, completion: ((Bool) -> Void)? = nil) {
        nativeClient.launchApp(bundleID: bundleID, url: url) { success in
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: Notification.Name("HSBAppLaunchedNotification"),
                    object: bundleID
                )
                completion?(success)
            }
        }
    }
    
    public func submitNativePIN(_ pin: String, completion: ((Bool) -> Void)? = nil) {
        nativeClient.submitPIN(pin) { [weak self] success in
            if success {
                self?.stateMachine.handle(event: .pairingSucceeded)
            }
            completion?(success)
        }
    }
    
    @objc public func clearNativeCredentials(for deviceName: String) {
        nativeClient.clearCredentials(for: deviceName)
    }
}

// MARK: - Delegates
extension DualModeRemoteCoordinator: HSBBrowserProtocolClientDelegate {
    public func browserClient(_ client: HSBBrowserProtocolClient, didChangeState state: HSBConnectionState) {
        switch state {
        case .ready(let name, let mode):
            let targetMode = self.nativeClient.isConnected ? .dual : mode
            stateMachine.handle(event: .socketConnected(deviceName: name, mode: targetMode))
        case .failed(let err):
            if currentMode == .dual && nativeClient.isConnected {
                let name = nativeClient.currentDeviceName ?? "Apple TV"
                stateMachine.handle(event: .socketConnected(deviceName: name, mode: .nativeOnly))
            } else {
                stateMachine.handle(event: .connectionLost(error: err))
            }
        case .disconnected:
            if currentMode == .dual && nativeClient.isConnected {
                let name = nativeClient.currentDeviceName ?? "Apple TV"
                stateMachine.handle(event: .socketConnected(deviceName: name, mode: .nativeOnly))
            } else {
                stateMachine.handle(event: .requestDisconnect(reason: "Disconnected"))
            }
        case .connecting(let name, let mode):
            stateMachine.handle(event: .requestConnect(deviceName: name, mode: mode))
        default:
            break
        }
    }
    
    public func browserClient(_ client: HSBBrowserProtocolClient, didReceiveMessage message: [String: Any]) {
        delegate?.coordinator(self, didReceiveScreenMessage: message)
    }
}

extension DualModeRemoteCoordinator: AppleTVNativeClientDelegate {
    public func nativeClient(_ client: AppleTVNativeClient, didChangeState state: HSBConnectionState) {
        NSLog("[DualMode] nativeClient didChangeState: %@", "\(state)")
        if currentMode == .nativeOnly || currentMode == .dual {
            switch state {
            case .ready(let name, _):
                if name.lowercased().contains("mac") {
                    self.isCurrentTargetMac = true
                }
                self.currentTargetDeviceName = name
                UserDefaults.standard.set(name, forKey: "HSBLastConnectedTVName")
                if let h = client.currentHost {
                    UserDefaults.standard.set(h, forKey: "HSBLastConnectedTVHost")
                }
                let targetMode: HSBRemoteMode = (currentMode == .dual && screenClient.isConnected) ? .dual : .nativeOnly
                stateMachine.handle(event: .socketConnected(deviceName: name, mode: targetMode))
                delegate?.coordinator(self, didChangeState: .ready(deviceName: name, mode: targetMode))
                NotificationCenter.default.post(
                    name: Notification.Name("HSBConnectionStateDidChangeNotification"),
                    object: self,
                    userInfo: ["state": HSBConnectionState.ready(deviceName: name, mode: targetMode)]
                )
            case .pairing(_, let pinNeeded):
                stateMachine.handle(event: .pairingRequired(pinNeeded: pinNeeded))
            case .failed(let err):
                if currentMode == .nativeOnly || !screenClient.isConnected {
                    stateMachine.handle(event: .connectionLost(error: err))
                }
            case .disconnected:
                if currentMode == .nativeOnly || !screenClient.isConnected {
                    stateMachine.handle(event: .requestDisconnect(reason: "Native disconnected"))
                }
            case .connecting(let name, let mode):
                stateMachine.handle(event: .requestConnect(deviceName: name, mode: mode))
            default:
                break
            }
        }
    }
    
    @MainActor
    public func reopenNativePINAlertIfNeeded() {
        guard let completion = pendingPINCompletion else {
            NSLog("[DualMode] No pending PIN completion to reopen")
            return
        }
        let name = pendingPINDeviceName ?? "Apple TV"
        NSLog("[DualMode] Reopening native PIN alert for %@", name)
        HSBNativePINAlertPresenter.shared.presentPINAlert(deviceName: name) { [weak self] pin in
            self?.pendingPINCompletion = nil
            self?.pendingPINDeviceName = nil
            completion(pin)
        }
    }

    public func nativeClient(_ client: AppleTVNativeClient, didRequirePINCompletion completion: @escaping (String) -> Void) {
        let fallback = currentTargetDeviceName.isEmpty ? "Apple TV" : currentTargetDeviceName
        let name = client.currentDeviceName ?? fallback
        NSLog("[ATV_CONNECT] Native PIN required for %@. Presenting PIN alert directly from Swift...", name)
        
        self.pendingPINCompletion = completion
        self.pendingPINDeviceName = name
        
        DispatchQueue.main.async {
            HSBNativePINAlertPresenter.shared.presentPINAlert(deviceName: name) { [weak self] pin in
                NSLog("[ATV_CONNECT] PIN entered: %@, submitting to native client", pin)
                self?.pendingPINCompletion = nil
                self?.pendingPINDeviceName = nil
                completion(pin)
            }
        }
        
        NotificationCenter.default.post(
            name: Notification.Name("HSBAppleTVNativePINRequiredNotification"),
            object: self,
            userInfo: ["name": name]
        )
    }
}

extension DualModeRemoteCoordinator: HSBConnectionStateMachineDelegate {
    public func stateMachine(_ sm: HSBConnectionStateMachine, didTransitionTo state: HSBConnectionState) {
        delegate?.coordinator(self, didChangeState: state)
        NotificationCenter.default.post(
            name: Notification.Name("HSBConnectionStateDidChangeNotification"),
            object: self,
            userInfo: ["state": state]
        )
    }
}
