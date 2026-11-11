//
//  ModernAppGridView.swift
//  HSBWatchCompanion
//
//  糖葫芦极简高效的大屏应用启动器 (App Grid)。
//  使用统一的 Apple TV 原生与协同连接通道，
//  一键 launchApp 唤起大屏应用并实现与糖葫芦浏览器、糖葫芦TV、糖葫芦PDF的深度协同。
//

import SwiftUI

public struct TanghuluAppItem: Identifiable {
    public let id: String
    public let name: String
    public let subtitle: String
    public let bundleID: String
    public let url: String?
    public let iconName: String
    public let isSystemSymbol: Bool
    public let accentColor: Color
    public let targetMode: Int // 0: 系统/通用, 1: 触控浏览器, 2: IPTV, 3: PDF演讲
    
    public init(
        id: String,
        name: String,
        subtitle: String,
        bundleID: String,
        url: String? = nil,
        iconName: String,
        isSystemSymbol: Bool = true,
        accentColor: Color = .blue,
        targetMode: Int = 0
    ) {
        self.id = id
        self.name = name
        self.subtitle = subtitle
        self.bundleID = bundleID
        self.url = url
        self.iconName = iconName
        self.isSystemSymbol = isSystemSymbol
        self.accentColor = accentColor
        self.targetMode = targetMode
    }
}

public enum TanghuluAppCatalog {
    // 糖葫芦全生态三大旗舰核心应用 (附带系统协议深度解析 URL Scheme 载荷)
    public static let ecosystemApps: [TanghuluAppItem] = [
        TanghuluAppItem(
            id: "browser",
            name: "糖葫芦浏览器",
            subtitle: "4K WebKit 网页极清冲浪 · 5.5x 触控微操",
            bundleID: "com.never88gone.thlbrowser",
            url: "thlbrowser://web?body={'url':'https://cn.bing.com'}",
            iconName: "safari.fill",
            accentColor: Color(red: 0.15, green: 0.55, blue: 0.98),
            targetMode: 1
        ),
        TanghuluAppItem(
            id: "iptv",
            name: "糖葫芦TV",
            subtitle: "客厅电视直播流 · EPG电子节目单 · 毫秒换台",
            bundleID: "com.nevergone.huluge.iptv",
            url: "thliptv://home",
            iconName: "tv.fill",
            accentColor: Color(red: 0.2, green: 0.8, blue: 0.45),
            targetMode: 2
        ),
        TanghuluAppItem(
            id: "pdf",
            name: "糖葫芦PDF",
            subtitle: "商务大屏演说 · 无线幻灯片翻页 · 激光笔批注",
            bundleID: "com.never88gone.thlpdf",
            url: "thlpdf://home",
            iconName: "doc.richtext.fill",
            accentColor: Color(red: 0.98, green: 0.45, blue: 0.2),
            targetMode: 3
        )
    ]
    
    // Apple TV 常用原生与第三方应用列表 (经典应用阵列)
    public static let tvApps: [TanghuluAppItem] = [
        TanghuluAppItem(
            id: "appletv",
            name: "Apple TV",
            subtitle: "影视流媒体与影视库",
            bundleID: "com.apple.TVWatchList",
            iconName: "appletv.fill",
            accentColor: .white,
            targetMode: 0
        ),
        TanghuluAppItem(
            id: "appstore",
            name: "App Store",
            subtitle: "大屏电视应用商店",
            bundleID: "com.apple.TVAppStore",
            iconName: "bag.fill",
            accentColor: Color(red: 0.1, green: 0.6, blue: 0.95),
            targetMode: 0
        ),
        TanghuluAppItem(
            id: "settings",
            name: "系统设置",
            subtitle: "tvOS 设备核心配置",
            bundleID: "com.apple.TVSettings",
            iconName: "gearshape.fill",
            accentColor: Color(red: 0.6, green: 0.6, blue: 0.65),
            targetMode: 0
        ),
        TanghuluAppItem(
            id: "music",
            name: "Apple Music",
            subtitle: "无损高保真客厅音乐",
            bundleID: "com.apple.TVMusic",
            iconName: "music.note",
            accentColor: Color(red: 0.98, green: 0.2, blue: 0.35),
            targetMode: 0
        ),
        TanghuluAppItem(
            id: "youtube",
            name: "YouTube",
            subtitle: "全球视频精选",
            bundleID: "com.google.ios.youtube",
            iconName: "play.rectangle.fill",
            accentColor: Color(red: 0.95, green: 0.15, blue: 0.15),
            targetMode: 0
        ),
        TanghuluAppItem(
            id: "photos",
            name: "照片",
            subtitle: "4K 幻灯片与家庭影集",
            bundleID: "com.apple.TVPhotos",
            iconName: "photo.on.rectangle.angled",
            accentColor: Color(red: 0.2, green: 0.7, blue: 0.9),
            targetMode: 0
        )
    ]
}

public struct ModernAppGridView: View {
    public var isWideDuo: Bool = false
    public var onSelectApp: (TanghuluAppItem) -> Void
    
