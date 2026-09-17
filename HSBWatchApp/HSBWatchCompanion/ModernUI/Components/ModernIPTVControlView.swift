//
//  ModernIPTVControlView.swift
//  HSBWatchCompanion
//

import SwiftUI
import UIKit

public struct ModernIPTVControlView: View {
    public var onAction: ((HSBRemoteSimulateAction) -> Void)?
    public var onPlayChannel: ((String, String) -> Void)?
    public var onDigit: ((Int) -> Void)?
    
    @State private var inputDigits: String = ""
    private let haptic = UIImpactFeedbackGenerator(style: .medium)
    private let lightHaptic = UIImpactFeedbackGenerator(style: .light)
    
    // 热门预置频道
    private let quickChannels: [(name: String, id: String)] = [
        ("CCTV-1 综合", "cctv1"),
        ("CCTV-5 体育", "cctv5"),
        ("CCTV-13 新闻", "cctv13"),
        ("湖南卫视", "hunan"),
        ("浙江卫视", "zhejiang"),
        ("东方卫视", "dongfang")
    ]
    
    public init(
        onAction: ((HSBRemoteSimulateAction) -> Void)? = nil,
        onPlayChannel: ((String, String) -> Void)? = nil,
        onDigit: ((Int) -> Void)? = nil
    ) {
        self.onAction = onAction
        self.onPlayChannel = onPlayChannel
        self.onDigit = onDigit
    }
    
    public var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 20) {
                // 1. 核心换台与音量双子塔
                HStack(spacing: 16) {
                    // 频道调节塔 (Channel Tower)
                    VStack(spacing: 12) {
                        Text("频道 CH")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                        
                        Button {
                            haptic.impactOccurred()
                            onAction?(.channelUp)
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: "chevron.up")
                                    .font(.system(size: 20, weight: .bold))
                                Text("+")
                                    .font(.system(size: 16, weight: .heavy))
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        .buttonStyle(TowerButtonStyle())
                        
                        Button {
                            haptic.impactOccurred()
                            onAction?(.channelDown)
                        } label: {
                            VStack(spacing: 4) {
                                Text("-")
                                    .font(.system(size: 16, weight: .heavy))
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 20, weight: .bold))
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        .buttonStyle(TowerButtonStyle())
                    }
                    .frame(height: 190)
                    .padding(12)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(20)
                    
                    // 音量调节塔 (Volume Tower)
                    VStack(spacing: 12) {
                        Text("音量 VOL")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                        
                        Button {
                            haptic.impactOccurred()
                            onAction?(.volumeUp)
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: "speaker.plus.fill")
                                    .font(.system(size: 20, weight: .bold))
                                Text("+")
                                    .font(.system(size: 16, weight: .heavy))
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        .buttonStyle(TowerButtonStyle())
                        
                        Button {
                            haptic.impactOccurred()
                            onAction?(.volumeDown)
                        } label: {
                            VStack(spacing: 4) {
                                Text("-")
                                    .font(.system(size: 16, weight: .heavy))
                                Image(systemName: "speaker.minus.fill")
                                    .font(.system(size: 20, weight: .bold))
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        .buttonStyle(TowerButtonStyle())
                    }
                    .frame(height: 190)
                    .padding(12)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(20)
                }
                .padding(.horizontal, 16)
                
                // 2. 媒体辅助功能条 (静音、全屏、节目单、暂停)
                HStack(spacing: 12) {
                    iptvActionButton(title: "静音", icon: "speaker.slash.fill") {
                        onAction?(.toggleMute)
                    }
                    iptvActionButton(title: "全屏", icon: "arrow.up.left.and.arrow.down.right") {
                        onAction?(.select)
                    }
                    iptvActionButton(title: "节目单", icon: "list.bullet.rectangle.portrait.fill") {
                        onAction?(.iptvEpg)
                    }
                    iptvActionButton(title: "播放/暂停", icon: "playpause.fill") {
                        onAction?(.play)
                    }
                }
                .padding(.horizontal, 16)
                
                // 3. 热门电视频道直达胶囊
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "sparkles.tv")
                            .foregroundColor(.accentColor)
                        Text("快捷频道直达")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(quickChannels, id: \.id) { ch in
                                Button {
                                    lightHaptic.impactOccurred()
                                    onPlayChannel?(ch.name, ch.id)
                                } label: {
                                    Text(ch.name)
                                        .font(.system(size: 13, weight: .medium))
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(Color(UIColor.tertiarySystemBackground))
                                        .foregroundColor(.primary)
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                                        )
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
                
                // 4. 数字选台键盘
                VStack(spacing: 10) {
                    if !inputDigits.isEmpty {
                        HStack {
                            Text("已输入台号:")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                            Text(inputDigits)
                                .font(.system(size: 20, weight: .heavy, design: .monospaced))
                                .foregroundColor(.accentColor)
                            Spacer()
                            Button("清除") {
                                inputDigits = ""
                            }
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 20)
                    }
                    
                    let grid = [
                        [1, 2, 3],
                        [4, 5, 6],
                        [7, 8, 9]
                    ]
                    
                    ForEach(grid, id: \.self) { row in
                        HStack(spacing: 16) {
                            ForEach(row, id: \.self) { num in
                                digitButton("\(num)") {
                                    handleDigit(num)
                                }
                            }
                        }
                    }
                    
                    HStack(spacing: 16) {
                        digitButton("回看") {
                            onAction?(.menu)
                        }
                        digitButton("0") {
                            handleDigit(0)
                        }
                        digitButton("确定") {
                            haptic.impactOccurred()
                            onAction?(.select)
                            inputDigits = ""
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
    }
    
    private func handleDigit(_ digit: Int) {
        lightHaptic.impactOccurred()
        inputDigits.append("\(digit)")
        onDigit?(digit)
        if inputDigits.count > 4 {
            inputDigits = String(inputDigits.suffix(4))
        }
    }
    
    @ViewBuilder
    private func digitButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
        }
    }
    
    @ViewBuilder
    private func iptvActionButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            lightHaptic.impactOccurred()
            action()
        }) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .medium))
                Text(title)
                    .font(.system(size: 11, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color(UIColor.secondarySystemBackground))
            .foregroundColor(.primary)
            .cornerRadius(14)
        }
    }
}

private struct TowerButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? Color.accentColor.opacity(0.3) : Color(UIColor.tertiarySystemBackground))
            .foregroundColor(configuration.isPressed ? .accentColor : .primary)
            .cornerRadius(14)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
