//
//  ModernHomeView.swift
//  HSBWatchCompanion
//
//  纯 SwiftUI 设备中枢首页：
//  - 折叠窄屏下采用紧凑单列滚动卡片（首屏直达设备连接、遥控台与 AI 中心）；
//  - iPhone Duo 展开态 (width >= 550pt) 自动启用左右对称双栏 Bento 布局，彻底消灭右侧黑空；
//  - 完整保留 `糖葫芦遥控器`、`Apple TV 硬件终端`、`进入双栏全能遥控台`、`AI 模型中心` 等全部交互与测试标识符。
//

import SwiftUI

public struct ModernHomeView: View {
    @ObservedObject public var viewModel: ModernHomeViewModel
    @ObservedObject public var router: HSBAppRouter
    
    @State private var showingTargetEditor: Bool = false
    @State private var targetGoalDraft: String = "100"
    
    public init(viewModel: ModernHomeViewModel, router: HSBAppRouter = .shared) {
        self.viewModel = viewModel
        self.router = router
    }
    
    public var body: some View {
        ZStack {
            GeometryReader { geometry in
                let isWideDuo = geometry.size.width >= 550
                ScrollView(showsIndicators: false) {
                    if isWideDuo {
                        duoWideLayout(totalWidth: geometry.size.width)
                            .padding(.leading, DuoMetrics.outerPadding)
                            .padding(.trailing, DuoMetrics.trailingPadding)
                            .padding(.vertical, 16)
                    } else {
                        compactNarrowLayout
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                    }
                }
                .refreshable {
                    viewModel.startScanning()
                }
                .background(DuoPalette.canvasBg.ignoresSafeArea())
            }
            
            // AI 模型本地预热状态浮层
            if viewModel.isAIPrewarming {
                aiPrewarmingOverlay
            }
            
            // 首屏糖葫芦拟人入场动画
            if viewModel.showLaunchAnimation {
                TanghuluLaunchAnimationView {
                    viewModel.finishLaunchAnimation()
                }
                .transition(.opacity)
                .zIndex(99)
            }
        }
        .navigationTitle(hsbL("ZE Watch", "糖葫芦遥控器"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    router.isQRScannerPresented = true
                } label: {
                    Image(systemName: "qrcode.viewfinder")
                        .foregroundColor(DuoPalette.warmOrange)
                }
                .accessibilityIdentifier("home_scan_button")
                .accessibilityLabel("扫码连大屏")
                
                Button {
                    router.push(.remote)
                } label: {
                    Image(systemName: "appletvremote.gen4.fill")
                        .foregroundColor(DuoPalette.hawthornRed)
                }
                .accessibilityIdentifier("home_remote_button")
                .accessibilityLabel("进入遥控器")
                
                Button {
                    router.push(.settings)
                } label: {
                    Image(systemName: "gearshape.fill")
                        .foregroundColor(.white)
                }
                .accessibilityIdentifier("home_settings_button")
                .accessibilityLabel("设置")
            }
        }
        .onAppear {
            viewModel.onConnectSuccess = { _ in
                router.push(.remote)
            }
            viewModel.markLaunchAnimationActiveIfVisible()
            viewModel.onViewAppear()
        }
        .alert(viewModel.failureAlertTitle, isPresented: $viewModel.isFailureAlertPresented) {
            Button(hsbL("🔄 重试连接", "🔄 重试连接")) {
                if let dev = viewModel.failedDeviceForRetry {
                    viewModel.connect(to: dev)
                }
            }
            if viewModel.showsQRScannerButtonInFailureAlert {
                Button(hsbL("📷 扫码连接专属浏览器", "📷 扫码连接专属浏览器")) {
                    router.isQRScannerPresented = true
                }
            }
            Button(hsbL("好的", "好的"), role: .cancel) {}
        } message: {
            Text(viewModel.failureAlertMessage)
        }
        .alert("设定每日交互目标", isPresented: $showingTargetEditor) {
            TextField("例如：100", text: $targetGoalDraft)
                .keyboardType(.numberPad)
            Button("保存目标") {
                if let val = Int(targetGoalDraft), val > 0 {
                    viewModel.setTargetGoal(val)
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("记录每天手表手势与伴侣交互的活跃度目标。")
        }
    }
    
    // MARK: - iPhone Duo 展开态对称双栏排版 (彻底消灭左侧黑空)
    private func duoWideLayout(totalWidth: CGFloat) -> some View {
        let colWidth = DuoMetrics.columnWidth(for: totalWidth)
        return HStack(alignment: .top, spacing: DuoMetrics.columnGap) {
            // 左栏：前台提示 + 核心开关状态卡 + 快捷中枢面板 + 大屏协同应用矩阵 + 表端体感联动监控 (彻底消除左侧空白)
            VStack(alignment: .leading, spacing: 14) {
                foregroundHintBanner
                statusCardsStack
                duoActionHubCard
                duoEcosystemLaunchGridCard
                duoSensorAndLinkageCard
            }
            .frame(width: colWidth)
            
            // 右栏：大屏电视与硬件终端列表 + mDNS 自动雷达发现 Footer
            VStack(alignment: .leading, spacing: 14) {
                discoveredDevicesCard(minHeight: 356)
                mdnsDiscoveryFooterCard
            }
            .frame(width: colWidth)
        }
    }
    
    private var duoEcosystemLaunchGridCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("大屏协同应用矩阵", systemImage: "sparkles.tv.fill")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(DuoPalette.textPrimary)
                Spacer()
                Text("一键直通")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(DuoPalette.accentRed)
            }
            
