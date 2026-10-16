//
//  ModernRemoteCoordinatorObservable.swift
//  HSBWatchCompanion
//

import SwiftUI
import Combine

@MainActor
final class CoordinatorObservable: ObservableObject, DualModeRemoteCoordinatorDelegate, RemoteTextInputManagerDelegate {
    @Published var state: HSBConnectionState = .disconnected
    @Published var isHSBBrowserConnected: Bool = false
    @Published var browserDeviceName: String = ""
    @Published var isNativeConnected: Bool = false
    @Published var isTargetMac: Bool = false
    @Published var targetDeviceName: String = "Mac"
    private let coordinator: DualModeRemoteCoordinator
    
    init(coordinator: DualModeRemoteCoordinator) {
        self.coordinator = coordinator
        self.state = coordinator.currentState
        let legacyMgr = HSBTVOSConnectionManager.shared()
        self.isHSBBrowserConnected = legacyMgr.isConnected || coordinator.screenClient.isConnected
        self.browserDeviceName = legacyMgr.deviceName ?? ""
        self.isNativeConnected = coordinator.nativeClient.isConnected
        self.isTargetMac = coordinator.isCurrentTargetMac || CommandLine.arguments.contains("--test-mac-media")
        self.targetDeviceName = coordinator.currentTargetDeviceName.isEmpty ? "Mac" : coordinator.currentTargetDeviceName
        coordinator.delegate = self
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTVOSConnectionNotification(_:)),
            name: .HSBTVOSConnectionState,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func handleTVOSConnectionNotification(_ note: Notification) {
        DispatchQueue.main.async {
            let legacyMgr = HSBTVOSConnectionManager.shared()
            self.isHSBBrowserConnected = legacyMgr.isConnected || self.coordinator.screenClient.isConnected
            self.browserDeviceName = legacyMgr.deviceName ?? ""
        }
    }
    
    func coordinator(_ coordinator: DualModeRemoteCoordinator, didChangeState state: HSBConnectionState) {
        DispatchQueue.main.async {
            self.state = state
            let legacyMgr = HSBTVOSConnectionManager.shared()
            self.isHSBBrowserConnected = legacyMgr.isConnected || coordinator.screenClient.isConnected
            self.browserDeviceName = legacyMgr.deviceName ?? ""
            self.isNativeConnected = coordinator.nativeClient.isConnected
            self.isTargetMac = coordinator.isCurrentTargetMac || CommandLine.arguments.contains("--test-mac-media")
            if !coordinator.currentTargetDeviceName.isEmpty {
                self.targetDeviceName = coordinator.currentTargetDeviceName
            }
        }
    }
    
    func coordinator(_ coordinator: DualModeRemoteCoordinator, didReceiveScreenMessage message: [String: Any]) {
        // 接收消息处理
    }
    
    func textInputManager(_ manager: RemoteTextInputManager, didProduceRTIPayload data: Data) {
        // Native RTI 同步
    }
    
    func textInputManager(_ manager: RemoteTextInputManager, didFallbackToScript script: String) {
        coordinator.executeJavaScript(script, completion: nil)
    }
}

extension Color {
    /// 糖葫芦官方新版图标同源朱砂红 (#E02438)
    public static let tanghuluAccentRed = Color(red: 224.0 / 255.0, green: 36.0 / 255.0, blue: 56.0 / 255.0)
    /// 兼容旧命名，映射至新版朱砂红
    public static let tanghuluBrandBlue = tanghuluAccentRed
    
    /// 深炭黑沉浸背景渐变
    public static let auroraBackgroundGradient = LinearGradient(
        gradient: Gradient(colors: [
            Color(red: 37.0 / 255.0, green: 38.0 / 255.0, blue: 43.0 / 255.0),
            Color(red: 28.0 / 255.0, green: 29.0 / 255.0, blue: 33.0 / 255.0),
            Color(red: 20.0 / 255.0, green: 20.0 / 255.0, blue: 22.0 / 255.0)
        ]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
