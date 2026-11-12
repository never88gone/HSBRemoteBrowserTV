//
//  ModernHomeViewModel.swift
//  HSBWatchCompanion
//
//  纯 SwiftUI 首页中枢 ViewModel：
//  - 统一驱动局域网 Bonjour/mDNS 多通道设备发现与直连握手；
//  - 统一驱动 Apple Watch 会话状态监测、体感动作捕获、CoreMotion 今日步数与互动目标计数；
//  - 完整复刻失败连接指引（Android TV / Mac 隔空播放 / Apple TV PIN 与二维码）并支持 Canvas #Preview Mock 注入。
//

import Foundation
import SwiftUI
import CoreMotion
import Combine

@MainActor
public final class ModernHomeViewModel: ObservableObject {
    @Published public var discoveredDevices: [HSBDiscoveredAppleTV] = []
    @Published public var isScanning: Bool = false
    @Published public var connectingDeviceHost: String? = nil
    
    @Published public var watchSyncEnabled: Bool = true {
        didSet { updateWatchSessionState() }
    }
    @Published public var tvScanEnabled: Bool = true {
        didSet {
            if tvScanEnabled {
                startScanning()
            } else {
                stopScanning()
            }
        }
    }
    
    @Published public var watchStatusText: String = hsbL("🟡 Connecting...", "🟡 获取 Apple Watch 状态中...")
    @Published public var tvStatusText: String = hsbL("⚪️ Hardware Idle", "⚪️ 未连接 Apple TV 硬件")
    @Published public var tvStatusColor: Color = DuoPalette.textSecondary
    @Published public var actionLogText: String = hsbL("Waiting for gestures...", "等待进行体感动作...")
    
    @Published public var dailySteps: Int = 0
    @Published public var dailyActionCount: Int = 0
    @Published public var dailyTargetCount: Int = 100
    @Published public var isAIPrewarming: Bool = false
    
    // 失败指引 Alert 状态
    @Published public var failureAlertTitle: String = ""
    @Published public var failureAlertMessage: String = ""
    @Published public var failedDeviceForRetry: HSBDiscoveredAppleTV? = nil
    @Published public var isFailureAlertPresented: Bool = false
    @Published public var showsQRScannerButtonInFailureAlert: Bool = false
    
    // 开屏动画状态
    @Published public var showLaunchAnimation: Bool = true
    
    private let pedometer = CMPedometer()
    private let isPreviewMock: Bool
    private var cancellables = Set<AnyCancellable>()
    
    public var onConnectSuccess: ((HSBDiscoveredAppleTV) -> Void)?
    
    public init(isPreviewMock: Bool = false) {
        self.isPreviewMock = isPreviewMock
        if isPreviewMock {
            showLaunchAnimation = false
            loadMockState()
        } else {
            loadPersistedActivityStats()
            setupNotifications()
        }
    }
    
    public func onViewAppear() {
        guard !isPreviewMock else { return }
        UIApplication.shared.isIdleTimerDisabled = true
        HSBWatchSessionManager.shared().startSession()
        updateWatchSessionState()
        startPedometerIfNeeded()
        if tvScanEnabled {
            startScanning()
        }
    }
    
    public func finishLaunchAnimation() {
        guard showLaunchAnimation else { return }
        withAnimation(.easeOut(duration: 0.3)) {
            showLaunchAnimation = false
        }
        HSBModernRemoteBridge.isLaunchAnimationActive = false
        NotificationCenter.default.post(name: Notification.Name("HSBLaunchAnimationDidFinishNotification"), object: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            HSBModernRemoteBridge.reopenNativePINAlertIfNeeded()
        }
    }
    
    public func markLaunchAnimationActiveIfVisible() {
        guard !isPreviewMock, showLaunchAnimation else { return }
        HSBModernRemoteBridge.isLaunchAnimationActive = true
    }
    
    // MARK: - Device Discovery & Connection
    public func startScanning() {
        guard !isPreviewMock else { return }
        isScanning = true
        HSBAppleTVDiscovery.shared.startScanning(observerId: "homeViewModel") { [weak self] devices in
            DispatchQueue.main.async {
                self?.discoveredDevices = devices
            }
        }
    }
    
    public func stopScanning() {
        guard !isPreviewMock else { return }
        isScanning = false
        HSBAppleTVDiscovery.shared.stopScanning()
    }
    
