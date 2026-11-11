//
//  ModernPrivacyPolicyView.swift
//  HSBWatchCompanion
//
//  纯 SwiftUI 隐私政策详情页面（完整迁移自原 SettingsViewController 条款）。
//

import SwiftUI

private struct PrivacyClause: Identifiable {
    let id = UUID()
    let number: String
    let title: String
    let content: String
    let icon: String
    let tint: Color
}

public struct ModernPrivacyPolicyView: View {
    private var clauses: [PrivacyClause] {
        [
            PrivacyClause(
                number: "01",
                title: hsbL("Data Collection & Usage", "1. 数据收集与使用"),
                content: hsbL(
                    "This app operates as a remote control and motion tracker companion. We solemnly promise that this app does NOT collect, store, or upload any of your personal identifiable information.\nAll control communications are transmitted directly between your devices over your local area network.",
                    "本应用主要作为外围设备的遥控和体感数据采集工具。我们郑重承诺，本应用不会收集、存储或上传您的任何个人身份信息与隐私。\n所有的控制通信（如控制指令）仅在您的本地局域网内进行设备间的直接传输。"
                ),
                icon: "lock.shield.fill",
                tint: DuoPalette.readyGreen
            ),
            PrivacyClause(
                number: "02",
                title: hsbL("Permissions Description", "2. 权限说明"),
                content: hsbL(
                    "• Local Network: Used strictly to discover and connect to smart TV or large display devices within your local network.\n• Motion & Fitness: Used for calculating motion gestures and local step counting.",
                    "• 本地网络权限：仅用于发现并连接局域网内的智能电视或大屏设备。\n• 运动与健身权限：仅用于体感手势判定与本地步数统计。"
                ),
                icon: "wifi.circle.fill",
                tint: DuoPalette.brandBlue
            ),
            PrivacyClause(
                number: "03",
                title: hsbL("Information Sharing", "3. 信息共享"),
                content: hsbL(
                    "We do not share any data with third parties. All processing is handled locally on-device.",
                    "我们不会与任何第三方分享您的数据，所有数据均只在本地实时处理。"
                ),
                icon: "iphone.and.arrow.forward",
                tint: DuoPalette.brandPurple
            ),
            PrivacyClause(
                number: "04",
                title: hsbL("Contact Us", "4. 联系我们"),
                content: hsbL(
                    "If you have any questions, please contact developer support via Settings -> Contact Us.",
                    "如有任何问题，可在设置界面通过「联系我们」联系官方开发者支持。"
                ),
                icon: "envelope.badge.fill",
                tint: DuoPalette.warmOrange
            )
        ]
    }
    
    public init() {}
    
    public var body: some View {
        GeometryReader { geometry in
            let isWideDuo = geometry.size.width >= 550
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    bannerCard
                    
                    let columns = isWideDuo
                        ? [GridItem(.flexible(), spacing: DuoMetrics.columnGap), GridItem(.flexible(), spacing: DuoMetrics.columnGap)]
                        : [GridItem(.flexible())]
                    
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(clauses) { clause in
                            clauseCard(clause)
                        }
                    }
                }
                .padding(.leading, isWideDuo ? DuoMetrics.outerPadding : 16)
                .padding(.trailing, isWideDuo ? DuoMetrics.trailingPadding : 16)
                .padding(.vertical, 18)
            }
            .background(DuoPalette.canvasBg.ignoresSafeArea())
        }
        .navigationTitle(hsbL("Privacy Policy", "隐私政策"))
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var bannerCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(DuoPalette.readyGreen.opacity(0.16))
                    .frame(width: 46, height: 46)
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(DuoPalette.readyGreen)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(hsbL("Tanghulu Remote Privacy Policy", "糖葫芦遥控器（Tanghulu Remote）隐私政策"))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(DuoPalette.textPrimary)
                Text(hsbL("Zero cloud uploads. 100% local area network direct communication.", "全本地执行、零服务器采集、保护每一条隐私记录"))
                    .font(.system(size: 12.5))
                    .foregroundColor(DuoPalette.textSecondary)
            }
            Spacer()
        }
        .padding(16)
        .duoCard(cornerRadius: DuoMetrics.innerCardRadius)
    }
    
    private func clauseCard(_ clause: PrivacyClause) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(clause.tint.opacity(0.16))
                        .frame(width: 34, height: 34)
                    Image(systemName: clause.icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(clause.tint)
                }
                Text(clause.title)
                    .font(.system(size: 15.5, weight: .semibold))
                    .foregroundColor(DuoPalette.textPrimary)
                Spacer()
            }
            
            Text(clause.content)
                .font(.system(size: 13.5))
                .foregroundColor(DuoPalette.textSecondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .duoCard(cornerRadius: DuoMetrics.innerCardRadius)
    }
}

#if DEBUG
#Preview("隐私政策 · 折叠窄屏") {
    DuoPreviewContainer("隐私政策", expandedDuo: false) {
        ModernPrivacyPolicyView()
    }
}

#Preview("隐私政策 · iPhone Duo 双栏展开") {
    DuoPreviewContainer("隐私政策", expandedDuo: true) {
        ModernPrivacyPolicyView()
    }
}
#endif
