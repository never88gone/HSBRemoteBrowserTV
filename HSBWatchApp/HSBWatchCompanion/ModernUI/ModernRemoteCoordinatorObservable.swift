//
//  ModernRemoteCoordinatorObservable.swift
//  HSBWatchCompanion
//

import SwiftUI
import Combine

@MainActor
final class CoordinatorObservable: ObservableObject, DualModeRemoteCoordinatorDelegate, RemoteTextInputManagerDelegate, HSBBonjourDiscoveryDelegate {
    @Published var state: HSBConnectionState = .disconnected
    @Published var isHSBBrowserConnected: Bool = false
    @Published var isHSBBrowserReconnecting: Bool = false
    @Published var browserDeviceName: String = ""
    @Published var isNativeConnected: Bool = false
    @Published var isTargetMac: Bool = false
    @Published var targetDeviceName: String = "Mac"
    @Published var nearbyDiscoveredBrowserTV: String? = nil
    
    private let coordinator: DualModeRemoteCoordinator
    private let bonjourDiscovery = HSBBonjourDiscovery()
    
    init(coordinator: DualModeRemoteCoordinator) {
        self.coordinator = coordinator
        self.state = coordinator.currentState
        let legacyMgr = HSBTVOSConnectionManager.shared()
        self.isTargetMac = coordinator.isCurrentTargetMac
        self.targetDeviceName = coordinator.currentTargetDeviceName.isEmpty ? "Mac" : coordinator.currentTargetDeviceName
        
        if coordinator.isCurrentTargetMac {
            self.isHSBBrowserConnected = false
            self.isHSBBrowserReconnecting = false
            self.browserDeviceName = ""
            self.isNativeConnected = true
        } else {
            self.isHSBBrowserConnected = legacyMgr.isConnected || coordinator.screenClient.isConnected
            self.isHSBBrowserReconnecting = legacyMgr.isReconnecting
            self.browserDeviceName = legacyMgr.deviceName ?? ""
            self.isNativeConnected = coordinator.nativeClient.isConnected
        }
        coordinator.delegate = self
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTVOSConnectionNotification(_:)),
            name: .HSBTVOSConnectionState,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleConnectionStateNotification(_:)),
            name: Notification.Name("HSBConnectionStateDidChangeNotification"),
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRefreshScreenChannelNotification),
            name: Notification.Name("HSBRefreshScreenChannelNotification"),
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDisconnectScreenChannelNotification),
            name: Notification.Name("HSBDisconnectScreenChannelNotification"),
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleForgetScreenChannelNotification),
            name: Notification.Name("HSBForgetScreenChannelNotification"),
            object: nil
        )
        
        bonjourDiscovery.delegate = self
        bonjourDiscovery.startDiscovery()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        bonjourDiscovery.delegate = nil
        bonjourDiscovery.cancelDiscoverySync()
    }
    
    @objc private func handleConnectionStateNotification(_ note: Notification) {
        DispatchQueue.main.async {
            self.state = self.coordinator.currentState
            self.isTargetMac = self.coordinator.isCurrentTargetMac
            if self.coordinator.isCurrentTargetMac {
                self.isHSBBrowserConnected = false
                self.isHSBBrowserReconnecting = false
                self.browserDeviceName = ""
                self.isNativeConnected = true
            } else {
                let legacyMgr = HSBTVOSConnectionManager.shared()
                self.isHSBBrowserConnected = legacyMgr.isConnected || self.coordinator.screenClient.isConnected
                self.isHSBBrowserReconnecting = legacyMgr.isReconnecting
                self.browserDeviceName = legacyMgr.deviceName ?? ""
                self.isNativeConnected = self.coordinator.nativeClient.isConnected
            }
            if !self.coordinator.currentTargetDeviceName.isEmpty {
                self.targetDeviceName = self.coordinator.currentTargetDeviceName
            }
        }
    }
    
    @objc private func handleTVOSConnectionNotification(_ note: Notification) {
        DispatchQueue.main.async {
            guard !self.coordinator.isCurrentTargetMac else {
                self.isHSBBrowserConnected = false
                self.isHSBBrowserReconnecting = false
                return
            }
            let legacyMgr = HSBTVOSConnectionManager.shared()
            self.isHSBBrowserConnected = legacyMgr.isConnected || self.coordinator.screenClient.isConnected
            self.isHSBBrowserReconnecting = legacyMgr.isReconnecting
            self.browserDeviceName = legacyMgr.deviceName ?? ""
            self.isNativeConnected = self.coordinator.nativeClient.isConnected
        }
    }
    
    func coordinator(_ coordinator: DualModeRemoteCoordinator, didChangeState state: HSBConnectionState) {
        DispatchQueue.main.async {
            self.state = state
            self.isTargetMac = coordinator.isCurrentTargetMac
            if coordinator.isCurrentTargetMac {
                self.isHSBBrowserConnected = false
                self.isHSBBrowserReconnecting = false
                self.browserDeviceName = ""
                self.isNativeConnected = true
            } else {
                let legacyMgr = HSBTVOSConnectionManager.shared()
                self.isHSBBrowserConnected = legacyMgr.isConnected || coordinator.screenClient.isConnected
                self.isHSBBrowserReconnecting = legacyMgr.isReconnecting
                self.browserDeviceName = legacyMgr.deviceName ?? ""
                self.isNativeConnected = coordinator.nativeClient.isConnected
            }
            if !coordinator.currentTargetDeviceName.isEmpty {
                self.targetDeviceName = coordinator.currentTargetDeviceName
            }
        }
    }
    
    // MARK: - HSBBonjourDiscoveryDelegate (局域网大屏在线状态感知)
    
    nonisolated func bonjourDiscovery(_ discovery: HSBBonjourDiscovery, didFind device: HSBDiscoveredDevice) {
        Task { @MainActor in
            self.nearbyDiscoveredBrowserTV = device.name
            let legacyMgr = HSBTVOSConnectionManager.shared()
            if !legacyMgr.isConnected && !legacyMgr.isReconnecting {
                let records = HSBTVOSConnectionManager.pairedTVRecords()
                if !records.isEmpty {
                    if case .service(let name, let type, let domain, _) = device.endpoint {
                        let cEndpoint = nw_endpoint_create_bonjour_service(name, type, domain)
                        legacyMgr.connect(to: cEndpoint, deviceName: device.name)
                    }
                }
            }
        }
    }
    
    nonisolated func bonjourDiscovery(_ discovery: HSBBonjourDiscovery, didLose device: HSBDiscoveredDevice) {
        Task { @MainActor in
            if self.nearbyDiscoveredBrowserTV == device.name {
                self.nearbyDiscoveredBrowserTV = nil
            }
        }
    }
    
    // MARK: - Screen Channel Controls (大屏状态控制核心操作)
    
    /// 刷新并测试当前大屏通道
    func refreshBrowserChannel() {
        let legacyMgr = HSBTVOSConnectionManager.shared()
        if legacyMgr.isConnected {
            legacyMgr.handleAppWillEnterForeground()
        } else {
            legacyMgr.triggerImmediateReconnect()
        }
    }
    
    /// 主动断开大屏应用连接
    func disconnectBrowserChannel() {
        HSBTVOSConnectionManager.shared().disconnect()
        coordinator.screenClient.disconnect()
        self.isHSBBrowserConnected = false
        self.isHSBBrowserReconnecting = false
        self.browserDeviceName = ""
    }
    
    /// 清除配对记录并准备重新扫码
    func forgetPairedBrowserAndRescan() {
        let legacyMgr = HSBTVOSConnectionManager.shared()
        legacyMgr.clearPairedTVRecords()
        coordinator.screenClient.disconnect()
        self.isHSBBrowserConnected = false
        self.isHSBBrowserReconnecting = false
        self.browserDeviceName = ""
        NotificationCenter.default.post(name: Notification.Name("HSBOpenQRCodeScannerNotification"), object: nil)
    }
    
    @objc private func handleRefreshScreenChannelNotification() {
        Task { @MainActor in
            self.refreshBrowserChannel()
        }
    }
    
    @objc private func handleDisconnectScreenChannelNotification() {
        Task { @MainActor in
            self.disconnectBrowserChannel()
        }
    }
    
    @objc private func handleForgetScreenChannelNotification() {
        Task { @MainActor in
            self.forgetPairedBrowserAndRescan()
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
