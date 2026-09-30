//
//  ModernAppGridView.swift
//  HSBWatchCompanion
//
//  沿用 itsytv-macos 极简高效的应用启动器 (App Grid) 哲学。
//  使用与 itsytv-macos 完全统一的 Apple TV Companion 连接通道，
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

public struct ModernAppGridView: View {
    public var onSelectApp: (TanghuluAppItem) -> Void
    
    private let haptic = UIImpactFeedbackGenerator(style: .medium)
    
    // 糖葫芦全生态三大旗舰核心应用 (附带 itsytv 协议深度解析 URL Scheme 载荷)
    private let ecosystemApps: [TanghuluAppItem] = [
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
    
    // Apple TV 常用原生与第三方应用列表 (itsytv-macos 经典阵列)
    private let tvApps: [TanghuluAppItem] = [
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
    
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    public init(onSelectApp: @escaping (TanghuluAppItem) -> Void) {
        self.onSelectApp = onSelectApp
    }
    
    public var body: some View {
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
                        ForEach(ecosystemApps) { app in
                            ecosystemAppRow(app: app)
                        }
                    }
                }
                
                // 2. Apple TV 经典应用阵列 (itsytv-macos 风格网格)
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
                        ForEach(tvApps) { app in
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
    private func systemAppCard(app: TanghuluAppItem) -> some View {
        Button {
            haptic.impactOccurred()
            onSelectApp(app)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(app.accentColor.opacity(0.16))
                        .frame(width: 40, height: 40)
                    Image(systemName: app.iconName)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(app.accentColor)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(app.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Text(app.subtitle)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
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
