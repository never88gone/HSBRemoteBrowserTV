//
//  DuoDesignSystem.swift
//  HSBWatchCompanion
//
//  专为 iPhone Duo 折叠屏展开态（width >= 550pt）打造的统一视觉与空间布局底座：
//  1. 严格划分左/右双栏与中央 26pt 折痕安全呼吸带（Hinge Safe Zone）；
//  2. 提供 L 型右下让位度量，既消除侧边栏上方垂直黑空，又保证右下 4 键操盘栏零遮挡；
//  3. 提供顶部环境感知双子条（DuoAmbientTopStrip），彻底消灭顶部黑色空带且不展示电池/返回键。
//

import SwiftUI

public enum DuoMetrics {
    /// 展开态画布左侧外边距
    public static let outerPadding: CGFloat = 20
    /// 展开态画布右侧安全防遮挡外边距 (预留舒适呼吸带，杜绝贴边遮挡)
    public static let trailingPadding: CGFloat = 22
    /// 左右两栏中间避让折叠铰链的安全呼吸间隙
    public static let columnGap: CGFloat = 26
    /// 右下 4 键纯扁平操作侧边栏需要让出的右侧宽度 (56pt 宽 + 22pt 边距 + 14pt 缓冲)
    public static let sidebarReserveWidth: CGFloat = 92
    /// 右侧侧边栏高度占位 (用于 L 型让位或安全滚动底边距)
    public static let sidebarHeight: CGFloat = 252
    
    public static let cardRadius: CGFloat = 22
    public static let innerCardRadius: CGFloat = 16
    public static let compactCardRadius: CGFloat = 14
    
    /// 根据总宽计算均衡的左右栏宽 (严格以折痕为界居中对称)
    public static func columnWidth(for totalWidth: CGFloat) -> CGFloat {
        max(220, (totalWidth - outerPadding - trailingPadding - columnGap) / 2.0)
    }
    
    /// 右下角向左侧收缩让位给侧边栏的净宽
    public static func lowerRightReducedWidth(for totalWidth: CGFloat) -> CGFloat {
        let fullRightWidth = columnWidth(for: totalWidth)
        return max(160, fullRightWidth - (sidebarReserveWidth - trailingPadding))
    }
}

public enum DuoPalette {
    public static let cardFill = Color(red: 30.0 / 255.0, green: 31.0 / 255.0, blue: 40.0 / 255.0).opacity(0.94)
    public static let cardElevated = Color(red: 40.0 / 255.0, green: 42.0 / 255.0, blue: 51.0 / 255.0).opacity(0.96)
    public static let stroke = Color.white.opacity(0.085)
    public static let strokeBright = Color.white.opacity(0.16)
    
    /// 活力朱砂红 (#FF453A) - 用于扁平激活与高频主操
    public static let accentRed = Color(red: 1.0, green: 69.0 / 255.0, blue: 58.0 / 255.0)
    public static let hawthornRed = Color(red: 224.0 / 255.0, green: 36.0 / 255.0, blue: 56.0 / 255.0)
    public static let brandBlue = Color(red: 38.0 / 255.0, green: 140.0 / 255.0, blue: 1.0)
    public static let readyGreen = Color(red: 52.0 / 255.0, green: 199.0 / 255.0, blue: 89.0 / 255.0)
    public static let warmOrange = Color(red: 1.0, green: 149.0 / 255.0, blue: 0.0)
    public static let brightYellow = Color(red: 1.0, green: 214.0 / 255.0, blue: 10.0 / 255.0)
    
    public static let textPrimary = Color(red: 245.0 / 255.0, green: 247.0 / 255.0, blue: 252.0 / 255.0)
    public static let textSecondary = Color(red: 161.0 / 255.0, green: 166.0 / 255.0, blue: 181.0 / 255.0)
    public static let textMuted = Color(red: 112.0 / 255.0, green: 117.0 / 255.0, blue: 133.0 / 255.0)
    public static let silverInactive = Color(red: 161.0 / 255.0, green: 166.0 / 255.0, blue: 184.0 / 255.0)
}

