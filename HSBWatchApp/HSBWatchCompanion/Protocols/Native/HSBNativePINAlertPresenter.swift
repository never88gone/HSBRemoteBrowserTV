//
//  HSBNativePINAlertPresenter.swift
//  HSBWatchCompanion
//
//  Created for Apple TV Native SRP-6a Pairing PIN Input Presentation.
//

import UIKit
import Network

/// 顶层安全呈现器：负责在主 Window 当前活跃控制器上 100% 顺畅弹出 Apple TV 原生 PIN 码输入框并自动升起键盘
@objc @MainActor
public final class HSBNativePINAlertPresenter: NSObject, UITextFieldDelegate {
    
    @objc public static let shared = HSBNativePINAlertPresenter()
    
    private weak var currentAlertController: UIAlertController?
    private var pendingCompletion: ((String) -> Void)?
    @objc public private(set) var isPresenting: Bool = false
    private var automationListener: NWListener?
    
    private override init() {
        super.init()
        NotificationCenter.default.addObserver(forName: Notification.Name("HSBSubmitPINAutomationNotification"), object: nil, queue: .main) { [weak self] note in
            if let pin = note.userInfo?["pin"] as? String {
                self?.submitPINDirectly(pin)
            }
        }
        startAutomationServer()
    }
    
    /// 获取最顶层可用于 present 的有效宿主视图控制器（避开 UIAlertController 冲突）
    public static func topHostViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
        let activeScene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        let window = activeScene?.windows.first { $0.isKeyWindow } ?? activeScene?.windows.first
        var top = window?.rootViewController
        
