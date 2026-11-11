//
//  ModernSettingsView.swift
//  HSBWatchCompanion
//
//  纯 SwiftUI 系统设置页面：
//  - 保留原 3 大核心分区：AI 智能与引擎、翻译源/目标语言实时持久化偏好、第三方组件/隐私/联系/关于；
//  - iPhone Duo 展开宽屏（width >= 550pt）自动以双栏 Bento 展示，彻底消除大屏两侧黑空。
//

import SwiftUI

public struct ModernSettingsView: View {
    @AppStorage("HSBTranslationSourceLanguage") private var sourceLanguage: String = "Auto"
    @AppStorage("HSBTranslationTargetLanguage") private var targetLanguage: String = "Chinese"
    
    @State private var showingSourcePicker: Bool = false
    @State private var showingTargetPicker: Bool = false
    
    private let onNavigate: (HSBAppRoute) -> Void
    
    private let sourceKeys = ["Auto", "Chinese", "English", "Japanese", "Korean", "French", "German", "Spanish", "Russian"]
    private let targetKeys = ["Chinese", "English", "Japanese", "Korean", "French", "German", "Spanish", "Russian"]
    
    public init(onNavigate: @escaping (HSBAppRoute) -> Void) {
        self.onNavigate = onNavigate
    }
    
    public var body: some View {
        GeometryReader { geometry in
            let isWideDuo = geometry.size.width >= 550
            ScrollView(showsIndicators: false) {
                if isWideDuo {
                    HStack(alignment: .top, spacing: DuoMetrics.columnGap) {
                        VStack(spacing: 18) {
                            aiSectionCard
                            translationSectionCard
                        }
                        .frame(width: DuoMetrics.columnWidth(for: geometry.size.width))
                        
                        VStack(spacing: 18) {
                            systemInfoSectionCard
                            versionFooterCard
                        }
                        .frame(width: DuoMetrics.columnWidth(for: geometry.size.width))
                    }
                    .padding(.leading, DuoMetrics.outerPadding)
                    .padding(.trailing, DuoMetrics.trailingPadding)
                    .padding(.vertical, 18)
                } else {
                    VStack(spacing: 20) {
                        aiSectionCard
                        translationSectionCard
                        systemInfoSectionCard
                        versionFooterText
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                }
            }
            .background(DuoPalette.canvasBg.ignoresSafeArea())
        }
        .navigationTitle(hsbL("Settings", "设置"))
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            hsbL("Select Source Language", "设置翻译源语言"),
            isPresented: $showingSourcePicker,
            titleVisibility: .visible
        ) {
            ForEach(sourceKeys, id: \.self) { key in
                Button(localizedLanguageName(for: key) + (key == sourceLanguage ? " ✓" : "")) {
                    sourceLanguage = key
                }
            }
            Button(hsbL("Cancel", "取消"), role: .cancel) {}
        }
        .confirmationDialog(
            hsbL("Select Target Language", "设置翻译目标语言"),
            isPresented: $showingTargetPicker,
            titleVisibility: .visible
        ) {
            ForEach(targetKeys, id: \.self) { key in
                Button(localizedLanguageName(for: key) + (key == targetLanguage ? " ✓" : "")) {
                    targetLanguage = key
                }
            }
            Button(hsbL("Cancel", "取消"), role: .cancel) {}
        }
    }
    
