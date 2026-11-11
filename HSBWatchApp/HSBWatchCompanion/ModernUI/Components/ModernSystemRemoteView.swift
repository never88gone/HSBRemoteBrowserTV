//
//  ModernSystemRemoteView.swift
//  HSBWatchCompanion
//

import SwiftUI
import Combine

public struct ModernSystemRemoteView: View {
    public var dpadSize: CGFloat = 220.0
    public var isWideDuo: Bool = false
    public var onLaunchApp: ((TanghuluAppItem) -> Void)? = nil
    
    private let lightHaptic = UIImpactFeedbackGenerator(style: .light)
    @State private var isAwakeAndConnected: Bool = DualModeRemoteCoordinator.shared.nativeClient.isConnected && !DualModeRemoteCoordinator.shared.isSleeping
    private let timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
    
    public init(
        dpadSize: CGFloat = 220.0,
        isWideDuo: Bool = false,
        onLaunchApp: ((TanghuluAppItem) -> Void)? = nil
    ) {
        self.dpadSize = dpadSize
        self.isWideDuo = isWideDuo
        self.onLaunchApp = onLaunchApp
    }
    
    public var body: some View {
        Group {
            if isWideDuo {
                wideDuoBody
            } else {
                compactBody
            }
        }
        .onReceive(timer) { _ in
            let current = DualModeRemoteCoordinator.shared.nativeClient.isConnected && !DualModeRemoteCoordinator.shared.isSleeping
            if current != self.isAwakeAndConnected {
                self.isAwakeAndConnected = current
            }
        }
    }
    
    // MARK: - 共享真实操作回调
    
    private func triggerVolume(_ isUp: Bool) {
        lightHaptic.impactOccurred()
        DualModeRemoteCoordinator.shared.sendSystemKey(isUp ? .volumeUp : .volumeDown)
    }
    
