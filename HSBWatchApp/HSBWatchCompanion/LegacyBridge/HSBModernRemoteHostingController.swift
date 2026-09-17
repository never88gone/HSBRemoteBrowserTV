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
        
        let keyboardItem = UIBarButtonItem(
            image: UIImage(systemName: "keyboard"),
            style: .plain,
            target: self,
            action: #selector(didTapKeyboardToggle)
        )
        self.navigationItem.rightBarButtonItem = keyboardItem
    }
    
    @objc private func didTapKeyboardToggle() {
        NotificationCenter.default.post(name: Notification.Name("HSBToggleRemoteKeyboardNotification"), object: nil)
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
    
    @objc public static func createModernRemoteViewController() -> UIViewController {
        return HSBModernRemoteHostingController()
    }
    
    @objc public static func connectWithHost(_ host: String, port: Int, deviceName: String) {
        if !HSBTVOSConnectionManager.shared().isConnected {
            let endpoint = nw_endpoint_create_host(host, "\(port)")
            HSBTVOSConnectionManager.shared().connect(to: endpoint, deviceName: deviceName)
        }
        if !DualModeRemoteCoordinator.shared.nativeClient.isConnected {
            DualModeRemoteCoordinator.shared.connectToNative(host: host, deviceName: deviceName)
        }
    }
    
    @objc public static func isUnifiedConnected() -> Bool {
        return HSBTVOSConnectionManager.shared().isConnected || DualModeRemoteCoordinator.shared.nativeClient.isConnected
    }
    
    @objc public static func disconnectUnified() {
        DualModeRemoteCoordinator.shared.disconnectAll()
    }
    
    @objc public static func syncLegacyLLMTranslation(requestId: String, result: String) {
        DualModeRemoteCoordinator.shared.screenClient.send(
            command: .translationResult(requestId: requestId, result: result)
        )
    }
}