public extension View {
    /// V2 统一深炭黑质感圆角卡片修饰器
    func duoCard(
        cornerRadius: CGFloat = DuoMetrics.cardRadius,
        fill: Color = DuoPalette.cardFill,
        stroke: Color = DuoPalette.stroke,
        lineWidth: CGFloat = 1.0
    ) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(fill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(stroke, lineWidth: lineWidth)
            )
    }
}

/// 顶部环境感知条中的单侧状态卡片
struct DuoAmbientPillCard: View {
    let icon: String
    let tint: Color
    let title: String
    let subtitle: String
    let actionIcon: String?
    var actionTint: Color = DuoPalette.textPrimary
    var actionIdentifier: String? = nil
    var onCardTap: (() -> Void)? = nil
    var onTrailingAction: (() -> Void)? = nil
    
    var body: some View {
        HStack(spacing: 10) {
            Button {
                onCardTap?()
            } label: {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(tint.opacity(0.16))
                            .frame(width: 34, height: 34)
                        Image(systemName: icon)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(tint)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.system(size: 13.5, weight: .bold, design: .rounded))
                            .foregroundColor(DuoPalette.textPrimary)
                            .lineLimit(1)
                        Text(subtitle)
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundColor(DuoPalette.textSecondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            if let actionIcon = actionIcon {
                Button {
                    onTrailingAction?()
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(DuoPalette.cardElevated)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(DuoPalette.stroke, lineWidth: 1)
                            )
                            .frame(width: 34, height: 34)
                        Image(systemName: actionIcon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(actionTint)
                    }
                }
                .buttonStyle(.plain)
                .modifier(OptionalAccessibilityIdentifier(identifier: actionIdentifier))
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 54)
        .duoCard(cornerRadius: 16, fill: DuoPalette.cardFill, stroke: DuoPalette.stroke)
    }
}

private struct OptionalAccessibilityIdentifier: ViewModifier {
    let identifier: String?
    func body(content: Content) -> some View {
        if let id = identifier, !id.isEmpty {
            content.accessibilityIdentifier(id)
        } else {
            content
        }
    }
}

/// 展开态顶部对称双子感知条（无电池、无返回按钮、填满原顶部空带）
struct DuoAmbientTopStrip: View {
    @ObservedObject var coordinatorObserver: CoordinatorObservable
    let selectedMainTab: Int
    let selectedControlTab: Int
    @Binding var showingBrowserGuide: Bool
    @Binding var showingSystemGuide: Bool
    
    @State private var showingBrowserManageActionSheet: Bool = false
    private let lightHaptic = UIImpactFeedbackGenerator(style: .light)
    
    var body: some View {
        HStack(spacing: DuoMetrics.columnGap) {
            leftAmbientCard
                .frame(maxWidth: .infinity)
            rightAmbientCard
                .frame(maxWidth: .infinity)
        }
        .actionSheet(isPresented: $showingBrowserManageActionSheet) {
            ActionSheet(
                title: Text("大屏通道控制 (\(coordinatorObserver.browserDeviceName.isEmpty ? "糖葫芦浏览器" : coordinatorObserver.browserDeviceName))"),
                message: Text("当前已建立 TLS 1.2 加密长连接专线 (端口 56789)，支持触控板滑动、双指滚动与 EPG 协同。"),
                buttons: [
                    .default(Text("🔄 刷新与测试大屏通道")) {
                        lightHaptic.impactOccurred()
                        coordinatorObserver.refreshBrowserChannel()
                    },
                    .default(Text("📱 重新扫码配对新大屏")) {
                        lightHaptic.impactOccurred()
                        coordinatorObserver.forgetPairedBrowserAndRescan()
                    },
                    .destructive(Text("🚫 断开大屏连接")) {
                        lightHaptic.impactOccurred()
                        coordinatorObserver.disconnectBrowserChannel()
                    },
                    .cancel(Text("取消"))
                ]
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("HSBShowScreenManageSheetNotification"))) { _ in
            showingBrowserManageActionSheet = true
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("HSBDismissScreenManageSheetNotification"))) { _ in
            showingBrowserManageActionSheet = false
        }
    }
    