    // MARK: - Section 0: AI 智能与自动化引擎
    private var aiSectionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(hsbL("AI INTELLIGENCE", "AI 智能与自动化引擎"))
            VStack(spacing: 0) {
                settingsRow(
                    icon: "cpu.fill",
                    tint: DuoPalette.brandPurple,
                    title: hsbL("AI Model Center", "AI 模型中心"),
                    detail: hsbL("On-device MLX & API Engine", "端侧大模型管理与配置")
                ) {
                    onNavigate(.aiModelCenter)
                }
                
                Divider().background(DuoPalette.stroke)
                
                settingsRow(
                    icon: "wand.and.stars",
                    tint: DuoPalette.readyGreen,
                    title: hsbL("AI Assistant", "AI 智能助手"),
                    detail: hsbL("Translate · Control · Butler", "同声传译 · 控屏 · 管家实测")
                ) {
                    onNavigate(.llmTest)
                }
            }
            .duoCard(cornerRadius: DuoMetrics.innerCardRadius)
        }
    }
    
    // MARK: - Section 1: 翻译与交互偏好
    private var translationSectionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(hsbL("TRANSLATION PREFERENCES", "翻译与交互偏好"))
            VStack(spacing: 0) {
                settingsRow(
                    icon: "text.bubble.fill",
                    tint: DuoPalette.brandBlue,
                    title: hsbL("Source Language", "翻译源语言"),
                    trailingBadge: localizedLanguageName(for: sourceLanguage)
                ) {
                    showingSourcePicker = true
                }
                
                Divider().background(DuoPalette.stroke)
                
                settingsRow(
                    icon: "character.book.closed.fill",
                    tint: DuoPalette.warmOrange,
                    title: hsbL("Target Language", "翻译目标语言"),
                    trailingBadge: localizedLanguageName(for: targetLanguage)
                ) {
                    showingTargetPicker = true
                }
            }
            .duoCard(cornerRadius: DuoMetrics.innerCardRadius)
        }
    }
    
    // MARK: - Section 2: 系统信息与支持
    private var systemInfoSectionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(hsbL("SYSTEM & SUPPORT", "系统信息与支持"))
            VStack(spacing: 0) {
                settingsRow(
                    icon: "shippingbox.fill",
                    tint: DuoPalette.brandBlue,
                    title: hsbL("Third-Party Components", "第三方组件"),
                    detail: hsbL("9 Open-Source Engines", "appletv-remote · mlx-swift · swift-nio 等")
                ) {
                    onNavigate(.openSourceLibraries)
                }
                
                Divider().background(DuoPalette.stroke)
                
                settingsRow(
                    icon: "hand.raised.fill",
                    tint: DuoPalette.readyGreen,
                    title: hsbL("Privacy Policy", "隐私政策")
                ) {
                    onNavigate(.privacyPolicy)
                }
                
                Divider().background(DuoPalette.stroke)
                
                settingsRow(
                    icon: "envelope.fill",
                    tint: DuoPalette.warmOrange,
                    title: hsbL("Contact Us", "联系我们")
                ) {
                    onNavigate(.contactUs)
                }
                
                Divider().background(DuoPalette.stroke)
                
                settingsRow(
                    icon: "info.circle.fill",
                    tint: DuoPalette.hawthornRed,
                    title: hsbL("About Us", "关于我们")
                ) {
                    onNavigate(.about)
                }
            }
            .duoCard(cornerRadius: DuoMetrics.innerCardRadius)
        }
    }
    
    private var versionFooterCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "appletvremote.gen4.fill")
                .font(.system(size: 20))
                .foregroundColor(DuoPalette.hawthornRed)
            VStack(alignment: .leading, spacing: 2) {
                Text(versionString)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(DuoPalette.textPrimary)
                Text(hsbL("Pure SwiftUI Architecture · Zero Objective-C Views", "纯 SwiftUI 响应式引擎驱动 · iPhone Duo 双栏适配"))
                    .font(.system(size: 12))
                    .foregroundColor(DuoPalette.textSecondary)
            }
            Spacer()
        }
        .padding(16)
        .duoCard(cornerRadius: DuoMetrics.innerCardRadius)
    }
    
    private var versionFooterText: some View {
        Text(versionString)
            .font(.system(size: 12.5))
            .foregroundColor(DuoPalette.textMuted)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 4)
    }
    
    private var versionString: String {
        let short = (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "1.0"
        let build = (Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String) ?? "1"
        return "\(hsbL("Tanghulu Remote Version", "糖葫芦遥控器 版本")) \(short) (\(build))"
    }
    
    // MARK: - Helpers
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(DuoPalette.textMuted)
            .padding(.horizontal, 6)
    }
    
    private func settingsRow(
        icon: String,
        tint: Color,
        title: String,
        detail: String? = nil,
        trailingBadge: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(tint.opacity(0.16))
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .font(.system(size: 14.5, weight: .semibold))
                        .foregroundColor(tint)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15.5, weight: .medium))
                        .foregroundColor(DuoPalette.textPrimary)
                    if let detail = detail {
                        Text(detail)
                            .font(.system(size: 12))
                            .foregroundColor(DuoPalette.textSecondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                if let badge = trailingBadge {
                    Text(badge)
                        .font(.system(size: 13.5, weight: .medium))
                        .foregroundColor(DuoPalette.textSecondary)
                }
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundColor(DuoPalette.textMuted)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    private func localizedLanguageName(for key: String) -> String {
        switch key {
        case "Auto": return hsbL("Auto Detect", "自动检测")
        case "Chinese": return hsbL("Chinese", "中文")
        case "English": return hsbL("English", "英文")
        case "Japanese": return hsbL("Japanese", "日文")
        case "Korean": return hsbL("Korean", "韩文")
        case "French": return hsbL("French", "法文")
        case "German": return hsbL("German", "德文")
        case "Spanish": return hsbL("Spanish", "西班牙文")
        case "Russian": return hsbL("Russian", "俄文")
        default: return key
        }
    }
}

#if DEBUG
#Preview("设置页面 · 折叠窄屏") {
    DuoPreviewContainer("设置", expandedDuo: false) {
        ModernSettingsView { _ in }
    }
}

#Preview("设置页面 · iPhone Duo 双栏展开") {
    DuoPreviewContainer("设置", expandedDuo: true) {
        ModernSettingsView { _ in }
    }
}
#endif