    private let haptic = UIImpactFeedbackGenerator(style: .medium)
    
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    public init(isWideDuo: Bool = false, onSelectApp: @escaping (TanghuluAppItem) -> Void) {
        self.isWideDuo = isWideDuo
        self.onSelectApp = onSelectApp
    }
    
    public var body: some View {
        if isWideDuo {
            wideDuoBody
        } else {
            compactBody
        }
    }
    
    /// iPhone Duo 展开态：左栏糖葫芦三大旗舰生态 × 右栏 tvOS 常用应用矩阵 (右下角自然留出侧边栏位)
    private var wideDuoBody: some View {
        HStack(alignment: .top, spacing: DuoMetrics.columnGap) {
            // 左半屏：糖葫芦生态专属阵地 + 大屏快捷情景控制台
            VStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(DuoPalette.accentRed)
                        Text("糖葫芦大屏专属生态")
                            .font(.system(size: 13.5, weight: .bold))
                            .foregroundColor(DuoPalette.textSecondary)
                        Spacer()
                        Text("同一连接 · 秒级直达")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(DuoPalette.brandBlue)
                    }
                    
                    ForEach(TanghuluAppCatalog.ecosystemApps) { app in
                        ecosystemAppRow(app: app)
                    }
                }
                .padding(16)
                .duoCard()
                