            HStack(spacing: 8) {
                ForEach(TanghuluAppCatalog.ecosystemApps) { app in
                    Button {
                        DualModeRemoteCoordinator.shared.launchApp(bundleID: app.bundleID, url: app.url)
                        NotificationCenter.default.post(name: Notification.Name("HSBSwitchRemoteTabNotification"), object: nil, userInfo: ["tab": app.targetMode])
                        router.push(.remote)
                    } label: {
                        VStack(spacing: 6) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(app.accentColor.opacity(0.18))
                                    .frame(width: 40, height: 40)
                                Image(systemName: app.iconName)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(app.accentColor)
                            }
                            Text(app.name.replacingOccurrences(of: "糖葫芦", with: ""))
                                .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                                .foregroundColor(DuoPalette.textPrimary)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .duoCard(cornerRadius: DuoMetrics.compactCardRadius, fill: DuoPalette.cardElevated)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .duoCard(cornerRadius: DuoMetrics.cardRadius)
    }
    
    private var duoSensorAndLinkageCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Apple Watch 智能手势与感知", systemImage: "applewatch.radiowaves.left.and.right")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(DuoPalette.textPrimary)
                Spacer()
                HStack(spacing: 4) {
                    Circle()
                        .fill(DuoPalette.readyGreen)
                        .frame(width: 6, height: 6)
                    Text("实时协同中")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundColor(DuoPalette.readyGreen)
                }
            }
            
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("手势延迟")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(DuoPalette.textMuted)
                    Text("< 5ms")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(DuoPalette.readyGreen)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .duoCard(cornerRadius: 12, fill: DuoPalette.cardElevated)
                
