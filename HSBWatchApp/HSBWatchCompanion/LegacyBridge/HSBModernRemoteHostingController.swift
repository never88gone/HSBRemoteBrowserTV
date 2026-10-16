//
//  HSBModernRemoteHostingController.swift
//  HSBWatchCompanion
//

import UIKit
import SwiftUI
import Network

public final class HSBModernRemoteHostingController: UIHostingController<ModernRemoteContainerView> {
    
    public init() {
        super.init(rootView: ModernRemoteContainerView())
    }
    
    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "智能遥控器"
        self.view.backgroundColor = .clear
        
        // push 场景下系统已提供返回按钮；modal 场景由外部设置关闭按钮。
        // 仅当两者都不存在时才补充自定义返回，避免出现两个返回按钮。
        let hasSystemBack = (self.navigationController?.viewControllers.count ?? 0) > 1
        if !hasSystemBack && self.navigationItem.leftBarButtonItem == nil {
            let backItem = UIBarButtonItem(
                image: UIImage(systemName: "chevron.left"),
                style: .plain,
                target: self,
                action: #selector(didTapBackButton)
            )
            self.navigationItem.leftBarButtonItem = backItem
        }
        
        let keyboardItem = UIBarButtonItem(
            image: UIImage(systemName: "keyboard"),
            style: .plain,
            target: self,
            action: #selector(didTapKeyboardToggle)
        )
        let scanItem = UIBarButtonItem(
            image: UIImage(systemName: "qrcode.viewfinder"),
            style: .plain,
            target: self,
            action: #selector(didTapScanQRCode)
        )
        self.navigationItem.rightBarButtonItems = [keyboardItem, scanItem]
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didTapBackButton),
            name: Notification.Name("HSBExitRemotePageNotification"),
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didTapScanQRCode),
            name: Notification.Name("HSBOpenQRCodeScannerNotification"),
            object: nil
        )
    }
    
    @objc private func didTapBackButton() {
        self.navigationController?.popViewController(animated: true)
    }
    
    @objc private func didTapKeyboardToggle() {
        NotificationCenter.default.post(name: Notification.Name("HSBToggleRemoteKeyboardNotification"), object: nil)
    }
    
    @objc private func didTapScanQRCode() {
        let scanner = HSBQRCodeScannerViewController()
        scanner.delegate = self
        scanner.modalPresentationStyle = .fullScreen
        self.present(scanner, animated: true)
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.hidesBottomBarWhenPushed = true
    }
    
    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // 禁用侧滑返回手势，防止用户在触控板、画板或遥控按键上滑动时误触发页面退出
        self.navigationController?.interactivePopGestureRecognizer?.isEnabled = false
    }
    
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // 离开遥控器页面时恢复系统边缘返回手势
        self.navigationController?.interactivePopGestureRecognizer?.isEnabled = true
    }
}

@objc public final class HSBModernRemoteBridge: NSObject {
    
    @objc @MainActor public static func createModernRemoteViewController() -> UIViewController {
        return HSBModernRemoteHostingController()
    }
    
    @objc @MainActor public static func setCurrentTargetDevice(_ device: HSBDiscoveredAppleTV?) {
        if let dev = device {
            DualModeRemoteCoordinator.shared.setCurrentTarget(device: dev)
            if dev.isMacDevice {
                DualModeRemoteCoordinator.shared.currentMode = .nativeOnly
            }
        }
    }
    
    @objc @MainActor public static func connectWithHost(_ host: String, port: Int, deviceName: String) {
        if !DualModeRemoteCoordinator.shared.nativeClient.isConnected {
            DualModeRemoteCoordinator.shared.currentMode = .nativeOnly
            DualModeRemoteCoordinator.shared.connectToNative(host: host, deviceName: deviceName)
        }
        let targetPort: UInt16 = port > 0 ? UInt16(port) : HSBRemoteConstants.screenDefaultPort
        let screenEndpoint = nw_endpoint_create_host(host, "\(targetPort)")
        HSBTVOSConnectionManager.shared().connect(to: screenEndpoint, deviceName: deviceName)
        DualModeRemoteCoordinator.shared.screenClient.connect(to: screenEndpoint, deviceName: deviceName)
    }
    
    @objc(clearCredentialsForDevice:) @MainActor public static func clearCredentials(for deviceName: String) {
        DualModeRemoteCoordinator.shared.clearNativeCredentials(for: deviceName)
    }
    
    @objc @MainActor public static func connectToDiscoveredDevice(_ device: HSBDiscoveredAppleTV) {
        connectToDiscoveredDevice(device, timeout: 6.0, completion: nil)
    }
    