    private func triggerPowerToggle() {
        DualModeRemoteCoordinator.shared.sendSystemKey(.power)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.isAwakeAndConnected = DualModeRemoteCoordinator.shared.nativeClient.isConnected && !DualModeRemoteCoordinator.shared.isSleeping
        }
    }
    
    private func triggerLaunchApp(_ item: TanghuluAppItem) {
        lightHaptic.impactOccurred()
        if let onLaunchApp = onLaunchApp {
            onLaunchApp(item)
        } else {
            DualModeRemoteCoordinator.shared.launchApp(bundleID: item.bundleID, url: item.url)
        }
    }
    
    // MARK: - 窄屏 / 折叠外屏单手布局 (完整保留原交互流)
    
    private var compactBody: some View {
        VStack(spacing: 0) {
            // 上半部微缓冲 (收紧顶部间隙，让轮盘自然承接Tab栏)
            Spacer(minLength: 4)
                .frame(maxHeight: 12)
            
            // 现代 220pt 质感 D-pad 轮盘 (居于单手握持最佳操控中轴，舒适人体工学)
            ModernDPadView(
                size: dpadSize,
                onDirection: { dir, action in
                    DualModeRemoteCoordinator.shared.sendDPad(direction: dir, action: action)
                },
                onSelect: { action in
                    DualModeRemoteCoordinator.shared.sendSelect(action: action)
                }
            )
            
            // 轮盘与控制岛之间的黄金呼吸间隙
            Spacer(minLength: 8)
                .frame(maxHeight: 24)
            
            // 下半屏：高质感一体化控制岛 (Control Island)
            VStack(spacing: 10) {
                mediaControlRow
                
                // 2. 系统核心功能行 (桌面, 返回, 静音, 待机)
                HStack(spacing: 12) {
                    systemIslandRoundButton(icon: "house.fill", label: "桌面") {
                        DualModeRemoteCoordinator.shared.sendSystemKey(.home)
                    }
                    systemIslandRoundButton(icon: "arrow.uturn.backward", label: "返回") {
                        DualModeRemoteCoordinator.shared.sendSystemKey(.menu)
                    }
                    systemIslandRoundButton(icon: "speaker.slash.fill", label: "静音") {
                        DualModeRemoteCoordinator.shared.sendSystemKey(.mute)
                    }
                    systemIslandRoundButton(
                        icon: "power",
                        label: isAwakeAndConnected ? "待机" : "开机",
                        tintColor: isAwakeAndConnected ? nil : Color.green
                    ) {
                        triggerPowerToggle()
                    }
                }
                
                // 3. 硬件音量调节行
                HStack(spacing: 10) {
                    compactVolumeButton(isUp: false)
                    compactVolumeButton(isUp: true)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(UIColor.secondarySystemBackground).opacity(0.7))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 16)
            
            // 底部自然贴合安全区
            Spacer(minLength: 6)
                .frame(maxHeight: 16)
        }
    }
    
    // MARK: - V2 展开双栏零空白：折痕避让 + L 型右下让位
    
    private var wideDuoBody: some View {
        GeometryReader { geo in
            let safeDpadSize = min(304, max(215, geo.size.height * 0.44))
            
            HStack(alignment: .top, spacing: DuoMetrics.columnGap) {
                // 左栏：糖葫芦生态+原生4应用速启 + 2×2 物理系统按键岛 + 搜索与配对卡片组
                VStack(spacing: 14) {
                    duoAppLaunchCard
                    duoSystemKeysGridCard
                    duoKeyboardShortcutCard
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                
                // 右栏：自适应大尺寸精工轮盘 (消除顶部留白) + 左收窄 L 型（媒体播控 3 连排 + 大屏硬件音量）
                VStack(alignment: .leading, spacing: 14) {
                    VStack(spacing: 10) {
                        HStack {
                            Label("Apple TV 主控同心轮盘", systemImage: "dot.circle.and.hand.point.up.left.fill")
                                .font(.system(size: 13.5, weight: .bold, design: .rounded))
                                .foregroundColor(DuoPalette.textPrimary)
                            Spacer()
                            HStack(spacing: 5) {
                                Circle()
                                    .fill(DuoPalette.readyGreen)
                                    .frame(width: 6, height: 6)
                                Text("四向轻滑 · 中央确认")
                                    .font(.system(size: 10.5, weight: .semibold))
                                    .foregroundColor(DuoPalette.textSecondary)
                            }
                        }
                        
                        // 顶部状态微标签 (充实轮盘顶部，彻底消除顶部大面积空白)
                        HStack(spacing: 8) {
                            Text("Apple TV 4K 原生触觉反馈")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundColor(DuoPalette.textSecondary)
                            Spacer()
                            Text("低延迟物理直连")
                                .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                                .foregroundColor(DuoPalette.accentRed)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(DuoPalette.accentRed.opacity(0.12), in: Capsule())
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(DuoPalette.cardElevated, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        
                        Spacer(minLength: 4)
                            .frame(maxHeight: 14)
                        
                        ModernDPadView(
                            size: safeDpadSize,
                            onDirection: { dir, action in
                                DualModeRemoteCoordinator.shared.sendDPad(direction: dir, action: action)
                            },
                            onSelect: { action in
                                DualModeRemoteCoordinator.shared.sendSelect(action: action)
                            }
                        )
                        
                        Spacer(minLength: 6)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .duoCard(cornerRadius: DuoMetrics.cardRadius)
                    
                    // L 型让位区：224pt 高度覆盖右侧全部 4 键区，内容全部向左侧收缩零重叠
                    HStack(spacing: 0) {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Label("媒体快捷与音量", systemImage: "hifispeaker.and.appletv.fill")
                                    .font(.system(size: 13.5, weight: .bold, design: .rounded))
                                    .foregroundColor(DuoPalette.textPrimary)
                                Spacer()
                                Text("CEC / AirPlay")
                                    .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                                    .foregroundColor(DuoPalette.textMuted)
                            }
                            
                            Spacer(minLength: 2)
                            
                            mediaControlRow
                            
                            Divider()
                                .background(DuoPalette.stroke)
                            
                            HStack(spacing: 10) {
                                duoVolumeTile(isUp: false)
                                duoVolumeTile(isUp: true)
                            }
                            
                            Spacer(minLength: 2)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .duoCard(cornerRadius: DuoMetrics.cardRadius)
                        
                        Spacer()
                            .frame(width: DuoMetrics.sidebarReserveWidth - DuoMetrics.trailingPadding)
                    }
                    .frame(height: 224)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
    }
    
    private var duoAppLaunchCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("糖葫芦大屏生态速启", systemImage: "sparkles.tv.fill")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(DuoPalette.textPrimary)
                Spacer()
                Text("一键协同")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(DuoPalette.accentRed)
            }
            
            HStack(spacing: 10) {
                ForEach(TanghuluAppCatalog.ecosystemApps) { app in
                    Button {
                        triggerLaunchApp(app)
                    } label: {
                        VStack(spacing: 8) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(app.accentColor.opacity(0.18))
                                    .frame(width: 44, height: 44)
                                Image(systemName: app.iconName)
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(app.accentColor)
                            }
                            Text(app.name.replacingOccurrences(of: "糖葫芦", with: ""))
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundColor(DuoPalette.textPrimary)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .duoCard(cornerRadius: DuoMetrics.compactCardRadius, fill: DuoPalette.cardElevated)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // 原生 Apple TV 4 大高频应用 2×2 快捷直达
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(Array(TanghuluAppCatalog.tvApps.prefix(4))) { tvApp in
                    duoMiniAppRow(tvApp)
                }
            }
        }
        .padding(14)
        .duoCard(cornerRadius: DuoMetrics.cardRadius)
    }
    
    private func duoMiniAppRow(_ app: TanghuluAppItem) -> some View {
        Button {
            triggerLaunchApp(app)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: app.iconName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(app.accentColor)
                Text(app.name)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundColor(DuoPalette.textPrimary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(DuoPalette.textMuted)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .duoCard(cornerRadius: 12, fill: DuoPalette.cardElevated)
        }
        .buttonStyle(.plain)
    }
    
    private var duoSystemKeysGridCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("电视物理系统键", systemImage: "appletvremote.gen4.fill")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(DuoPalette.textPrimary)
                Spacer()
                Text(isAwakeAndConnected ? "已唤醒" : "待机中")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(isAwakeAndConnected ? DuoPalette.readyGreen : DuoPalette.warmOrange)
            }
            
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    duoSystemSquareKey(icon: "house.fill", label: "桌面", tint: DuoPalette.brandBlue) {
                        DualModeRemoteCoordinator.shared.sendSystemKey(.home)
                    }
                    duoSystemSquareKey(icon: "arrow.uturn.backward", label: "返回", tint: DuoPalette.textPrimary) {
                        DualModeRemoteCoordinator.shared.sendSystemKey(.menu)
                    }
                }
                .frame(maxHeight: .infinity)
                
                HStack(spacing: 10) {
                    duoSystemSquareKey(icon: "speaker.slash.fill", label: "静音", tint: DuoPalette.warmOrange) {
                        DualModeRemoteCoordinator.shared.sendSystemKey(.mute)
                    }
                    duoSystemSquareKey(
                        icon: "power",
                        label: isAwakeAndConnected ? "待机" : "开机",
                        tint: isAwakeAndConnected ? DuoPalette.accentRed : DuoPalette.readyGreen
                    ) {
                        triggerPowerToggle()
                    }
                }
                .frame(maxHeight: .infinity)
            }
            .frame(maxHeight: .infinity)
        }
        .padding(14)
        .frame(maxHeight: .infinity, alignment: .top)
        .duoCard(cornerRadius: DuoMetrics.cardRadius)
    }
    
    private func duoSystemSquareKey(icon: String, label: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button {
            lightHaptic.impactOccurred()
            action()
        } label: {
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(tint)
                Text(label)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(DuoPalette.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 104, maxHeight: .infinity)
            .duoCard(cornerRadius: DuoMetrics.innerCardRadius, fill: DuoPalette.cardElevated)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("system_\(label)")
        .accessibilityLabel(label)
    }
    
    private var duoKeyboardShortcutCard: some View {
        Button {
            lightHaptic.impactOccurred()
            NotificationCenter.default.post(name: NSNotification.Name("HSBToggleRemoteKeyboardNotification"), object: nil)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(DuoPalette.brandBlue.opacity(0.16))
                        .frame(width: 38, height: 38)
                    Image(systemName: "keyboard.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(DuoPalette.brandBlue)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("呼出文本输入与语音搜索")
                        .font(.system(size: 13.5, weight: .bold, design: .rounded))
                        .foregroundColor(DuoPalette.textPrimary)
                    Text("直接在大屏搜索框键入中文、账号密码或网址")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(DuoPalette.textSecondary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(DuoPalette.textMuted)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .duoCard(cornerRadius: DuoMetrics.innerCardRadius)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - 共享基础子控件 (保留既有无障碍标识)
    
    private var mediaControlRow: some View {
        HStack(spacing: 10) {
            mediaControlButton(icon: "gobackward.10", title: "快退 10s") {
                DualModeRemoteCoordinator.shared.sendDPad(direction: .left, action: .tap)
            }
            
            mediaControlButton(icon: "playpause.fill", title: "播放 / 暂停", isPrimary: true) {
                DualModeRemoteCoordinator.shared.sendSystemKey(.playPause)
            }
            
            mediaControlButton(icon: "goforward.10", title: "快进 10s") {
                DualModeRemoteCoordinator.shared.sendDPad(direction: .right, action: .tap)
            }
        }
    }
    
    private func compactVolumeButton(isUp: Bool) -> some View {
        Button {
            triggerVolume(isUp)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isUp ? "speaker.plus.fill" : "speaker.minus.fill")
                    .font(.system(size: 13, weight: .semibold))
                Text(isUp ? "音量 +" : "音量 -")
                    .font(.system(size: 13, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .background(Color(UIColor.tertiarySystemBackground))
            .foregroundColor(.primary)
            .cornerRadius(10)
        }
        .accessibilityIdentifier(isUp ? "volume_up_button" : "volume_down_button")
        .accessibilityLabel(isUp ? "音量 +" : "音量 -")
    }
    
    private func duoVolumeTile(isUp: Bool) -> some View {
        Button {
            triggerVolume(isUp)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isUp ? "speaker.plus.fill" : "speaker.minus.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(isUp ? DuoPalette.readyGreen : DuoPalette.textPrimary)
                Text(isUp ? "音量 +" : "音量 -")
                    .font(.system(size: 13.5, weight: .bold, design: .rounded))
                    .foregroundColor(DuoPalette.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .duoCard(cornerRadius: 14, fill: DuoPalette.cardElevated)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(isUp ? "volume_up_button" : "volume_down_button")
        .accessibilityLabel(isUp ? "音量 +" : "音量 -")
    }
    
    private func mediaControlButton(icon: String, title: String, isPrimary: Bool = false, action: @escaping () -> Void) -> some View {
        Button {
            lightHaptic.impactOccurred()
            action()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: isPrimary ? 13 : 11.5, weight: .semibold))
                Text(title)
                    .font(.system(size: 11, weight: isPrimary ? .semibold : .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
            }
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity)
            .frame(height: isWideDuo ? 44 : 38)
            .background(isPrimary ? (isWideDuo ? DuoPalette.accentRed.opacity(0.22) : Color.accentColor.opacity(0.2)) : (isWideDuo ? DuoPalette.cardElevated : Color(UIColor.tertiarySystemBackground)))
            .foregroundColor(isPrimary ? (isWideDuo ? DuoPalette.accentRed : Color.accentColor) : (isWideDuo ? DuoPalette.textPrimary : .primary))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isPrimary ? (isWideDuo ? DuoPalette.accentRed.opacity(0.45) : Color.accentColor.opacity(0.4)) : Color.white.opacity(0.06), lineWidth: 1)
            )
        }
        .accessibilityIdentifier("media_\(title)")
        .accessibilityLabel(title)
    }
    
    @ViewBuilder
    private func systemIslandRoundButton(icon: String, label: String, tintColor: Color? = nil, action: @escaping () -> Void) -> some View {
        Button(action: {
            lightHaptic.impactOccurred()
            action()
        }) {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(tintColor != nil ? tintColor!.opacity(0.18) : Color(UIColor.tertiarySystemBackground))
                        .frame(width: 42, height: 42)
                        .overlay(
                            Circle()
                                .stroke(tintColor != nil ? tintColor!.opacity(0.4) : Color.white.opacity(0.1), lineWidth: 1)
                        )
                    Image(systemName: icon)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(tintColor ?? .primary)
                }
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(tintColor ?? .secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityIdentifier("system_\(label)")
        .accessibilityLabel(label)
    }
}

#if DEBUG
#Preview("系统硬件轮盘遥控 · 折叠窄屏") {
    DuoPreviewContainer(expandedDuo: false) {
        ModernSystemRemoteView(dpadSize: 215, isWideDuo: false)
    }
}

#Preview("系统硬件轮盘遥控 · iPhone Duo 双栏") {
    DuoPreviewContainer(expandedDuo: true) {
        ModernSystemRemoteView(dpadSize: 220, isWideDuo: true)
            .padding(18)
    }
}
#endif
