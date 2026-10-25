//
//  ModernWebRemoteView.swift
//  HSBWatchCompanion
//

import SwiftUI

public struct ModernWebRemoteView: View {
    @State private var isFullScreenTrackpad: Bool = false
    private let lightHaptic = UIImpactFeedbackGenerator(style: .light)
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: isFullScreenTrackpad ? 8 : 14) {
            // 触控微操板 (内置右上角全屏切换按钮)
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
            .padding(.horizontal, isFullScreenTrackpad ? 8 : 16)
            
            // 网页悬浮磨砂操作岛 (后退、前进、刷新、主页、放大)
            if !isFullScreenTrackpad {
                HStack(spacing: 8) {
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
    
    @ViewBuilder
    private func webNavButton(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            lightHaptic.impactOccurred()
            action()
        }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                Text(title)
                    .font(.system(size: 10, weight: .medium))
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(Color(UIColor.secondarySystemBackground))
            .foregroundColor(.primary)
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
