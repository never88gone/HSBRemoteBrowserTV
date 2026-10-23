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
    
    private override init() {
        super.init()
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
    
    // MARK: - Programmatic Submission
    
    /// 编程式填充并提交 PIN 码
    @objc public func submitPINDirectly(_ pin: String) {
        self.currentAlertController?.textFields?.first?.text = pin
        self.dismissAlert(animated: true) {
            let comp = self.pendingCompletion
            self.pendingCompletion = nil
            comp?(pin)
        }
    }
}