                VStack(alignment: .leading, spacing: 3) {
                    Text("信令协议")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(DuoPalette.textMuted)
                    Text("WCSession")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(DuoPalette.brandBlue)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .duoCard(cornerRadius: 12, fill: DuoPalette.cardElevated)
                
                VStack(alignment: .leading, spacing: 3) {
                    Text("大屏联动")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(DuoPalette.textMuted)
                    Text("全功能")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(DuoPalette.warmOrange)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .duoCard(cornerRadius: 12, fill: DuoPalette.cardElevated)
            }
            
            Text("支持通过手表数码表冠平滑换台、抬腕双击确认、轻微晃动刷新大屏。")
                .font(.system(size: 11))
                .foregroundColor(DuoPalette.textSecondary)
                .lineLimit(2)
        }
        .padding(14)
        .duoCard(cornerRadius: DuoMetrics.cardRadius)
    }
    
    // MARK: - 折叠屏窄屏紧凑单列排版
    private var compactNarrowLayout: some View {
        VStack(alignment: .leading, spacing: 14) {
            foregroundHintBanner
            duoActionHubCard
            discoveredDevicesCard(minHeight: 200)
            statusCardsStack
            mdnsDiscoveryFooterCard
        }
    }
    
    private var foregroundHintBanner: some View {
        Text(hsbL("Keep this app open while using your Watch.", "在使用手表遥控时保持此应用在前台运行"))
            .font(.system(size: 13.5, weight: .medium))
            .foregroundColor(DuoPalette.textSecondary)
            .padding(.horizontal, 4)
    }
    
    private var statusCardsStack: some View {
        VStack(spacing: 10) {
            // Card 1: Watch Engine
            statusToggleCard(
                title: hsbL(" WATCH SYNC ENGINE", " 穿戴设备运动同步引擎"),
                value: viewModel.watchStatusText,
                valueColor: DuoPalette.textPrimary,
                isOn: $viewModel.watchSyncEnabled
            )
            
            // Card 2: Apple TV Hardware Link
            statusToggleCard(
                title: hsbL(" APPLE TV HARDWARE LINK", " Apple TV 硬件设备直连"),
                value: viewModel.tvStatusText,
                valueColor: viewModel.tvStatusColor,
                isOn: $viewModel.tvScanEnabled
            ) {
                if HSBModernRemoteBridge.isUnifiedConnected() {
                    router.push(.remote)
                } else {
                    router.activeGuideType = .system
                }
            }
            
            // Card 3: Gesture & Activity Stats
            Button {
                targetGoalDraft = "\(viewModel.dailyTargetCount)"
                showingTargetEditor = true
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(hsbL("LATEST DETECTED ACTION", "最终判定体感动作"))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(DuoPalette.textMuted)
                        Spacer()
                        Text("今日步数 \(viewModel.dailySteps) · 互动 \(viewModel.dailyActionCount)/\(viewModel.dailyTargetCount)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(DuoPalette.hawthornRed)
                    }
                    
                    Text(viewModel.actionLogText)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(DuoPalette.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(14)
                .duoCard(cornerRadius: DuoMetrics.innerCardRadius)
            }
            .buttonStyle(.plain)
        }
    }
    
    private func statusToggleCard(
        title: String,
        value: String,
        valueColor: Color,
        isOn: Binding<Bool>,
        onTapCard: (() -> Void)? = nil
    ) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(DuoPalette.textMuted)
                Text(value)
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundColor(valueColor)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture {
                onTapCard?()
            }
            
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(DuoPalette.hawthornRed)
        }
        .padding(14)
        .duoCard(cornerRadius: DuoMetrics.innerCardRadius)
    }
    
    // MARK: - 全能大屏快捷控制台
    private var duoActionHubCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(hsbL("QUICK CONTROL CENTER", "全能大屏快捷控制台"))
                .font(.system(size: 11.5, weight: .bold))
                .foregroundColor(DuoPalette.textMuted)
            
            Button {
                router.push(.remote)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "appletvremote.gen4.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(DuoPalette.accentRed)
                    Text("进入双栏全能遥控台")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(DuoPalette.textSecondary)
                }
                .padding(.horizontal, 16)
                .frame(height: 54)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(DuoPalette.accentRed.opacity(0.20))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(DuoPalette.accentRed.opacity(0.45), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("进入双栏全能遥控台")
            
            HStack(spacing: 10) {
                quickTileButton(
                    icon: "qrcode.viewfinder",
                    title: "扫码连大屏",
                    color: DuoPalette.brandBlue
                ) {
                    router.isQRScannerPresented = true
                }
                
                quickTileButton(
                    icon: "cpu.fill",
                    title: "AI 模型中心",
                    color: DuoPalette.warmOrange
                ) {
                    router.push(.aiModelCenter)
                }
                
                quickTileButton(
                    icon: "gearshape.fill",
                    title: "系统设置",
                    color: DuoPalette.silverInactive
                ) {
                    router.push(.settings)
                }
            }
        }
        .padding(16)
        .duoCard(cornerRadius: DuoMetrics.cardRadius)
    }
    
    private func quickTileButton(
        icon: String,
        title: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 76)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(DuoPalette.cardElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(DuoPalette.stroke, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
    
    // MARK: - Apple TV 硬件终端与发现列表卡片
    private func discoveredDevicesCard(minHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Text("Apple TV 硬件终端")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(DuoPalette.textPrimary)
                
                if viewModel.isScanning {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(DuoPalette.hawthornRed)
                }
                
                Spacer()
                
                Text("\(viewModel.discoveredDevices.count) 台可用")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(DuoPalette.textSecondary)
            }
            
            if viewModel.discoveredDevices.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "appletv.fill")
                        .font(.system(size: 32))
                        .foregroundColor(DuoPalette.textMuted)
                    Text("正在搜索周边 Apple TV、Mac 与糖葫芦大屏设备...")
                        .font(.system(size: 13.5, weight: .medium))
                        .foregroundColor(DuoPalette.textSecondary)
                        .multilineTextAlignment(.center)
                    Text("请确认所有设备接入同一 Wi-Fi；也可直接点击左下「进入双栏全能遥控台」体验界面或点击右上角扫码配对。")
                        .font(.system(size: 12))
                        .foregroundColor(DuoPalette.textMuted)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 34)
            } else {
                VStack(spacing: 8) {
                    ForEach(viewModel.discoveredDevices, id: \.id) { device in
                        deviceRow(device)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .topLeading)
        .duoCard(cornerRadius: DuoMetrics.cardRadius)
    }
    
    private func deviceRow(_ device: HSBDiscoveredAppleTV) -> some View {
        let isConnecting = viewModel.connectingDeviceHost == device.host
        return Button {
            viewModel.connect(to: device)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(device.isMacDevice ? DuoPalette.brandBlue.opacity(0.16) : DuoPalette.hawthornRed.opacity(0.16))
                        .frame(width: 40, height: 40)
                    Image(systemName: device.deviceCategoryIconName)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(device.isMacDevice ? DuoPalette.brandBlue : DuoPalette.hawthornRed)
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(device.name)
                        .font(.system(size: 15.5, weight: .bold))
                        .foregroundColor(DuoPalette.textPrimary)
                        .lineLimit(1)
                    Text(device.displaySubtitle)
                        .font(.system(size: 12))
                        .foregroundColor(DuoPalette.textSecondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                if isConnecting {
                    ProgressView()
                        .scaleEffect(0.85)
                        .tint(.white)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12.5, weight: .bold))
                        .foregroundColor(DuoPalette.textMuted)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(DuoPalette.cardElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isConnecting ? DuoPalette.hawthornRed.opacity(0.55) : DuoPalette.stroke, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("home_device_row_\(device.id)")
        .accessibilityLabel("\(device.name) \(device.displaySubtitle)")
    }
    
    // MARK: - mDNS 零配置雷达 Footer
    private var mdnsDiscoveryFooterCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(DuoPalette.readyGreen)
            
            VStack(alignment: .leading, spacing: 3) {
                Text("mDNS 零配置自动雷达发现")
                    .font(.system(size: 13.5, weight: .bold))
                    .foregroundColor(DuoPalette.textPrimary)
                Text("支持 Apple TV 原生伴侣协议、糖葫芦 TV/Browser 与 Mac 隔空播放接收器。")
                    .font(.system(size: 11.5))
                    .foregroundColor(DuoPalette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
            
            Button {
                viewModel.startScanning()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("重新扫描设备")
        }
        .padding(14)
        .duoCard(cornerRadius: DuoMetrics.innerCardRadius)
    }
    
    private var aiPrewarmingOverlay: some View {
        VStack {
            Spacer()
            HStack(spacing: 10) {
                ProgressView()
                    .tint(.white)
                Text("正在端侧硬件加速预热 AI 大模型引擎...")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(Capsule().fill(Color.black.opacity(0.86)))
            .overlay(Capsule().stroke(DuoPalette.strokeBright, lineWidth: 1))
            .padding(.bottom, 26)
        }
    }
}

#if DEBUG
#Preview("首页设备中枢 · 折叠窄屏") {
    DuoPreviewContainer("糖葫芦遥控器", expandedDuo: false) {
        ModernHomeView(viewModel: ModernHomeViewModel(isPreviewMock: true))
    }
}

#Preview("首页设备中枢 · iPhone Duo 双栏展开") {
    DuoPreviewContainer("糖葫芦遥控器", expandedDuo: true) {
        ModernHomeView(viewModel: ModernHomeViewModel(isPreviewMock: true))
    }
}
#endif
