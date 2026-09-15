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
        self.title = "智能双模遥控器"
        self.view.backgroundColor = .systemBackground
    }
}

@objc public final class HSBModernRemoteBridge: NSObject {
    
    @objc public static func createModernRemoteViewController() -> UIViewController {
        return HSBModernRemoteHostingController()
    }
    
    @objc public static func connectWithHost(_ host: String, port: Int, deviceName: String) {
        let endpoint = nw_endpoint_create_host(host, "\(port)")
        DualModeRemoteCoordinator.shared.connectToScreen(endpoint: endpoint, deviceName: deviceName)
        DualModeRemoteCoordinator.shared.connectToNative(host: host, deviceName: deviceName)
    }
    
    @objc public static func syncLegacyLLMTranslation(requestId: String, result: String) {
        DualModeRemoteCoordinator.shared.screenClient.send(
            command: .translationResult(requestId: requestId, result: result)
        )
    }
}