    @objc @MainActor public static func connectToDiscoveredDevice(
        _ device: HSBDiscoveredAppleTV,
        timeout: TimeInterval = 15.0,
        completion: ((Bool, String?) -> Void)? = nil
    ) {
        // 1. 如果已连通当前设备，直接主线程完成
        let isNative = DualModeRemoteCoordinator.shared.nativeClient.isConnected
        let isScreen = HSBTVOSConnectionManager.shared().isConnected || DualModeRemoteCoordinator.shared.screenClient.isConnected
        let currentHost = DualModeRemoteCoordinator.shared.nativeClient.currentHost
        if (isNative || isScreen), (currentHost == device.host || currentHost == nil) {
            DispatchQueue.main.async {
                completion?(true, nil)
            }
            return
        }
        
        // 方案 A：针对 macOS 原生媒体终端直连，设置目标设备并就绪
        if device.isMacDevice {
            DualModeRemoteCoordinator.shared.setCurrentTarget(device: device)
            DualModeRemoteCoordinator.shared.currentMode = .nativeOnly
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                completion?(true, nil)
            }
            return
        }
        
        var hasCompleted = false
        var observerTokens: [NSObjectProtocol] = []
        var isPairingPhase = false
        var timeoutWorkItem: DispatchWorkItem?
        let lock = NSLock()
        
        let finish = { (success: Bool, errorMsg: String?) in
            lock.lock()
            if hasCompleted {
                lock.unlock()
                return
            }
            hasCompleted = true
            lock.unlock()
            
            for token in observerTokens {
                NotificationCenter.default.removeObserver(token)
            }
            observerTokens.removeAll()
            timeoutWorkItem?.cancel()
            timeoutWorkItem = nil
            
            DispatchQueue.main.async {
                completion?(success, errorMsg)
            }
        }
        