    @ViewBuilder
    private var leftAmbientCard: some View {
        if coordinatorObserver.isTargetMac {
            DuoAmbientPillCard(
                icon: "desktopcomputer",
                tint: DuoPalette.hawthornRed,
                title: coordinatorObserver.targetDeviceName.isEmpty ? "Mac 电脑" : coordinatorObserver.targetDeviceName,
                subtitle: "macOS 原生音频隔空播放直控已就绪",
                actionIcon: nil
            )
        } else {
            let statusInfo = nativeSystemInfo
            DuoAmbientPillCard(
                icon: "appletv.fill",
                tint: statusInfo.tint,
                title: statusInfo.title,
                subtitle: statusInfo.subtitle,
                actionIcon: "arrow.left.arrow.right",
                actionTint: DuoPalette.textSecondary,
                onCardTap: {
                    lightHaptic.impactOccurred()
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showingSystemGuide = true
                    }
                },
                onTrailingAction: {
                    lightHaptic.impactOccurred()
                    NotificationCenter.default.post(name: Notification.Name("HSBExitRemotePageNotification"), object: nil)
                }
            )
        }
    }
    
    @ViewBuilder
    private var rightAmbientCard: some View {
        if coordinatorObserver.isTargetMac {
            DuoAmbientPillCard(
                icon: "checkmark.shield.fill",
                tint: DuoPalette.readyGreen,
                title: "100% 免装软件安全直连",
                subtitle: "系统原生隔空播放接收器 · 点击右钮断开",
                actionIcon: "power",
                actionTint: DuoPalette.accentRed,
                actionIdentifier: "mac_disconnect_button",
                onCardTap: {
                    lightHaptic.impactOccurred()
                    NotificationCenter.default.post(name: Notification.Name("HSBShowMacAirPlayHelpNotification"), object: nil)
                },
                onTrailingAction: {
                    lightHaptic.impactOccurred()
                    DualModeRemoteCoordinator.shared.disconnectAll()
                    NotificationCenter.default.post(name: Notification.Name("HSBExitRemotePageNotification"), object: nil)
                }
            )
        } else {
            let rightInfo = browserChannelInfo
            DuoAmbientPillCard(
                icon: rightInfo.icon,
                tint: rightInfo.tint,
                title: rightInfo.title,
                subtitle: rightInfo.subtitle,
                actionIcon: coordinatorObserver.isHSBBrowserConnected ? "slider.horizontal.3" : "qrcode.viewfinder",
                actionTint: coordinatorObserver.isHSBBrowserConnected ? DuoPalette.textPrimary : DuoPalette.accentRed,
                onCardTap: {
                    handleBrowserChannelTap()
                },
                onTrailingAction: {
                    handleBrowserActionTap()
                }
            )
        }
    }
    
    private func handleBrowserChannelTap() {
        lightHaptic.impactOccurred()
        if coordinatorObserver.isHSBBrowserConnected {
            showingBrowserManageActionSheet = true
        } else {
            withAnimation(.easeInOut(duration: 0.2)) {
                showingBrowserGuide = true
            }
        }
    }
    
    private func handleBrowserActionTap() {
        lightHaptic.impactOccurred()
        if coordinatorObserver.isHSBBrowserConnected {
            showingBrowserManageActionSheet = true
        } else {
            NotificationCenter.default.post(name: Notification.Name("HSBOpenQRCodeScannerNotification"), object: nil)
        }
    }
    
    private var nativeSystemInfo: (title: String, subtitle: String, tint: Color) {
        let name = (!coordinatorObserver.targetDeviceName.isEmpty && coordinatorObserver.targetDeviceName != "Mac")
            ? coordinatorObserver.targetDeviceName
            : "Apple TV 大屏"
        if coordinatorObserver.isNativeConnected {
            return (name, "原生硬件控制通道直连就绪", DuoPalette.readyGreen)
        } else if coordinatorObserver.isHSBBrowserConnected {
            return ("协同遥控模式", "大屏应用通道已协同激活", DuoPalette.readyGreen)
        }
        switch coordinatorObserver.state {
        case .ready(let devName, _):
            return (devName, "原生硬件控制通道就绪", DuoPalette.readyGreen)
        case .connecting:
            return (name, "正在建立硬件加密通道...", DuoPalette.warmOrange)
        case .pairing:
            return (name, "正在等待 PIN 码配对完成...", DuoPalette.warmOrange)
        case .scanning:
            return ("正在搜寻设备", "mDNS 自动发现周边 Apple TV", DuoPalette.brandBlue)
        case .failed(let err):
            return (name, err.contains("待机") ? "电视休眠中 · 点击唤醒" : "硬件通道未连接 · 点击查看指引", DuoPalette.warmOrange)
        case .disconnected:
            return ("Apple TV 硬件通道", "尚未配对 · 点击查看配对指引", DuoPalette.textSecondary)
        }
    }
    
    private var browserChannelInfo: (title: String, subtitle: String, icon: String, tint: Color) {
        if coordinatorObserver.isHSBBrowserConnected {
            let devName = coordinatorObserver.browserDeviceName.isEmpty ? "糖葫芦大屏生态" : coordinatorObserver.browserDeviceName
            switch (selectedMainTab, selectedControlTab) {
            case (0, 1):
                return ("\(devName) · WebKit 4K", "TLS 1.2 专线 · 5.5x 触控指针同步中", "safari.fill", DuoPalette.brandBlue)
            case (0, 2):
                return ("\(devName) · 糖葫芦 TV", "TLS 1.2 专线 · IPTV 频道目录已同步", "play.tv.fill", DuoPalette.readyGreen)
            case (0, 3):
                return ("\(devName) · 糖葫芦 PDF", "TLS 1.2 专线 · 16:9 实时激光画板同步", "doc.richtext.fill", DuoPalette.warmOrange)
            default:
                return ("\(devName) · 已同步", "TLS 1.2 加密长连接专线 (56789)", "sparkles", DuoPalette.brandBlue)
            }
        } else if coordinatorObserver.isHSBBrowserReconnecting {
            return ("糖葫芦大屏通道 · 重连中", "正在恢复 TLS 1.2 专线 · 点击扫码", "arrow.triangle.2.circlepath", DuoPalette.warmOrange)
        } else if let nearby = coordinatorObserver.nearbyDiscoveredBrowserTV {
            return ("发现周边大屏【\(nearby)】", "点击右侧二维码图标即可秒级直连", "dot.radiowaves.left.and.right", DuoPalette.warmOrange)
        } else {
            return ("大屏专属应用通道", "点击扫描电视端二维码秒级建立直连", "qrcode.viewfinder", DuoPalette.brandBlue)
        }
    }
}