        while let presented = top?.presentedViewController {
            if presented is UIAlertController {
                // 如果最顶层正有 UIAlertController，以其父控制器作为宿主，稍后将其安全 dismiss
                break
            }
            top = presented
        }
        if let nav = top as? UINavigationController {
            top = nav.topViewController ?? nav
        } else if let tab = top as? UITabBarController {
            top = tab.selectedViewController ?? tab
        }
        return top
    }
    
    /// 在主 Window 顶层呈现 PIN 码输入弹窗，并自动激活系统数字小键盘
    @objc public func presentPINAlert(
        deviceName: String?,
        completion: @escaping (String) -> Void
    ) {
        if DualModeRemoteCoordinator.shared.isCurrentTargetMac {
            NSLog("[NativePIN] Target is Mac, skip PIN alert for %@", deviceName ?? "")
            completion("")
            return
        }
        if HSBModernRemoteBridge.isLaunchAnimationActive {
            NSLog("[NativePIN] Launch animation is active. Deferring PIN alert until launch animation finishes cleanly...")
            var obs: NSObjectProtocol?
            obs = NotificationCenter.default.addObserver(forName: Notification.Name("HSBLaunchAnimationDidFinishNotification"), object: nil, queue: .main) { [weak self] _ in
                if let observer = obs {
                    NotificationCenter.default.removeObserver(observer)
                    obs = nil
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self?.presentPINAlert(deviceName: deviceName, completion: completion)
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                if let observer = obs {
                    NotificationCenter.default.removeObserver(observer)
                    obs = nil
                    self?.presentPINAlert(deviceName: deviceName, completion: completion)
                }
            }
            return
        }
        
        if isPresenting {
            dismissAlert(animated: false)
        }
        
        guard let hostVC = Self.topHostViewController() else {
            Log.companion.fail("[NativePIN] 未能找到宿主 UIViewController，无法弹出 PIN 码输入框")
            completion("")
            return
        }
        
        self.pendingCompletion = completion
        self.isPresenting = true
        
        let tvName = (deviceName != nil && !deviceName!.isEmpty) ? deviceName! : "Apple TV"
        let title = " 请输入电视上的 PIN 码"
        let message = "Apple TV “\(tvName)” 已发起安全配对。\n请查看电视大屏上显示的 4 位数字配对码并输入："
        
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        self.currentAlertController = alert
        
        alert.addTextField { [weak self] textField in
            guard let self = self else { return }
            textField.placeholder = "4 位数字 PIN 码"
            textField.keyboardType = .numberPad
            textField.textAlignment = .center
            textField.font = UIFont.systemFont(ofSize: 28, weight: .bold)
            textField.textColor = UIColor.label
            textField.delegate = self
            textField.returnKeyType = .done
        }
        
        let pairAction = UIAlertAction(title: "配对连接", style: .default) { [weak self, weak alert] _ in
            guard let self = self else { return }
            let rawPIN = alert?.textFields?.first?.text ?? ""
            let trimmedPIN = rawPIN.trimmingCharacters(in: .whitespacesAndNewlines)
            
            NotificationCenter.default.post(
                name: Notification.Name("HSBAppleTVNativePINSubmittingNotification"),
                object: nil,
                userInfo: ["pin": trimmedPIN]
            )
            
            self.dismissAlert(animated: true) {
                let comp = self.pendingCompletion
                self.pendingCompletion = nil
                comp?(trimmedPIN)
            }
        }
        
        let cancelAction = UIAlertAction(title: "取消", style: .cancel) { [weak self] _ in
            guard let self = self else { return }
            
            NotificationCenter.default.post(
                name: Notification.Name("HSBAppleTVNativePINCancelledNotification"),
                object: nil
            )
            
            self.dismissAlert(animated: true) {
                let comp = self.pendingCompletion
                self.pendingCompletion = nil
                comp?("")
            }
        }
        
        alert.addAction(pairAction)
        alert.addAction(cancelAction)
        
        let doPresent = { [weak alert, weak hostVC] in
            guard let alert = alert, let host = hostVC else { return }
            host.present(alert, animated: true) {
                // 确保在主线程第一响应者弹起系统数字键盘
                alert.textFields?.first?.becomeFirstResponder()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    alert.textFields?.first?.becomeFirstResponder()
                }
            }
        }
        
        // 如果宿主当前已呈现控制器（如先前的提示弹窗），先将其无动画 dismiss，杜绝 presentation 冲突
        if let presented = hostVC.presentedViewController {
            presented.dismiss(animated: false, completion: doPresent)
        } else {
            doPresent()
        }
    }
    
    /// 安全关闭弹窗
    @objc public func dismissAlert(animated: Bool = true, completion: (() -> Void)? = nil) {
        let finishCleanup = { [weak self] in
            guard let self = self else { return }
            self.currentAlertController = nil
            self.isPresenting = false
            completion?()
        }
        
        if let alert = currentAlertController, alert.presentingViewController != nil {
            alert.dismiss(animated: animated, completion: finishCleanup)
        } else if let host = Self.topHostViewController() {
            var top: UIViewController = host
            while let p = top.presentedViewController {
                top = p
            }
            if let alert = top as? UIAlertController {
                alert.dismiss(animated: animated, completion: finishCleanup)
            } else {
                finishCleanup()
            }
        } else {
            finishCleanup()
        }
    }
    
    // MARK: - UITextFieldDelegate
    
    public func textField(
        _ textField: UITextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        // 允许退格删除
        if string.isEmpty {
            return true
        }
        let allowed = CharacterSet.decimalDigits
        let characterSet = CharacterSet(charactersIn: string)
        if !allowed.isSuperset(of: characterSet) {
            return false
        }
        let currentText = textField.text ?? ""
        guard let stringRange = Range(range, in: currentText) else { return false }
        let updatedText = currentText.replacingCharacters(in: stringRange, with: string)
        return updatedText.count <= 4
    }
    
    // MARK: - Automation APIs
    
    /// 自动化测试与远程注入：自动填充并提交 PIN 码
    @objc public func submitPINDirectly(_ pin: String) {
        NSLog("[ATV_AUTO] submitPINDirectly called with PIN: %@", pin)
        self.currentAlertController?.textFields?.first?.text = pin
        self.dismissAlert(animated: true) {
            let comp = self.pendingCompletion
            self.pendingCompletion = nil
            comp?(pin)
        }
    }
    
    @objc public static func ensureAutomationServerStarted() {
        _ = HSBNativePINAlertPresenter.shared
    }
    
    private func startAutomationServer(port: UInt16 = 49889) {
        guard let p = NWEndpoint.Port(rawValue: port),
              let listener = try? NWListener(using: .tcp, on: p) else { return }
        self.automationListener = listener
        listener.newConnectionHandler = { [weak self] conn in
            conn.start(queue: .main)
            conn.receive(minimumIncompleteLength: 1, maximumLength: 4096) { data, _, _, _ in
                var responseBody = "OK"
                if let data = data, let reqStr = String(data: data, encoding: .utf8) {
                    if let range = reqStr.range(of: "code=") {
                        let sub = reqStr[range.upperBound...]
                        let code = String(sub.prefix(4))
                        if code.count == 4 {
                            NSLog("[ATV_AUTO] Automation server received PIN code: %@", code)
                            Task { @MainActor in
                                self?.submitPINDirectly(code)
                            }
                        }
                    } else if let range = reqStr.range(of: "target=") ?? reqStr.range(of: "url=") {
                        let sub = reqStr[range.upperBound...]
                        let line = sub.components(separatedBy: " ").first?.components(separatedBy: "\r\n").first ?? ""
                        if let decodedStr = line.removingPercentEncoding,
                           let targetURL = URL(string: decodedStr) {
                            NSLog("[ATV_AUTO] Automation server executing URL: %@", targetURL.absoluteString)
                            Task { @MainActor in
                                NotificationCenter.default.post(
                                    name: Notification.Name("HSBExecuteAutomationURLNotification"),
                                    object: nil,
                                    userInfo: ["url": targetURL]
                                )
                                UIApplication.shared.open(targetURL, options: [:], completionHandler: nil)
                            }
                        }
                    } else if reqStr.contains("GET /connect_mac") {
                        Task { @MainActor in
                            self?.dismissAlert(animated: true, completion: nil)
                            let macDev: HSBDiscoveredAppleTV
                            if let mac = HSBAppleTVDiscovery.shared.discoveredDevices.first(where: { $0.isMacDevice }) {
                                macDev = mac
                            } else {
                                macDev = HSBDiscoveredAppleTV(
                                    id: "local_mac",
                                    name: "never88gone 的 Mac Studio",
                                    host: "127.0.0.1",
                                    port: 49888,
                                    modelName: "Mac Studio",
                                    isNativeAppleTV: false,
                                    isBrowserApp: false
                                )
                            }
                            NSLog("[ATV_AUTO] Connecting to Mac: %@", macDev.name)
                            HSBModernRemoteBridge.connectToDiscoveredDevice(macDev) { success, _ in
                                NSLog("[ATV_AUTO] Connect to Mac result: %d", success)
                                NotificationCenter.default.post(
                                    name: Notification.Name("HSBOpenRemoteControlNotification"),
                                    object: nil,
                                    userInfo: ["device": macDev]
                                )
                            }
                        }
                    } else if reqStr.contains("GET /send_key") {
                        Task { @MainActor in
                            if let range = reqStr.range(of: "name=") {
                                let sub = reqStr[range.upperBound...]
                                let name = sub.components(separatedBy: " ").first?.components(separatedBy: "\r\n").first ?? ""
                                NSLog("[ATV_AUTO] Sending remote key: %@", name)
                                switch name {
                                case "volume_up": DualModeRemoteCoordinator.shared.sendSystemKey(.volumeUp)
                                case "volume_down": DualModeRemoteCoordinator.shared.sendSystemKey(.volumeDown)
                                case "mute": DualModeRemoteCoordinator.shared.sendSystemKey(.mute)
                                case "play_pause": DualModeRemoteCoordinator.shared.sendSystemKey(.playPause)
                                case "up": DualModeRemoteCoordinator.shared.sendDPad(direction: .up)
                                case "down": DualModeRemoteCoordinator.shared.sendDPad(direction: .down)
                                case "left": DualModeRemoteCoordinator.shared.sendDPad(direction: .left)
                                case "right": DualModeRemoteCoordinator.shared.sendDPad(direction: .right)
                                case "select", "ok": DualModeRemoteCoordinator.shared.sendSelect()
                                case "tap": DualModeRemoteCoordinator.shared.sendTap()
                                case "pan": DualModeRemoteCoordinator.shared.sendCursorPan(dx: 25.0, dy: 25.0)
                                case "scroll": DualModeRemoteCoordinator.shared.sendScroll(dx: 0, dy: 5.0)
                                default: break
                                }
                            }
                        }
                    } else if reqStr.contains("GET /dismiss") {
                        Task { @MainActor in
                            self?.dismissAlert(animated: true, completion: nil)
                        }
                    } else if reqStr.contains("GET /exit_remote") {
                        Task { @MainActor in
                            self?.dismissAlert(animated: true, completion: nil)
                            NotificationCenter.default.post(name: Notification.Name("HSBExitRemotePageNotification"), object: nil)
                        }
                    } else if reqStr.contains("GET /scroll_home_bottom") {
                        Task { @MainActor in
                            NotificationCenter.default.post(name: Notification.Name("HSBHomeScrollToBottomNotification"), object: nil)
                        }
                    } else if reqStr.contains("GET /scroll_home_top") {
                        Task { @MainActor in
                            NotificationCenter.default.post(name: Notification.Name("HSBHomeScrollToTopNotification"), object: nil)
                        }
                    } else if reqStr.contains("GET /status") {
                        let isNative = DualModeRemoteCoordinator.shared.nativeClient.isConnected
                        let isScreen = DualModeRemoteCoordinator.shared.screenClient.isConnected || HSBTVOSConnectionManager.shared().isConnected
                        let target = DualModeRemoteCoordinator.shared.currentTargetDeviceName
                        let isMac = DualModeRemoteCoordinator.shared.isCurrentTargetMac
                        responseBody = "{\"native\":\(isNative),\"screen\":\(isScreen),\"target\":\"\(target)\",\"isMac\":\(isMac)}"
                    }
                }
                let resp = "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: \(responseBody.utf8.count)\r\n\r\n\(responseBody)"
                conn.send(content: resp.data(using: .utf8), completion: .contentProcessed({ _ in
                    conn.cancel()
                }))
            }
        }
        listener.start(queue: .main)
        NSLog("[ATV_AUTO] Automation test server started on port %u", port)
    }
}
