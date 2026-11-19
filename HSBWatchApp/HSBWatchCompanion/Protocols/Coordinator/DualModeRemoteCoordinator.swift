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
    public let androidClient = AndroidTVNativeClient()
    public let stateMachine = HSBConnectionStateMachine()
    public private(set) lazy var router = RemoteCommandRouter(coordinator: self)
    
    // 纯原生通道单连接模式 (Single Unified Native Connection)
    public var currentMode: HSBRemoteMode = .nativeOnly
    
    // 当前目标设备类型与上下文
    public var isCurrentTargetMac: Bool = false
    public var isCurrentTargetAndroidTV: Bool = false
    public var isCurrentTargetNativeAndroidTV: Bool = false
    public var currentTargetDeviceName: String = ""
    public var currentTargetHost: String = ""
    
    public var isAnyNativeConnected: Bool {
        return nativeClient.isConnected || androidClient.isConnected
    }
    
    public var isAnyNativePairing: Bool {
        return nativeClient.isPairing || androidClient.isPairing
    }
    
    public func setCurrentTarget(device: HSBDiscoveredAppleTV) {
        self.isCurrentTargetMac = device.isMacDevice
        self.isCurrentTargetAndroidTV = device.isAndroidTV
        self.isCurrentTargetNativeAndroidTV = device.isNativeAndroidTV
        self.currentTargetDeviceName = device.name
        self.currentTargetHost = device.host
        if device.isMacDevice {
            self.nativeClient.disconnect(userInitiated: true)
            self.androidClient.disconnect(userInitiated: true)
            MacMediaCommandDispatcher.currentTargetHost = device.host
            MacMediaCommandDispatcher.currentTargetDeviceName = device.name
            MacMediaCommandDispatcher.setupRouteObserverIfNeeded()
            self.currentMode = .nativeOnly
            
            // 真实校验：只有当前系统音频路由确实输出到该 Mac 时才为 ready，否则为等待隔空投送状态
            let isRouted = MacMediaCommandDispatcher.isConnectedToTarget(deviceName: device.name)
            if isRouted {
                self.stateMachine.handle(event: .socketConnected(deviceName: device.name, mode: .nativeOnly))
                NotificationCenter.default.post(
                    name: Notification.Name("HSBConnectionStateDidChangeNotification"),
                    object: self,
                    userInfo: ["state": HSBConnectionState.ready(deviceName: device.name, mode: .nativeOnly)]
                )
            } else {
                self.stateMachine.handle(event: .requestDisconnect(reason: "Waiting for AirPlay connection"))
                NotificationCenter.default.post(
                    name: Notification.Name("HSBConnectionStateDidChangeNotification"),
                    object: self,
                    userInfo: ["state": HSBConnectionState.disconnected]
                )
            }
        } else if device.isNativeAndroidTV {
            self.nativeClient.disconnect(userInitiated: true)
            self.currentMode = device.isBrowserApp ? .dual : .nativeOnly
            self.stateMachine.handle(event: .requestConnect(deviceName: device.name, mode: self.currentMode))
        } else if device.isAndroidTV {
            self.nativeClient.disconnect(userInitiated: true)
            self.androidClient.disconnect(userInitiated: true)
            self.currentMode = .screenOnly
            self.stateMachine.handle(event: .requestConnect(deviceName: device.name, mode: .screenOnly))
        } else {
            self.androidClient.disconnect(userInitiated: true)
        }
    }
    
    public var currentState: HSBConnectionState {
        return stateMachine.currentState
    }
    
    private var pendingPINCompletion: ((String) -> Void)?
    private var pendingPINDeviceName: String?
    private var pendingPINIsAndroidTV: Bool = false
    
    public override init() {
        super.init()
        screenClient.delegate = self
        nativeClient.delegate = self
        androidClient.delegate = self
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
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAirPlayRouteChangeNotification),
            name: MacMediaCommandDispatcher.airPlayRouteChangeNotification,
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
        let deviceName = legacyMgr.deviceName ?? (currentTargetDeviceName.isEmpty ? "TV" : currentTargetDeviceName)
        
        if legacyMgr.isConnected {
            if isAnyNativeConnected {
                self.currentMode = .dual
            } else if isCurrentTargetAndroidTV && !isCurrentTargetNativeAndroidTV {
                self.currentMode = .screenOnly
            } else {
                self.currentMode = .dual
            }
            self.stateMachine.handle(event: .requestConnect(deviceName: deviceName, mode: self.currentMode))
            self.stateMachine.handle(event: .socketConnected(deviceName: deviceName, mode: self.currentMode))
            
            // 自动并发连接/唤醒 Native 系统通道（实现一键双模聚合，按设备系统精准区分 Apple TV 与 Android TV）
            if !self.isAnyNativeConnected {
                var host = currentTargetHost.isEmpty ? "apple-tv.local" : currentTargetHost
                if let ep = legacyMgr.currentEndpoint {
                    if nw_endpoint_get_type(ep) == nw_endpoint_type_host {
                        host = String(cString: nw_endpoint_get_hostname(ep))
                    } else if nw_endpoint_get_type(ep) == nw_endpoint_type_bonjour_service {
                        host = "\(String(cString: nw_endpoint_get_bonjour_service_name(ep))).local"
                    }
                }
                if isCurrentTargetNativeAndroidTV {
                    self.connectToAndroidNative(host: host, deviceName: deviceName)
                } else if !isCurrentTargetAndroidTV {
                    self.connectToNative(host: host, deviceName: deviceName)
                }
            }
        } else {
            if currentMode == .screenOnly || !isAnyNativeConnected {
                self.stateMachine.handle(event: .requestDisconnect(reason: "Unified display disconnected"))
            }
        }
    }
    
    @objc private func handleAirPlayRouteChangeNotification() {
        guard isCurrentTargetMac else { return }
        let isConnected = MacMediaCommandDispatcher.isConnectedToTarget(deviceName: currentTargetDeviceName)
        NSLog("[DualMode] AirPlay route update for Mac: isConnected=%d", isConnected ? 1 : 0)
        if isConnected {
            self.stateMachine.handle(event: .socketConnected(deviceName: currentTargetDeviceName, mode: .nativeOnly))
            NotificationCenter.default.post(
                name: Notification.Name("HSBConnectionStateDidChangeNotification"),
                object: self,
                userInfo: ["state": HSBConnectionState.ready(deviceName: currentTargetDeviceName, mode: .nativeOnly)]
            )
        } else {
            self.stateMachine.handle(event: .requestDisconnect(reason: "AirPlay disconnected"))
            NotificationCenter.default.post(
                name: Notification.Name("HSBConnectionStateDidChangeNotification"),
                object: self,
                userInfo: ["state": HSBConnectionState.disconnected]
            )
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
    
    public func connectToAndroidNative(host: String, deviceName: String, port: UInt16 = 6466) {
        androidClient.connect(host: host, deviceName: deviceName, port: port)
    }
    
    // MARK: - Auto Discovery & Quick Reconnect
    @MainActor
    public func startAutoDiscoveryAndConnect() {
        guard !isCurrentTargetMac else {
            return
        }
        guard !isAnyNativeConnected, !isAnyNativePairing else {
            return
        }
        
        // 1. 如果有上次成功连接的 IP 与名字，且已有配对凭据，先尝试快速重连
        if let lastHost = UserDefaults.standard.string(forKey: "HSBLastConnectedTVHost"),
           let lastName = UserDefaults.standard.string(forKey: "HSBLastConnectedTVName") {
            let lastIsAndroid = UserDefaults.standard.bool(forKey: "HSBLastConnectedTVIsAndroid")
            if lastIsAndroid, androidClient.certificateManager.isPaired(deviceKey: lastName) {
                NSLog("[DualMode] Quick reconnecting to cached Android TV: %@ at %@", lastName, lastHost)
                currentTargetDeviceName = lastName
                isCurrentTargetAndroidTV = true
                isCurrentTargetNativeAndroidTV = true
                connectToAndroidNative(host: lastHost, deviceName: lastName)
            } else if !lastIsAndroid, nativeClient.credentialStore.hasCredentials(for: lastName) {
                NSLog("[DualMode] Quick reconnecting to cached Apple TV: %@ at %@", lastName, lastHost)
                currentTargetDeviceName = lastName
                connectToNative(host: lastHost, deviceName: lastName)
            }
        }
        
        // 2. 同时启动局域网 Bonjour 硬件扫描，供设备列表选择
        NSLog("[DualMode] Starting TV Bonjour hardware scan...")
        HSBAppleTVDiscovery.shared.startScanning(observerId: "coordinator") { [weak self] devices in
            guard let self = self else { return }
            guard !self.isCurrentTargetMac else { return }
            guard !self.isAnyNativeConnected, !self.isAnyNativePairing else { return }
            
            let tvCandidates = devices.filter { !$0.isMacDevice }
            // 仅对已配对过的设备自动恢复连接
            if let pairedApple = tvCandidates.first(where: { $0.isNativeAppleTV && self.nativeClient.credentialStore.hasCredentials(for: $0.name) }) {
                NSLog("[DualMode] Auto-reconnecting to paired Apple TV: %@", pairedApple.name)
                self.setCurrentTarget(device: pairedApple)
                self.connectToNative(host: pairedApple.host, deviceName: pairedApple.name, port: pairedApple.port)
            } else if let pairedAndroid = tvCandidates.first(where: { $0.isNativeAndroidTV && self.androidClient.certificateManager.isPaired(deviceKey: $0.name) }) {
                NSLog("[DualMode] Auto-reconnecting to paired Android TV: %@", pairedAndroid.name)
                self.setCurrentTarget(device: pairedAndroid)
                let targetPort = pairedAndroid.androidRemotePort > 0 ? pairedAndroid.androidRemotePort : HSBRemoteConstants.androidTVDefaultPort
                self.connectToAndroidNative(host: pairedAndroid.host, deviceName: pairedAndroid.name, port: targetPort)
            }
        }
    }
    
    public func disconnectAll() {
        screenClient.disconnect()
        nativeClient.disconnect(userInitiated: true)
        androidClient.disconnect(userInitiated: true)
        let legacyMgr = HSBTVOSConnectionManager.shared()
        if legacyMgr.isConnected {
            legacyMgr.disconnect()
        }
        self.isCurrentTargetMac = false
        self.isCurrentTargetAndroidTV = false
        self.isCurrentTargetNativeAndroidTV = false
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
        router.sendSystemKey(key, action: .tap)
    }
    
    public func sendSystemKey(_ key: SystemKey, action: KeyAction) {
        router.sendSystemKey(key, action: action)
    }
    
    public func sendLongPressKey(_ key: SystemKey, duration: TimeInterval = 0.8) {
        router.sendLongPressKey(key, duration: duration)
    }
    
    public func sendLongPressSelect(duration: TimeInterval = 0.8) {
        router.sendLongPressSelect(duration: duration)
    }
    
    public var isSleeping: Bool {
        if androidClient.isConnected {
            return !androidClient.isTVOn
        }
        return nativeClient.isSleeping
    }
    
    public func wakeAndConnect(completion: ((Bool) -> Void)? = nil) {
        if isCurrentTargetNativeAndroidTV || androidClient.isConnected {
            if androidClient.isConnected {
                androidClient.sendKey(.wakeup)
                completion?(true)
            } else if !currentTargetHost.isEmpty {
                connectToAndroidNative(host: currentTargetHost, deviceName: currentTargetDeviceName)
                completion?(true)
            } else {
                completion?(false)
            }
            return
        }
        nativeClient.wakeAndConnect(completion: completion)
    }
    
    public func wakeDevice(host: String, completion: ((Bool) -> Void)? = nil) {
        if isCurrentTargetNativeAndroidTV {
            if androidClient.isConnected {
                androidClient.sendKey(.wakeup)
            }
            completion?(true)
            return
        }
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
        if androidClient.isConnected && !screenClient.isConnected {
            androidClient.sendMediaAction(action, value: value)
            return
        }
        screenClient.send(command: .media(action: action, value: value))
    }
    
    public func launchApp(bundleID: String, url: String? = nil, completion: ((Bool) -> Void)? = nil) {
        if nativeClient.isConnected {
            nativeClient.launchApp(bundleID: bundleID, url: url) { success in
                DispatchQueue.main.async {
                    if success {
                        NotificationCenter.default.post(
                            name: Notification.Name("HSBAppLaunchedNotification"),
                            object: bundleID
                        )
                    }
                    completion?(success)
                }
            }
        } else if androidClient.isConnected {
            let targetLink = (url != nil && !url!.isEmpty) ? url! : bundleID
            androidClient.sendLaunchApp(appLink: targetLink) { success in
                DispatchQueue.main.async {
                    if success {
                        NotificationCenter.default.post(
                            name: Notification.Name("HSBAppLaunchedNotification"),
                            object: bundleID
                        )
                    }
                    completion?(success)
                }
            }
        } else if HSBTVOSConnectionManager.shared().isConnected {
            if let u = url, !u.isEmpty {
                HSBTVOSConnectionManager.shared().sendSimulateAction(.openUrl, withParams: ["url": u])
            }
            NotificationCenter.default.post(
                name: Notification.Name("HSBAppLaunchedNotification"),
                object: bundleID
            )
            completion?(true)
        } else {
            completion?(false)
        }
    }
    
    public func submitNativePIN(_ pin: String, completion: ((Bool) -> Void)? = nil) {
        if androidClient.isPairing || pendingPINIsAndroidTV {
            androidClient.submitPIN(pin) { [weak self] success in
                if success {
                    self?.stateMachine.handle(event: .pairingSucceeded)
                }
                completion?(success)
            }
            return
        }
        nativeClient.submitPIN(pin) { [weak self] success in
            if success {
                self?.stateMachine.handle(event: .pairingSucceeded)
            }
            completion?(success)
        }
    }
    
    @objc public func clearNativeCredentials(for deviceName: String) {
        nativeClient.clearCredentials(for: deviceName)
        androidClient.clearCredentials(for: deviceName)
    }
}

// MARK: - Delegates
extension DualModeRemoteCoordinator: HSBBrowserProtocolClientDelegate {
    public func browserClient(_ client: HSBBrowserProtocolClient, didChangeState state: HSBConnectionState) {
        switch state {
        case .ready(let name, let mode):
            let targetMode = self.isAnyNativeConnected ? .dual : mode
            stateMachine.handle(event: .socketConnected(deviceName: name, mode: targetMode))
        case .failed(let err):
            if currentMode == .dual && isAnyNativeConnected {
                let name = nativeClient.currentDeviceName ?? androidClient.currentDeviceName ?? "TV"
                stateMachine.handle(event: .socketConnected(deviceName: name, mode: .nativeOnly))
            } else {
                stateMachine.handle(event: .connectionLost(error: err))
            }
        case .disconnected:
            if currentMode == .dual && isAnyNativeConnected {
                let name = nativeClient.currentDeviceName ?? androidClient.currentDeviceName ?? "TV"
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

extension DualModeRemoteCoordinator {
    fileprivate func handleNativeClientStateChange(_ state: HSBConnectionState, host: String?, isAndroid: Bool) {
        if currentMode == .nativeOnly || currentMode == .dual {
            switch state {
            case .ready(let name, _):
                if name.lowercased().contains("mac") {
                    self.isCurrentTargetMac = true
                }
                self.currentTargetDeviceName = name
                UserDefaults.standard.set(name, forKey: "HSBLastConnectedTVName")
                UserDefaults.standard.set(isAndroid, forKey: "HSBLastConnectedTVIsAndroid")
                if let h = host {
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
    
    fileprivate func presentNativePINPrompt(deviceName: String, isAndroidTV: Bool, completion: @escaping (String) -> Void) {
        self.pendingPINCompletion = completion
        self.pendingPINDeviceName = deviceName
        self.pendingPINIsAndroidTV = isAndroidTV
        
        DispatchQueue.main.async {
            HSBNativePINAlertPresenter.shared.presentPINAlert(deviceName: deviceName, isAndroidTV: isAndroidTV) { [weak self] pin in
                NSLog("[TV_CONNECT] PIN entered (android=%d): %@, submitting to client", isAndroidTV ? 1 : 0, pin)
                self?.pendingPINCompletion = nil
                self?.pendingPINDeviceName = nil
                self?.pendingPINIsAndroidTV = false
                completion(pin)
            }
        }
        
        NotificationCenter.default.post(
            name: Notification.Name("HSBAppleTVNativePINRequiredNotification"),
            object: self,
            userInfo: ["name": deviceName, "isAndroidTV": isAndroidTV]
        )
    }
    
    @MainActor
    public func reopenNativePINAlertIfNeeded() {
        guard let completion = pendingPINCompletion else {
            NSLog("[DualMode] No pending PIN completion to reopen")
            return
        }
        let isAndroid = pendingPINIsAndroidTV
        let name = pendingPINDeviceName ?? (isAndroid ? "Android TV" : "Apple TV")
        NSLog("[DualMode] Reopening native PIN alert for %@ (android=%d)", name, isAndroid ? 1 : 0)
        HSBNativePINAlertPresenter.shared.presentPINAlert(deviceName: name, isAndroidTV: isAndroid) { [weak self] pin in
            self?.pendingPINCompletion = nil
            self?.pendingPINDeviceName = nil
            self?.pendingPINIsAndroidTV = false
            completion(pin)
        }
    }
}

extension DualModeRemoteCoordinator: AppleTVNativeClientDelegate {
    public func nativeClient(_ client: AppleTVNativeClient, didChangeState state: HSBConnectionState) {
        NSLog("[DualMode] nativeClient didChangeState: %@", "\(state)")
        handleNativeClientStateChange(state, host: client.currentHost, isAndroid: false)
    }

    public func nativeClient(_ client: AppleTVNativeClient, didRequirePINCompletion completion: @escaping (String) -> Void) {
        let fallback = currentTargetDeviceName.isEmpty ? "Apple TV" : currentTargetDeviceName
        let name = client.currentDeviceName ?? fallback
        NSLog("[ATV_CONNECT] Native PIN required for %@. Presenting PIN alert directly from Swift...", name)
        presentNativePINPrompt(deviceName: name, isAndroidTV: false, completion: completion)
    }
}

extension DualModeRemoteCoordinator: AndroidTVNativeClientDelegate {
    public func androidClient(_ client: AndroidTVNativeClient, didChangeState state: HSBConnectionState) {
        NSLog("[DualMode] androidClient didChangeState: %@", "\(state)")
        handleNativeClientStateChange(state, host: client.currentHost, isAndroid: true)
    }
    
    public func androidClient(_ client: AndroidTVNativeClient, didRequirePINCompletion completion: @escaping (String) -> Void) {
        let fallback = currentTargetDeviceName.isEmpty ? "Android TV" : currentTargetDeviceName
        let name = client.currentDeviceName ?? fallback
        NSLog("[AndroidTV_CONNECT] Native PIN required for %@. Presenting hex PIN alert...", name)
        presentNativePINPrompt(deviceName: name, isAndroidTV: true, completion: completion)
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
