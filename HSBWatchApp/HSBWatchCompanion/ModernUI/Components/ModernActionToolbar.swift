//
//  ModernActionToolbar.swift
//  HSBWatchCompanion
//

import SwiftUI
import UIKit

public struct ModernActionToolbar: View {
    @Binding public var currentMode: HSBRemoteMode
    public var onSystemKey: ((SystemKey) -> Void)?
    public var onPageAction: ((PageAction) -> Void)?
    public var onToggleKeyboard: (() -> Void)?
    
    private let lightHaptic = UIImpactFeedbackGenerator(style: .light)
    
    public init(
        currentMode: Binding<HSBRemoteMode>,
        onSystemKey: ((SystemKey) -> Void)? = nil,
        onPageAction: ((PageAction) -> Void)? = nil,
        onToggleKeyboard: (() -> Void)? = nil
    ) {
        self._currentMode = currentMode
        self.onSystemKey = onSystemKey
        self.onPageAction = onPageAction
        self.onToggleKeyboard = onToggleKeyboard
    }
    
    public var body: some View {
        VStack(spacing: 16) {
            // 系统与媒体快捷按钮行
            HStack(spacing: 18) {
                // 系统 Home 键
                actionRoundButton(icon: "house.fill", label: "桌面") {
                    onSystemKey?(.home)
                }
                
                // 返回/Menu 键
                actionRoundButton(icon: "arrow.uturn.backward", label: "返回") {
                    onSystemKey?(.menu)
                }
                
                // 键盘输入键
                actionRoundButton(icon: "keyboard", label: "打字") {
                    onToggleKeyboard?()
                }
                
                // 静音键
                actionRoundButton(icon: "speaker.slash.fill", label: "静音") {
                    onSystemKey?(.mute)
                }
                
                // 播放/暂停键
                actionRoundButton(icon: "playpause.fill", label: "播放") {
                    onSystemKey?(.playPause)
                }
            }
            
            // 音量与浏览器导航栏
            HStack(spacing: 16) {
                // 网页后退
                navIconButton(icon: "chevron.backward") {
                    onPageAction?(.back)
                }
                
                // 网页前进
                navIconButton(icon: "chevron.forward") {
                    onPageAction?(.forward)
                }
                
                // 网页刷新
                navIconButton(icon: "arrow.clockwise") {
                    onPageAction?(.reload)
                }
                
                Spacer()
                
                // 音量减
                navIconButton(icon: "speaker.minus.fill") {
                    onSystemKey?(.volumeDown)
                }
                
                // 音量加
                navIconButton(icon: "speaker.plus.fill") {
                    onSystemKey?(.volumeUp)
                }
            }
            .padding(.horizontal, 8)
        }
    }
    
    @ViewBuilder
    private func actionRoundButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            lightHaptic.impactOccurred()
            action()
        }) {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(Color(UIColor.secondarySystemBackground))
                        .frame(width: 48, height: 48)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                    
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.primary)
                }
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    @ViewBuilder
    private func navIconButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            lightHaptic.impactOccurred()
            action()
        }) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.primary)
                .frame(width: 42, height: 42)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(UIColor.secondarySystemBackground))
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
