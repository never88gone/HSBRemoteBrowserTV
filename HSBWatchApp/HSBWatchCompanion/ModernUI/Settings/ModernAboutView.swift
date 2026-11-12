//
//  ModernAboutView.swift
//  HSBWatchCompanion
//
//  纯 SwiftUI 关于我们页面（支持品牌主视觉发光、版本号快捷拷贝及 iPhone Duo 双栏分列排版）。
//

import SwiftUI
import UIKit

public struct ModernAboutView: View {
    @State private var copiedToastVisible: Bool = false
    
    private var appDisplayName: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? hsbL("Tanghulu Remote", "糖葫芦遥控器")
    }
    
    private var shortVersion: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "1.0.1"
    }
    
    private var buildVersion: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String) ?? "1"
    }
    
    public init() {}
    
    public var body: some View {
        GeometryReader { geometry in
            let isWideDuo = geometry.size.width >= 550
            ScrollView(showsIndicators: false) {
                if isWideDuo {
                    HStack(alignment: .top, spacing: DuoMetrics.columnGap) {
                        brandHeroCard
                            .frame(width: DuoMetrics.columnWidth(for: geometry.size.width))
                        
                        VStack(spacing: 14) {
                            highlightsCard
                            versionCopyCard
                        }
                        .frame(width: DuoMetrics.columnWidth(for: geometry.size.width))
                    }
                    .padding(.leading, DuoMetrics.outerPadding)
                    .padding(.trailing, DuoMetrics.trailingPadding)
                    .padding(.vertical, 22)
                } else {
                    VStack(spacing: 18) {
                        brandHeroCard
                        highlightsCard
                        versionCopyCard
                        Text("Copyright © 2026 THL. All rights reserved.")
                            .font(.system(size: 12))
                            .foregroundColor(DuoPalette.textMuted)
                            .padding(.top, 12)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 22)
                }
            }
            .background(DuoPalette.canvasBg.ignoresSafeArea())
            .overlay(alignment: .bottom) {
                if copiedToastVisible {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(DuoPalette.readyGreen)
                        Text(hsbL("Version copied to clipboard", "版本号已复制到剪贴板"))
                            .font(.system(size: 13.5, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Color.black.opacity(0.86)))
                    .overlay(Capsule().stroke(DuoPalette.strokeBright, lineWidth: 1))
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .navigationTitle(hsbL("About Us", "关于我们"))
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var brandHeroCard: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(DuoPalette.hawthornRed.opacity(0.18))
                    .frame(width: 118, height: 118)
                    .blur(radius: 14)
                
                if let brandImg = UIImage(named: "brandlogo") ?? UIImage(named: "logo") {
                    Image(uiImage: brandImg)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 100, height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(DuoPalette.hawthornRed.opacity(0.35), lineWidth: 1.5)
                        )
                        .shadow(color: DuoPalette.hawthornRed.opacity(0.35), radius: 14, y: 6)
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(DuoPalette.cardElevated)
                            .frame(width: 100, height: 100)
                        Image(systemName: "play.tv.fill")
                            .font(.system(size: 44, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(DuoPalette.hawthornRed.opacity(0.35), lineWidth: 1.5)
                    )
                    .shadow(color: DuoPalette.hawthornRed.opacity(0.3), radius: 14, y: 6)
                }
            }
            
            Text(appDisplayName)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(DuoPalette.textPrimary)
            
            Text(hsbL(
                "Smart interactive companion bridging wrist and palm.",
                "腕间与手掌间的智慧交互伴侣"
            ))
            .font(.system(size: 14.5))
            .foregroundColor(DuoPalette.textSecondary)
            .multilineTextAlignment(.center)
            
            Button {
                UIPasteboard.general.string = "\(appDisplayName) \(shortVersion) (\(buildVersion))"
                withAnimation(.easeInOut(duration: 0.2)) {
                    copiedToastVisible = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        copiedToastVisible = false
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text("\(hsbL("Version", "版本")) \(shortVersion) (\(buildVersion))")
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundColor(DuoPalette.textSecondary)
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 12))
                        .foregroundColor(DuoPalette.textMuted)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Capsule().fill(DuoPalette.cardElevated))
                .overlay(Capsule().stroke(DuoPalette.stroke, lineWidth: 1))
            }
            .buttonStyle(.plain)
            
            Text("Copyright © 2026 THL. All rights reserved.")
                .font(.system(size: 11.5))
                .foregroundColor(DuoPalette.textMuted)
                .padding(.top, 4)
        }
        .padding(.vertical, 28)
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity)
        .duoCard(cornerRadius: DuoMetrics.cardRadius)
    }
    
    private var highlightsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(hsbL("CORE ARCHITECTURE", "核心架构与特性"))
                .font(.system(size: 11.5, weight: .bold))
                .foregroundColor(DuoPalette.hawthornRed)
            
            featureRow(
                icon: "appletvremote.gen4.fill",
                tint: DuoPalette.hawthornRed,
                title: hsbL("Native Companion & AirPlay Bridge", "双模智能协议融合引擎"),
                detail: hsbL("SRP authentication with Apple TV, zero-config Mac media bridge & Android TV control.", "支持 Apple TV 原生硬件直连配对、Mac 无感媒体控制及大屏糖葫芦浏览器专线。")
            )
            
            featureRow(
                icon: "cpu.fill",
                tint: DuoPalette.brandBlue,
                title: hsbL("On-Device Apple Silicon MLX AI", "端侧 Apple MLX 本地人工智能"),
                detail: hsbL("Zero-cloud privacy translation, voice semantics and intelligent web assistants.", "全离线端侧大模型推理与实时双语字幕同传，保护个人隐私零云端泄漏。")
            )
            
            featureRow(
                icon: "ipad.landscape",
                tint: DuoPalette.readyGreen,
                title: hsbL("iPhone Duo Responsive Layout", "折叠屏宽幅双栏无死角适配"),
                detail: hsbL("Pure SwiftUI adaptive layout tailored for compact fold and wide dual-column panels.", "纯 SwiftUI 响应式双栏布局，折叠单手与展开双屏各自发挥极限操控效率。")
            )
        }
        .padding(18)
        .duoCard(cornerRadius: DuoMetrics.cardRadius)
    }
    
    private var versionCopyCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 20))
                .foregroundColor(DuoPalette.readyGreen)
            VStack(alignment: .leading, spacing: 2) {
                Text(hsbL("Local-First Privacy Guarantee", "纯本地网络直连与隐私承诺"))
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundColor(DuoPalette.textPrimary)
                Text(hsbL("Zero telemetry, zero cloud accounts.", "无账号追踪、无行为埋点，控制指令 100% 留存本地局域网。"))
                    .font(.system(size: 12.5))
                    .foregroundColor(DuoPalette.textSecondary)
            }
            Spacer()
        }
        .padding(16)
        .duoCard(cornerRadius: DuoMetrics.innerCardRadius)
    }
    
    private func featureRow(icon: String, tint: Color, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(tint.opacity(0.15))
                    .frame(width: 34, height: 34)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(tint)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundColor(DuoPalette.textPrimary)
                Text(detail)
                    .font(.system(size: 12.5))
                    .foregroundColor(DuoPalette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#if DEBUG
#Preview("关于我们 · 折叠窄屏") {
    DuoPreviewContainer("关于我们", expandedDuo: false) {
        ModernAboutView()
    }
}

#Preview("关于我们 · iPhone Duo 双栏展开") {
    DuoPreviewContainer("关于我们", expandedDuo: true) {
        ModernAboutView()
    }
}
#endif
