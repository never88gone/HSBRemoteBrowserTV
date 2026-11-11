//
//  ModernContactUsView.swift
//  HSBWatchCompanion
//
//  纯 SwiftUI 联系我们页面（支持网页跳转、邮件唤起及剪贴板复制提示）。
//

import SwiftUI
import UIKit

private struct ContactChannelItem: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let value: String
    let icon: String
    let tint: Color
    let type: ContactType
    
    enum ContactType {
        case url
        case email
    }
}

public struct ModernContactUsView: View {
    @Environment(\.openURL) private var openURL
    @State private var copiedBannerText: String?
    @State private var safariURL: URL?
    @State private var alertChannel: ContactChannelItem?
    
    private var channels: [ContactChannelItem] {
        [
            ContactChannelItem(
                title: hsbL("Official Website", "官方网站"),
                subtitle: "https://www.thltv.com/",
                value: "https://www.thltv.com/",
                icon: "globe",
                tint: DuoPalette.brandBlue,
                type: .url
            ),
            ContactChannelItem(
                title: hsbL("Telegram Group", "Telegram 交流群"),
                subtitle: "https://t.me/tanghulutvos",
                value: "https://t.me/tanghulutvos",
                icon: "paperplane.fill",
                tint: DuoPalette.readyGreen,
                type: .url
            ),
            ContactChannelItem(
                title: hsbL("Support Email", "客服与商务邮箱"),
                subtitle: "support@thltv.com",
                value: "support@thltv.com",
                icon: "envelope.fill",
                tint: DuoPalette.warmOrange,
                type: .email
            ),
            ContactChannelItem(
                title: hsbL("GitHub Repository", "GitHub 开源仓库"),
                subtitle: "github.com/never88gone/HSBRemoteBrowserTV",
                value: "https://github.com/never88gone/HSBRemoteBrowserTV",
                icon: "chevron.left.forwardslash.chevron.right",
                tint: DuoPalette.brandPurple,
                type: .url
            )
        ]
    }
    
    public init() {}
    
    public var body: some View {
        GeometryReader { geometry in
            let isWideDuo = geometry.size.width >= 550
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    introBanner
                    
                    let columns = isWideDuo
                        ? [GridItem(.flexible(), spacing: DuoMetrics.columnGap), GridItem(.flexible(), spacing: DuoMetrics.columnGap)]
                        : [GridItem(.flexible())]
                    
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(channels) { channel in
                            channelCard(channel)
                        }
                    }
                    
                    Text(hsbL(
                        "Tap any channel to open directly or copy contact address.",
                        "点击上方任一联系方式可直接打开浏览器或快速复制到剪贴板。"
                    ))
                    .font(.system(size: 12.5))
                    .foregroundColor(DuoPalette.textMuted)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 6)
                }
                .padding(.leading, isWideDuo ? DuoMetrics.outerPadding : 16)
                .padding(.trailing, isWideDuo ? DuoMetrics.trailingPadding : 16)
                .padding(.vertical, 18)
            }
            .background(DuoPalette.canvasBg.ignoresSafeArea())
            .overlay(alignment: .bottom) {
                if let text = copiedBannerText {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(DuoPalette.readyGreen)
                        Text(text)
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
        .navigationTitle(hsbL("Contact Us", "联系我们"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $safariURL) { url in
            ModernSafariView(url: url).ignoresSafeArea()
        }
        .alert(item: $alertChannel) { item in
            Alert(
                title: Text(item.title),
                message: Text("\(hsbL("Address", "联系方式")): \(item.value)"),
                primaryButton: .default(Text(hsbL("Copy Address", "复制地址"))) {
                    copyToPasteboard(item.value)
                },
                secondaryButton: .cancel(Text(hsbL("Close", "关闭")))
            )
        }
    }
    
    private var introBanner: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(DuoPalette.hawthornRed.opacity(0.18))
                    .frame(width: 48, height: 48)
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(DuoPalette.hawthornRed)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(hsbL("Official Support & Community", "官方支持与社区交流"))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(DuoPalette.textPrimary)
                Text(hsbL(
                    "Feedback, tvOS browser suggestions, or open-source collaboration.",
                    "欢迎提交建议、tvOS 浏览器反馈或参与开源生态共建。"
                ))
                .font(.system(size: 12.5))
                .foregroundColor(DuoPalette.textSecondary)
            }
            Spacer()
        }
        .padding(16)
        .duoCard(cornerRadius: DuoMetrics.innerCardRadius)
    }
    
    private func channelCard(_ item: ContactChannelItem) -> some View {
        Button {
            handleTap(item)
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(item.tint.opacity(0.16))
                        .frame(width: 42, height: 42)
                    Image(systemName: item.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(item.tint)
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
                        .font(.system(size: 15.5, weight: .semibold))
                        .foregroundColor(DuoPalette.textPrimary)
                    Text(item.subtitle)
                        .font(.system(size: 12.5))
                        .foregroundColor(DuoPalette.textSecondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Button {
                    copyToPasteboard(item.value)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 14))
                        .foregroundColor(DuoPalette.textMuted)
                        .padding(8)
                }
                .buttonStyle(.plain)
            }
            .padding(14)
            .duoCard(cornerRadius: DuoMetrics.innerCardRadius)
        }
        .buttonStyle(.plain)
    }
    
    private func handleTap(_ item: ContactChannelItem) {
        switch item.type {
        case .url:
            if let url = URL(string: item.value) {
                if item.value.contains("thltv.com") || item.value.contains("github.com") {
                    safariURL = url
                } else {
                    openURL(url)
                }
            }
        case .email:
            if let mailURL = URL(string: "mailto:\(item.value)") {
                openURL(mailURL) { accepted in
                    if !accepted {
                        alertChannel = item
                    }
                }
            }
        }
    }
    
    private func copyToPasteboard(_ text: String) {
        UIPasteboard.general.string = text
        withAnimation(.easeInOut(duration: 0.2)) {
            copiedBannerText = hsbL("Copied to clipboard: \(text)", "已复制到剪贴板：\(text)")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeInOut(duration: 0.2)) {
                copiedBannerText = nil
            }
        }
    }
}

#if DEBUG
#Preview("联系我们 · 折叠窄屏") {
    DuoPreviewContainer("联系我们", expandedDuo: false) {
        ModernContactUsView()
    }
}

#Preview("联系我们 · iPhone Duo 双栏展开") {
    DuoPreviewContainer("联系我们", expandedDuo: true) {
        ModernContactUsView()
    }
}
#endif
