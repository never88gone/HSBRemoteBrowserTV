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
        if HSBModernRemoteBridge.isLaunchAnimationActive {
            NSLog("[NativePIN] Launch animation is active. Dismissing launch animation first to present alert cleanly on main view...")
            HSBModernRemoteBridge.dismissLaunchAnimationIfNeeded {
                self.presentPINAlert(deviceName: deviceName, completion: completion)
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
    
    private func startAutomationServer(port: UInt16 = 49889) {
        guard let p = NWEndpoint.Port(rawValue: port),
              let listener = try? NWListener(using: .tcp, on: p) else { return }
        self.automationListener = listener
        listener.newConnectionHandler = { [weak self] conn in
            conn.start(queue: .main)
            conn.receive(minimumIncompleteLength: 1, maximumLength: 1024) { data, _, _, _ in
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
                    }
                }
                let resp = "HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nOK"
                conn.send(content: resp.data(using: .utf8), completion: .contentProcessed({ _ in
                    conn.cancel()
                }))
            }
        }
        listener.start(queue: .main)
        NSLog("[ATV_AUTO] Automation PIN server started on port %u", port)
    }
}