    public func connect(to device: HSBDiscoveredAppleTV) {
        if isPreviewMock {
            connectingDeviceHost = device.host
            return
        }
        if HSBModernRemoteBridge.isLaunchAnimationActive {
            finishLaunchAnimation()
        }
        if HSBModernRemoteBridge.isUnifiedConnected() {
            onConnectSuccess?(device)
            return
        }
        if connectingDeviceHost == device.host {
            return
        }
        
        connectingDeviceHost = device.host
        if device.isAndroidTV {
            tvStatusText = hsbL("🟡 Connecting to Android TV \(device.name)...", "🟡 正在连接 Android TV \(device.name)...")
        } else if device.isMacDevice {
            tvStatusText = hsbL("🟡 Connecting to Mac \(device.name)...", "🟡 正在连接 Mac \(device.name)...")
        } else {
            tvStatusText = hsbL("🟡 Connecting to Apple TV \(device.name)...", "🟡 正在连接 Apple TV \(device.name)...")
        }
        tvStatusColor = DuoPalette.brightYellow
        
        HSBModernRemoteBridge.connectToDiscoveredDevice(device, timeout: 15.0) { [weak self] success, errorMsg in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.connectingDeviceHost = nil
                if success {
                    if device.isMacDevice {
                        let isRouted = MacMediaCommandDispatcher.isConnectedToTarget(deviceName: device.name)
                        if isRouted {
                            self.tvStatusText = hsbL("🟢 AirPlay connected to \(device.name)", "🟢 已隔空投送至 \(device.name)")
                            self.tvStatusColor = DuoPalette.readyGreen
                        } else {
                            self.tvStatusText = hsbL("🟠 AirPlay ready · Connect in remote panel", "🟠 隔空播放接收器就绪 · 请在控台选择投送")
                            self.tvStatusColor = DuoPalette.warmOrange
                        }
                    } else {
                        self.tvStatusText = hsbL("🟢 Connected to \(device.name)", "🟢 已连接至 \(device.name)")
                        self.tvStatusColor = DuoPalette.readyGreen
                    }
                    self.onConnectSuccess?(device)
                } else {
                    if device.isMacDevice && (errorMsg?.contains("已就绪") == true) {
                        // 目标 Mac 7000 端口已就绪，但尚未投送音频：正常进入控制台，状态明确显示橙色就绪而非绿色已连接
                        self.tvStatusText = hsbL("🟠 AirPlay ready · Connect in remote panel", "🟠 隔空播放接收器就绪 · 请在控台选择投送")
                        self.tvStatusColor = DuoPalette.warmOrange
                        self.onConnectSuccess?(device)
                    } else {
                        self.tvStatusText = hsbL("🔴 Failed to connect to \(device.name)", "🔴 连接 \(device.name) 失败")
                        self.tvStatusColor = DuoPalette.accentRed
                        self.presentConnectionFailureGuide(for: device)
                    }
                }
            }
        }
    }
    
    private func presentConnectionFailureGuide(for device: HSBDiscoveredAppleTV) {
        failedDeviceForRetry = device
        if device.isAndroidTV {
            failureAlertTitle = hsbL("Android TV 连接指引", "Android TV 连接指引")
            failureAlertMessage = "未能与 Android TV “\(device.name)” 建立大屏遥控连接。\n\n• 确保应用就绪：\n请确保电视上已打开【糖葫芦TV】；\n\n• 检查网络环境：\n请确保手机与该 Android TV 处于同一局域网 Wi-Fi 网络下。"
            showsQRScannerButtonInFailureAlert = false
        } else if device.isMacDevice {
            failureAlertTitle = hsbL("Mac 隔空播放连接指引", "Mac 隔空播放连接指引")
            failureAlertMessage = "未能与 “\(device.name)” 建立原生隔空播放媒体控制连接。\n\n• 开启免装软件原生控制：\n请在目标 Mac 打开【系统设置】->【通用】->【隔空播放与接力】，确保已开启【隔空播放接收器】；\n\n• 检查网络环境：\n请确保手机与该 Mac 处于同一 Wi-Fi 局域网下。"
            showsQRScannerButtonInFailureAlert = false
        } else {
            failureAlertTitle = hsbL("电视连接指引", "电视连接指引")
            failureAlertMessage = "未能与 “\(device.name)” 建立连接。\n\n• 如需遥控 Apple TV 全局系统：\n请点击【🔄 重试连接】，电视屏幕将弹出 4 位配对码，在手机输入即可完成永久绑定；\n\n• 如需控制电视上的【糖葫芦浏览器】网页：\n请在电视打开应用后，点击下方【📷 扫码连接专属浏览器】。"
            showsQRScannerButtonInFailureAlert = true
        }
        isFailureAlertPresented = true
    }
    
    // MARK: - Watch & Activity Stats
    public func updateWatchSessionState() {
        guard !isPreviewMock else { return }
        if !watchSyncEnabled {
            watchStatusText = hsbL("🔴 Gesture Sync Disabled (Power Save)", "🔴 手势同步已关闭 (省电模式)")
            return
        }
        HSBWatchSessionManager.shared().updateWatchSessionState { [weak self] statusText in
            DispatchQueue.main.async {
                self?.watchStatusText = statusText
            }
        }
    }
    
    public func setTargetGoal(_ goal: Int) {
        guard goal > 0 else { return }
        dailyTargetCount = goal
        if !isPreviewMock {
            UserDefaults.standard.set(goal, forKey: "ActivityTargetCount")
        }
    }
    
    private var todayStorageKey: String {
        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd"
        return "ActivityCount_\(df.string(from: Date()))"
    }
    
    private func loadPersistedActivityStats() {
        let defaults = UserDefaults.standard
        dailyActionCount = defaults.integer(forKey: todayStorageKey)
        let savedTarget = defaults.integer(forKey: "ActivityTargetCount")
        dailyTargetCount = savedTarget > 0 ? savedTarget : 100
    }
    
    private func incrementActionScore() {
        dailyActionCount += 1
        if !isPreviewMock {
            UserDefaults.standard.set(dailyActionCount, forKey: todayStorageKey)
        }
    }
    
    private func startPedometerIfNeeded() {
        guard CMPedometer.isStepCountingAvailable() else { return }
        let midnight = Calendar.current.startOfDay(for: Date())
        pedometer.startUpdates(from: midnight) { [weak self] data, error in
            guard error == nil, let steps = data?.numberOfSteps.intValue else { return }
            DispatchQueue.main.async {
                self?.dailySteps = steps
            }
        }
    }
    
    // MARK: - Notifications
    private func setupNotifications() {
        let nc = NotificationCenter.default
        
        nc.publisher(for: Notification.Name("HSBLocalLLM_PrewarmingStartedNotification"))
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.isAIPrewarming = true }
            .store(in: &cancellables)
        
        nc.publisher(for: Notification.Name("HSBLocalLLM_PrewarmingFinishedNotification"))
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.isAIPrewarming = false }
            .store(in: &cancellables)
        
        nc.publisher(for: .HSBWatchSessionReachabilityDidChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateWatchSessionState() }
            .store(in: &cancellables)
        
        nc.publisher(for: .HSBWatchActionReceived)
            .receive(on: RunLoop.main)
            .sink { [weak self] note in
                guard let self = self else { return }
                if let action = note.userInfo?["action"] as? String, !action.isEmpty {
                    self.incrementActionScore()
                    self.actionLogText = hsbL("Action: \(action)", "捕获体感: \(action)")
                }
            }
            .store(in: &cancellables)
        
        nc.publisher(for: Notification.Name("HSBLaunchAnimationDidFinishNotification"))
            .receive(on: RunLoop.main)
            .sink { _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    HSBModernRemoteBridge.reopenNativePINAlertIfNeeded()
                }
            }
            .store(in: &cancellables)
        
        nc.publisher(for: Notification.Name("HSBConnectDeviceAtIndexNotification"))
            .receive(on: RunLoop.main)
            .sink { [weak self] note in
                guard let self = self else { return }
                let idx = (note.userInfo?["index"] as? Int) ?? 0
                if idx >= 0 && idx < self.discoveredDevices.count {
                    self.connect(to: self.discoveredDevices[idx])
                }
            }
            .store(in: &cancellables)
    }
    
    private func loadMockState() {
        watchStatusText = "🟢 手表端已连接 (实时传输中)"
        tvStatusText = "🟡 扫描周边局域网硬件与大屏设备..."
        tvStatusColor = DuoPalette.brightYellow
        actionLogText = "捕获体感: 手腕前挥 · 下滑"
        dailySteps = 4280
        dailyActionCount = 36
        dailyTargetCount = 100
        discoveredDevices = [
            HSBDiscoveredAppleTV(
                id: "mock-hsbtv7",
                name: "HSBTV7",
                host: "192.168.1.88",
                port: 7000,
                modelName: "AppleTV14,1",
                isNativeAppleTV: true,
                isBrowserApp: true,
                rawEndpoint: nil
            ),
            HSBDiscoveredAppleTV(
                id: "mock-mac",
                name: "never88gone的 Mac Studio",
                host: "192.168.1.99",
                port: 7000,
                modelName: "Mac14,14",
                isNativeAppleTV: false,
                isBrowserApp: false,
                rawEndpoint: nil
            ),
            HSBDiscoveredAppleTV(
                id: "mock-android-tv",
                name: "客厅 SONY Android TV",
                host: "192.168.1.105",
                port: 56789,
                modelName: "AndroidTV",
                isNativeAppleTV: false,
                isBrowserApp: true,
                rawEndpoint: nil
            )
        ]
    }
}
