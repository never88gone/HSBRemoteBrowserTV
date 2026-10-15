//
//  HSBNativePINAlertPresenter.swift
//  HSBWatchCompanion
//
//  Created for Apple TV Native SRP-6a Pairing PIN Input Presentation.
//

import UIKit

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
    
    /// 获取当前活跃的最顶层 UIViewController
    public static func topVisibleViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
        let activeScene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        let window = activeScene?.windows.first { $0.isKeyWindow } ?? activeScene?.windows.first
        var top = window?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        if let nav = top as? UINavigationController {
            top = nav.topViewController ?? nav
        }
        return top
    }
    
    /// 在主 Window 顶层呈现 PIN 码输入弹窗，并自动激活系统数字小键盘
    @objc public func presentPINAlert(
        deviceName: String?,
        completion: @escaping (String) -> Void
    ) {
        if isPresenting {
            dismissAlert(animated: false)
        }
        
        guard let topVC = Self.topVisibleViewController() else {
            Log.companion.fail("[NativePIN] 未能找到顶层 UIViewController，无法弹出 PIN 码输入框")
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
            textField.font = UIFont.systemFont(ofSize: 26, weight: .bold)
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
        
        let presentBlock = {
            topVC.present(alert, animated: true) {
                alert.textFields?.first?.becomeFirstResponder()
            }
        }
        
        if let currentPresented = topVC.presentedViewController, currentPresented is UIAlertController {
            currentPresented.dismiss(animated: false, completion: presentBlock)
        } else {
            presentBlock()
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
}