public extension DuoPalette {
    /// 全局页面深炭黑底色，确保所有子页面与遥控台视觉连贯
    static let canvasBg = Color(red: 13.0 / 255.0, green: 14.0 / 255.0, blue: 18.0 / 255.0)
    static let brandPurple = Color(red: 168.0 / 255.0, green: 85.0 / 255.0, blue: 247.0 / 255.0)
}

/// 统一中英文双语本地化助手（与原 OC 逻辑保持 100% 一致）
public func hsbL(_ en: String, _ zh: String) -> String {
    if let first = Locale.preferredLanguages.first, first.hasPrefix("zh") {
        return zh
    }
    return en
}

#if DEBUG
/// 专用于 Xcode Preview 画布的视图容器，支持一键模拟折叠屏窄屏或 iPhone Duo (669×951) 展开双栏
public struct DuoPreviewContainer<Content: View>: View {
    public let title: String?
    public let isExpandedDuo: Bool
    @ViewBuilder public let content: () -> Content
    
    public init(_ title: String? = nil, expandedDuo: Bool = false, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.isExpandedDuo = expandedDuo
        self.content = content
    }
    
    public var body: some View {
        Group {
            if let title = title {
                NavigationStack {
                    content()
                        .navigationTitle(title)
                        .navigationBarTitleDisplayMode(.inline)
                }
            } else {
                content()
            }
        }
        .preferredColorScheme(.dark)
        .tint(.white)
        .frame(width: isExpandedDuo ? 669 : 393, height: isExpandedDuo ? 951 : 852)
        .background(DuoPalette.canvasBg)
    }
}
#endif
