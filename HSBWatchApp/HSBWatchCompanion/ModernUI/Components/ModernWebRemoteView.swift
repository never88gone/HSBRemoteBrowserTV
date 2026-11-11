//
//  ModernWebRemoteView.swift
//  HSBWatchCompanion
//

import SwiftUI

public struct ModernWebRemoteView: View {
    public var isWideDuo: Bool = false
    @State private var isFullScreenTrackpad: Bool = false
    private let lightHaptic = UIImpactFeedbackGenerator(style: .light)
    
    public init(isWideDuo: Bool = false) {
        self.isWideDuo = isWideDuo
    }
    
    public var body: some View {
        Group {
            if isWideDuo && !isFullScreenTrackpad {
                wideDuoBody
            } else {
                compactBody
            }
        }
    }
    
    private var compactBody: some View {
        VStack(spacing: isFullScreenTrackpad ? 8 : 14) {
            touchpadView
                .padding(.horizontal, isFullScreenTrackpad ? 8 : 16)
            
            // 网页悬浮磨砂操作岛 (后退、前进、刷新、主页、放大)
            if !isFullScreenTrackpad {
                HStack(spacing: 8) {
                    webNavRow
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(UIColor.secondarySystemBackground).opacity(0.65))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
        }
    }
    
    private var wideDuoBody: some View {
        VStack(alignment: .leading, spacing: 14) {
            // 上区：全宽扩展大号触控微操板（跨折痕流畅滑动）
            touchpadView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // 下区：左栏 5 键网页控制岛 + 右栏左让位「网址搜索输入 / 全景触发 / 确认按键」（224pt 等高严防上方画板碰触右侧边栏）
            HStack(alignment: .top, spacing: DuoMetrics.columnGap) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Label("桌面级网页浏览控制岛", systemImage: "safari.fill")
                            .font(.system(size: 13.5, weight: .bold, design: .rounded))
                            .foregroundColor(DuoPalette.textPrimary)
                        Spacer()
                        Text("8 阶平滑惯性手势")
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundColor(DuoPalette.brandBlue)
                    }
                    
                    HStack(spacing: 10) {
                        webNavRow
                    }
                    .frame(maxHeight: .infinity)
                    
                    HStack(spacing: 8) {
                        Image(systemName: "hand.point.up.left.fill")
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundColor(DuoPalette.brandBlue)
                        Text("单指轻点等效鼠标左键 · 双指轻点右键 · 双指上下顺滑翻页")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(DuoPalette.textSecondary)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .duoCard(cornerRadius: 11, fill: DuoPalette.cardElevated)
                }
                .padding(14)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .duoCard(cornerRadius: DuoMetrics.cardRadius)
                
                // 右下 L 型让位区：向左侧收缩让出侧边栏
                HStack(spacing: 0) {
                    VStack(spacing: 8) {
                        Button {
                            lightHaptic.impactOccurred()
                            NotificationCenter.default.post(name: NSNotification.Name("HSBToggleRemoteKeyboardNotification"), object: nil)
                        } label: {
                            HStack(spacing: 10) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(DuoPalette.brandBlue.opacity(0.18))
                                        .frame(width: 36, height: 36)
                                    Image(systemName: "magnifyingglass")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(DuoPalette.brandBlue)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("输入网址或搜索词")
                                        .font(.system(size: 12.5, weight: .bold, design: .rounded))
                                        .foregroundColor(DuoPalette.textPrimary)
                                        .lineLimit(1)
                                    Text("呼出文本输入向大屏键入")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(DuoPalette.textSecondary)
                                        .lineLimit(1)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 10)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .duoCard(cornerRadius: DuoMetrics.innerCardRadius, fill: DuoPalette.cardElevated)
                        }
                        .buttonStyle(.plain)
                        
                        Button {
                            lightHaptic.impactOccurred()
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                isFullScreenTrackpad = true
                            }
                            NotificationCenter.default.post(
                                name: Notification.Name("HSBTrackpadFullScreenChangedNotification"),
                                object: nil,
                                userInfo: ["isFullScreen": true]
                            )
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(DuoPalette.accentRed)
                                Text("切换全景无界触控板")
                                    .font(.system(size: 12.5, weight: .bold, design: .rounded))
                                    .foregroundColor(DuoPalette.textPrimary)
                                    .lineLimit(1)
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 12)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .duoCard(cornerRadius: 13, fill: DuoPalette.cardElevated)
                        }
                        .buttonStyle(.plain)
                        
                        Button {
                            lightHaptic.impactOccurred()
                            DualModeRemoteCoordinator.shared.sendSelect(action: .tap)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "return")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(DuoPalette.readyGreen)
                                Text("发送确定 / 鼠标左键")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundColor(DuoPalette.textPrimary)
                                    .lineLimit(1)
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 12)
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .duoCard(cornerRadius: 13, fill: DuoPalette.readyGreen.opacity(0.14), stroke: DuoPalette.readyGreen.opacity(0.3))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .duoCard(cornerRadius: DuoMetrics.cardRadius)
                    