                // 左下充实面板：四大真实情景微操台一键直达
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("情景微操台快捷切换", systemImage: "rectangle.3.group.fill")
                            .font(.system(size: 13.5, weight: .bold))
                            .foregroundColor(DuoPalette.textSecondary)
                        Spacer()
                        Text("秒切形态")
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundColor(DuoPalette.readyGreen)
                    }
                    
                    VStack(spacing: 10) {
                        duoSceneQuickLinkRow(title: "系统原装轮盘", subtitle: "Apple TV 同心 D-Pad · 实体物理键 · 硬件音量", icon: "circle.circle.fill", color: DuoPalette.accentRed, tabIndex: 0)
                        duoSceneQuickLinkRow(title: "网页无界触控板", subtitle: "5.5x 桌面级光学手势指针 · 双指平滑翻页", icon: "hand.draw.fill", color: DuoPalette.brandBlue, tabIndex: 1)
                        duoSceneQuickLinkRow(title: "IPTV 高清选台台", subtitle: "数字键盘直选 · 频道收藏与 EPG 管理", icon: "tv.fill", color: DuoPalette.readyGreen, tabIndex: 2)
                        duoSceneQuickLinkRow(title: "PDF 演讲激光板", subtitle: "16:9 跨折痕同步激光标注 · 演示计时器", icon: "laser.burst", color: DuoPalette.warmOrange, tabIndex: 3)
                    }
                    .frame(maxHeight: .infinity)
                }
                .padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .duoCard()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // 右半屏：Apple TV 常用与系统应用（弹性铺满无大片留白）+ 右下 L 型留白避让侧边栏
            VStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 6) {
                        Image(systemName: "square.grid.2x2.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(DuoPalette.textSecondary)
                        Text("Apple TV 常用与系统应用")
                            .font(.system(size: 13.5, weight: .bold))
                            .foregroundColor(DuoPalette.textSecondary)
                        Spacer()
                        Text("原生遥控联动")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(DuoPalette.brandBlue)
                    }
                    
                    let tvRows = stride(from: 0, to: TanghuluAppCatalog.tvApps.count, by: 2).map { $0 }
                    VStack(spacing: 12) {
                        ForEach(tvRows, id: \.self) { rowStart in
                            HStack(spacing: 12) {
                                systemAppCard(app: TanghuluAppCatalog.tvApps[rowStart], fillHeight: true)
                                if rowStart + 1 < TanghuluAppCatalog.tvApps.count {
                                    systemAppCard(app: TanghuluAppCatalog.tvApps[rowStart + 1], fillHeight: true)
                                } else {
                                    Spacer()
                                        .frame(maxWidth: .infinity)
                                }
                            }
                            .frame(maxHeight: .infinity)
                        }
                    }
                    .frame(maxHeight: .infinity)
                }
                .padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .duoCard()
                
                // L 型左下卡：224pt 全覆盖避让右侧 4 键，避免上方网格最底卡与「轮盘/触控」重叠
                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Image(systemName: "cursorarrow.click.2")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(DuoPalette.brandBlue)
                                Text("点击任一应用立即在大屏唤醒")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(DuoPalette.textPrimary)
                            }
                            Text("糖葫芦系列应用唤醒后将自动为您匹配对应触控板、数字选台盘或幻灯画板。")
                                .font(.system(size: 11.5, weight: .regular))
                                .foregroundColor(DuoPalette.textSecondary)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        
                        Spacer(minLength: 0)
                        
                        HStack(spacing: 10) {
                            Button {
                                haptic.impactOccurred()
                                NotificationCenter.default.post(name: NSNotification.Name("HSBOpenQRCodeScannerNotification"), object: nil)
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "qrcode.viewfinder")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(DuoPalette.brandBlue)
                                    Text("扫码直连大屏")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(DuoPalette.textPrimary)
                                        .lineLimit(1)
                                }
                                .frame(maxWidth: .infinity, minHeight: 46)
                                .duoCard(cornerRadius: 12, fill: DuoPalette.cardElevated)
                            }
                            .buttonStyle(.plain)
                            
                            Button {
                                haptic.impactOccurred()
                                NotificationCenter.default.post(name: NSNotification.Name("HSBToggleRemoteKeyboardNotification"), object: nil)
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "keyboard.fill")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(DuoPalette.warmOrange)
                                    Text("远程文本键入")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(DuoPalette.textPrimary)
                                        .lineLimit(1)
                                }
                                .frame(maxWidth: .infinity, minHeight: 46)
                                .duoCard(cornerRadius: 12, fill: DuoPalette.cardElevated)
                            }
                            .buttonStyle(.plain)
                        }
                        
                        HStack(spacing: 6) {
                            Circle()
                                .fill(DuoPalette.readyGreen)
                                .frame(width: 6, height: 6)
                            Text("支持跨应用无缝保活 · 毫秒级场景协议切换")
                                .font(.system(size: 10.5, weight: .medium))
                                .foregroundColor(DuoPalette.textMuted)
                                .lineLimit(1)
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .duoCard()
                    
                    Spacer()
                        .frame(width: DuoMetrics.sidebarReserveWidth - DuoMetrics.trailingPadding)
                }
                .frame(height: 224)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    private func duoSceneQuickLinkRow(title: String, subtitle: String, icon: String, color: Color, tabIndex: Int) -> some View {
        Button {
            haptic.impactOccurred()
            NotificationCenter.default.post(
                name: Notification.Name("HSBSwitchRemoteTabNotification"),
                object: nil,
                userInfo: ["tab": tabIndex]
            )
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(color.opacity(0.16))
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(color)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13.5, weight: .bold))
                        .foregroundColor(DuoPalette.textPrimary)
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(DuoPalette.textSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(DuoPalette.textMuted)
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .duoCard(cornerRadius: DuoMetrics.innerCardRadius, fill: DuoPalette.cardElevated)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var compactBody: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                // 1. 糖葫芦全生态核心联动板块
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.tanghuluBrandBlue)
                        Text("糖葫芦大屏专属生态")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("同一连接 · 秒级直达")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                    .padding(.horizontal, 4)
                    
                    VStack(spacing: 10) {
                        ForEach(TanghuluAppCatalog.ecosystemApps) { app in
                            ecosystemAppRow(app: app)
                        }
                    }
                }
                
                // 2. Apple TV 常用与系统应用网格
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: "square.grid.2x2.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.secondary)
                        Text("Apple TV 常用与系统应用")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 4)
                    
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(TanghuluAppCatalog.tvApps) { app in
                            systemAppCard(app: app)
                        }
                    }
                }
                
                Spacer(minLength: 24)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
    }
    
    // 糖葫芦专属生态宽卡片
    @ViewBuilder
    private func ecosystemAppRow(app: TanghuluAppItem) -> some View {
        Button {
            haptic.impactOccurred()
            onSelectApp(app)
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(app.accentColor.opacity(0.18))
                        .frame(width: 52, height: 52)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(app.accentColor.opacity(0.4), lineWidth: 1)
                        )
                    Image(systemName: app.iconName)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(app.accentColor)
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(app.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "arrow.up.forward.app")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    Text(app.subtitle)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(UIColor.secondarySystemBackground).opacity(0.75))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // 原生 App 双列小卡片
    @ViewBuilder
    private func systemAppCard(app: TanghuluAppItem, fillHeight: Bool = false) -> some View {
        Button {
            haptic.impactOccurred()
            onSelectApp(app)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(app.accentColor.opacity(0.16))
                        .frame(width: fillHeight ? 46 : 40, height: fillHeight ? 46 : 40)
                    Image(systemName: app.iconName)
                        .font(.system(size: fillHeight ? 21 : 18, weight: .medium))
                        .foregroundColor(app.accentColor)
                }
                
                if fillHeight {
                    Spacer(minLength: 4)
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(app.name)
                        .font(.system(size: fillHeight ? 15 : 14, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Text(app.subtitle)
                        .font(.system(size: fillHeight ? 11.5 : 11, weight: .regular))
                        .foregroundColor(.secondary)
                        .lineLimit(fillHeight ? 2 : 1)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: fillHeight ? .infinity : nil, alignment: .leading)
            .padding(fillHeight ? 14 : 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(UIColor.secondarySystemBackground).opacity(0.6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#if DEBUG
#Preview("应用生态中心 · 折叠窄屏") {
    DuoPreviewContainer(expandedDuo: false) {
        ModernAppGridView(isWideDuo: false) { _ in }
    }
}

#Preview("应用生态中心 · iPhone Duo 双栏") {
    DuoPreviewContainer(expandedDuo: true) {
        ModernAppGridView(isWideDuo: true) { _ in }
            .padding(18)
    }
}
#endif