        let startPairingTimeout = {
            guard !isPairingPhase else { return }
            isPairingPhase = true
            Log.companion.report("Bridge: Native pairing initiated, extending timeout to 90s for user PIN entry")
            timeoutWorkItem?.cancel()
            let pairingItem = DispatchWorkItem {
                let connected = DualModeRemoteCoordinator.shared.nativeClient.isConnected ||
                                HSBTVOSConnectionManager.shared().isConnected ||
                                DualModeRemoteCoordinator.shared.screenClient.isConnected
                if connected {
                    finish(true, nil)
                } else {
                    finish(false, "配对超时：未在规定时间内输入电视屏幕上的 PIN 码。")
                }
            }
            timeoutWorkItem = pairingItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 90.0, execute: pairingItem)
        }
        
        // 2. 监听大屏握手成功通知
        let token1 = NotificationCenter.default.addObserver(
            forName: .HSBTVOSConnectionState,
            object: nil,
            queue: .main
        ) { _ in
            if HSBTVOSConnectionManager.shared().isConnected {
                finish(true, nil)
            }
        }
        observerTokens.append(token1)
        
        // 3. 监听原生状态变迁通知
        let token2 = NotificationCenter.default.addObserver(
            forName: Notification.Name("HSBConnectionStateDidChangeNotification"),
            object: nil,
            queue: .main
        ) { note in
            if let state = note.userInfo?["state"] as? HSBConnectionState {
                switch state {
                case .ready:
                    finish(true, nil)
                case .pairing:
                    startPairingTimeout()
                case .failed(let err):
                    if !HSBTVOSConnectionManager.shared().isConnected {
                        finish(false, "连接失败: \(err)")
                    }
                default:
                    break
                }
            }
        }
        observerTokens.append(token2)
        
        // 4. 监听 PIN 码请求通知，确保在收到 PIN 提示时立即进入配对超时延展
        let token3 = NotificationCenter.default.addObserver(
            forName: Notification.Name("HSBAppleTVNativePINRequiredNotification"),
            object: nil,
            queue: .main
        ) { _ in
            startPairingTimeout()
        }
        observerTokens.append(token3)
        
        // 5. 超时保底处理（常规探测放宽至 15 秒，如遇待配对则放宽给用户输入 PIN 码时间）
        let initialTimeoutItem = DispatchWorkItem {
            if isPairingPhase || DualModeRemoteCoordinator.shared.nativeClient.isPairing {
                Log.companion.report("Bridge: Native pairing in progress, skipping initial timeout")
                return
            }
            
            let connected = DualModeRemoteCoordinator.shared.nativeClient.isConnected ||
                            HSBTVOSConnectionManager.shared().isConnected ||
                            DualModeRemoteCoordinator.shared.screenClient.isConnected
            if connected {
                finish(true, nil)
            } else {
                finish(false, "连接超时：未能连接至 \(device.name)。\n请确认电视已开机亮屏，并在同一 Wi-Fi 网络。")
            }
        }
        timeoutWorkItem = initialTimeoutItem
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout, execute: initialTimeoutItem)
        
        // 5. 触发原生通道连接与待机唤醒
        DualModeRemoteCoordinator.shared.setCurrentTarget(device: device)
        DualModeRemoteCoordinator.shared.currentMode = .nativeOnly
        let nativePort = device.port > 0 ? device.port : 49152
        DualModeRemoteCoordinator.shared.connectToNative(host: device.host, deviceName: device.name, port: nativePort)
        DualModeRemoteCoordinator.shared.wakeDevice(host: device.host, completion: nil)
        
        // 6. 仅在目标为电视时在后台尝试连接伴随大屏端服务 (56789)
        if !device.isMacDevice {
            let screenEndpoint = nw_endpoint_create_host(device.host, "\(HSBRemoteConstants.screenDefaultPort)")
            HSBTVOSConnectionManager.shared().connect(to: screenEndpoint, deviceName: device.name)
            DualModeRemoteCoordinator.shared.screenClient.connect(to: screenEndpoint, deviceName: device.name)
        }
    }
    
    @objc @MainActor public static func submitNativePIN(_ pin: String, completion: ((Bool) -> Void)? = nil) {
        DualModeRemoteCoordinator.shared.submitNativePIN(pin, completion: completion)
    }
    
    @objc @MainActor public static var isLaunchAnimationActive: Bool = false
    @objc @MainActor private static weak var currentLaunchHostingVC: UIViewController?
    
    @objc @MainActor public static func dismissLaunchAnimationIfNeeded(completion: (() -> Void)? = nil) {
        guard isLaunchAnimationActive, let hosting = currentLaunchHostingVC else {
            isLaunchAnimationActive = false
            completion?()
            return
        }
        isLaunchAnimationActive = false
        currentLaunchHostingVC = nil
        hosting.dismiss(animated: false, completion: completion)
    }
    
    @objc @MainActor public static func reopenNativePINAlertIfNeeded() {
        DualModeRemoteCoordinator.shared.reopenNativePINAlertIfNeeded()
    }
    
    @objc(showLaunchEntranceAnimationOn:)
    @MainActor public static func showLaunchEntranceAnimation(on parent: UIViewController) {
        showLaunchEntranceAnimation(on: parent, completion: nil)
    }
    
    @objc(showLaunchEntranceAnimationOn:completion:)
    @MainActor public static func showLaunchEntranceAnimation(on parent: UIViewController, completion: (() -> Void)? = nil) {
        isLaunchAnimationActive = true
        weak var weakHosting: UIViewController?
        let animView = TanghuluLaunchAnimationView {
            isLaunchAnimationActive = false
            currentLaunchHostingVC = nil
            if let presented = weakHosting?.presentedViewController, presented is UIAlertController {
                NSLog("[LaunchAnim] Alert is currently active on launch view, skip dismissing to prevent closing alert")
                completion?()
                NotificationCenter.default.post(name: Notification.Name("HSBLaunchAnimationDidFinishNotification"), object: nil)
                return
            }
            weakHosting?.dismiss(animated: true) {
                completion?()
                NotificationCenter.default.post(name: Notification.Name("HSBLaunchAnimationDidFinishNotification"), object: nil)
            }
        }
        let hosting = UIHostingController(rootView: animView)
        weakHosting = hosting
        currentLaunchHostingVC = hosting
        hosting.view.backgroundColor = UIColor(red: 34.0 / 255.0, green: 34.0 / 255.0, blue: 34.0 / 255.0, alpha: 1.0)
        hosting.modalPresentationStyle = .overFullScreen
        hosting.modalTransitionStyle = .crossDissolve
        parent.present(hosting, animated: false, completion: nil)
    }
    
    @objc @MainActor public static func isUnifiedConnected() -> Bool {
        return DualModeRemoteCoordinator.shared.nativeClient.isConnected ||
               HSBTVOSConnectionManager.shared().isConnected ||
               DualModeRemoteCoordinator.shared.screenClient.isConnected
    }
    
    @objc @MainActor public static func disconnectUnified() {
        DualModeRemoteCoordinator.shared.disconnectAll()
    }
    
    @objc @MainActor public static func syncLegacyLLMTranslation(requestId: String, result: String) {
        DualModeRemoteCoordinator.shared.screenClient.send(
            command: .translationResult(requestId: requestId, result: result)
        )
    }
}

// MARK: - HSBQRCodeScannerDelegate
extension HSBModernRemoteHostingController: HSBQRCodeScannerDelegate {
    public func qrCodeScanner(_ scanner: HSBQRCodeScannerViewController, didScanPairingURL url: URL) {
        scanner.dismiss(animated: true) {
            HSBTVOSConnectionManager.shared().connect(toPairingURL: url)
        }
    }
    
    public func qrCodeScannerDidCancel(_ scanner: HSBQRCodeScannerViewController) {
        scanner.dismiss(animated: true, completion: nil)
    }
}
