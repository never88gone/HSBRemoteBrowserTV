//
//  HSBNativePINAlertPresenter.swift
//  HSBWatchCompanion
//
//  Created for Apple TV Native SRP-6a Pairing PIN Input Presentation.
//

import UIKit

/// 顶层独立 Window 呈现器：负责在任何视图层级下 100% 稳定弹出 Apple TV 原生 PIN 码输入框
@objc @MainActor
public final class HSBNativePINAlertPresenter: NSObject, UITextFieldDelegate {
    
    @objc public static let shared = HSBNativePINAlertPresenter()
    
    private var alertWindow: UIWindow?
    private weak var currentAlertController: UIAlertController?
    private var pendingCompletion: ((String) -> Void)?
    @objc public private(set) var isPresenting: Bool = false
    
    private override init() {
        super.init()
        setupNotificationListener()
    }
    
    // MARK: - Notification Listener
    
    private func setupNotificationListener() {
        NotificationCenter.default.addObserver(
            forName: Notification.Name("HSBAppleTVNativePINRequiredNotification"),
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let self = self else { return }
            guard let completion = note.userInfo?["completion"] as? (String) -> Void else {
                return
            }
            let deviceName = note.userInfo?["name"] as? String
            self.presentPINAlert(deviceName: deviceName, completion: completion)
        }
    }
    
    // MARK: - Presentation
    
    /// 在全局最顶层专属 UIWindow 上安全呈现 PIN 码输入弹窗
    @objc public func presentPINAlert(
        deviceName: String?,
        completion: @escaping (String) -> Void
    ) {
        // 如果当前已有正在呈现的 PIN 弹窗，先关闭旧的
        if isPresenting {
            dismissAlert(animated: false)
        }
        
        self.pendingCompletion = completion
        self.isPresenting = true
        
        // 1. 获取当前活动的前台 WindowScene
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
        let targetScene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        
        guard let windowScene = targetScene else {
            Log.companion.fail("[NativePIN] 未能找到活动的 UIWindowScene，无法弹出 PIN 码输入框")
            self.pendingCompletion?("")
            self.pendingCompletion = nil
            self.isPresenting = false
            return
        }
        
        // 2. 创建高优先级独立 UIWindow（Level = alert + 100），完全隔离主 Window 的呈现冲突
        let window = UIWindow(windowScene: windowScene)
        window.windowLevel = UIWindow.Level.alert + 100
        
        let rootVC = UIViewController()
        rootVC.view.backgroundColor = UIColor.clear
        window.rootViewController = rootVC
        self.alertWindow = window
        window.makeKeyAndVisible()
        
        // 3. 构建 PIN 码输入弹窗
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
        
        // 4. 在独立 rootVC 上呈现弹窗，并在完成时自动唤起数字键盘
        rootVC.present(alert, animated: true) {
            alert.textFields?.first?.becomeFirstResponder()
        }
    }
    
    // MARK: - Dismissal
    
    /// 安全关闭弹窗并销毁独立 UIWindow
    @objc public func dismissAlert(animated: Bool = true, completion: (() -> Void)? = nil) {
        let finishCleanup = { [weak self] in
            guard let self = self else { return }
            self.alertWindow?.isHidden = true
            self.alertWindow?.rootViewController = nil
            self.alertWindow = nil
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
        // 仅允许输入纯数字，并限制长度不超过 4 位
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