                    Spacer()
                        .frame(width: DuoMetrics.sidebarReserveWidth - DuoMetrics.trailingPadding)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(height: 224)
        }
    }
    
    private var touchpadView: some View {
        ModernTouchpadView(
            isFullScreen: $isFullScreenTrackpad,
            onPan: { dx, dy in
                DualModeRemoteCoordinator.shared.sendCursorPan(dx: dx, dy: dy)
            },
            onTap: { mode, pt in
                DualModeRemoteCoordinator.shared.sendTap(mode: mode, point: pt)
            },
            onScroll: { dx, dy in
                DualModeRemoteCoordinator.shared.sendScroll(dx: dx, dy: dy)
            },
            onDrag: { state, dx, dy in
                DualModeRemoteCoordinator.shared.sendDrag(state: state, dx: dx, dy: dy)
            },
            onZoom: { scale in
                DualModeRemoteCoordinator.shared.sendZoom(scale: scale)
            }
        )
    }
    
    @ViewBuilder
    private var webNavRow: some View {
        webNavButton(icon: "chevron.backward", title: "后退") {
            DualModeRemoteCoordinator.shared.sendPageAction(.back)
        }
        webNavButton(icon: "chevron.forward", title: "前进") {
            DualModeRemoteCoordinator.shared.sendPageAction(.forward)
        }
        webNavButton(icon: "arrow.clockwise", title: "刷新") {
            DualModeRemoteCoordinator.shared.sendPageAction(.reload)
        }
        webNavButton(icon: "house", title: "主页") {
            DualModeRemoteCoordinator.shared.sendPageAction(.home)
        }
        webNavButton(icon: "plus.magnifyingglass", title: "放大") {
            DualModeRemoteCoordinator.shared.sendZoom(scale: 1.25)
        }
    }
    
    @ViewBuilder
    private func webNavButton(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            lightHaptic.impactOccurred()
            action()
        }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: isWideDuo ? 18 : 16, weight: .semibold))
                Text(title)
                    .font(.system(size: isWideDuo ? 11 : 10, weight: .semibold))
            }
            .frame(maxWidth: .infinity, minHeight: isWideDuo ? 64 : 44)
            .background(isWideDuo ? DuoPalette.cardElevated : Color(UIColor.secondarySystemBackground))
            .foregroundColor(isWideDuo ? DuoPalette.textPrimary : .primary)
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#if DEBUG
#Preview("Web 浏览器精准触控 · 折叠窄屏") {
    DuoPreviewContainer(expandedDuo: false) {
        ModernWebRemoteView(isWideDuo: false)
    }
}

#Preview("Web 浏览器精准触控 · iPhone Duo 双栏") {
    DuoPreviewContainer(expandedDuo: true) {
        ModernWebRemoteView(isWideDuo: true)
            .padding(18)
    }
}
#endif
