//
//  DuoTrailingSidebarView.swift
//  HSBWatchCompanion
//
//  Created for iPhone Duo Foldable Display Optimization.
//

import SwiftUI

/// 专为 iPhone Duo 折叠双屏展开态（宽屏）打造的右下方实体操作按键组 (Action Keypad)
/// 严格遵循最新用户规范：
/// 1. 不带电池显示；
/// 2. 不带返回按钮；
/// 3. 彻底去除浮层外壳，直接呈现为界面底层的独立实体操作按键；
/// 4. 深度优化按键视觉质感：
///    - 未选中：精密深邃双层物理微渐变底座 + 金属漫反射微光 + 顶部倒角高光边 + 立体微阴影；
///    - 选中：奢华朱砂红/极光红宝石立体渐变 + 晶莹发光边框 + 专属极光红环境氛围光晕 (Ambient Glow) + 高亮立体纯白大图标；
/// 5. 图标放大至 23~24pt，文字 11.5pt，功能一目了然。
struct DuoTrailingSidebarView: View {
    @ObservedObject var coordinatorObserver: CoordinatorObservable
    @Binding var selectedMainTab: Int
    @Binding var selectedControlTab: Int
    @Binding var showingBrowserGuide: Bool
    @Binding var showingSystemGuide: Bool
    
    private let mediumHaptic = UIImpactFeedbackGenerator(style: .medium)
    private let lightHaptic = UIImpactFeedbackGenerator(style: .light)
    
    var body: some View {
        VStack(spacing: 12) {
            // === 核心实体操作按键区 (共 4 个，严格不超过 5 个) ===
            
            // 实体按键 1: 轮盘遥控模式 (D-Pad Action Key)
            actionKeyButton(
                icon: "dpad.fill",
                label: "轮盘",
                isSelected: (selectedMainTab == 0 && selectedControlTab == 0)
            ) {
                selectedMainTab = 0
                selectedControlTab = 0
            }
            
            // 实体按键 2: 无线触控板模式 (Touchpad Action Key)
            actionKeyButton(
                icon: "hand.point.up.left.fill",
                label: "触控",
                isSelected: (selectedMainTab == 0 && selectedControlTab == 1)
            ) {
                selectedMainTab = 0
                selectedControlTab = 1
            }
            
            // 实体按键 3: 扩展多模形态切换 (Multi-Mode Menu Key)
            Menu {
                Button(action: {
                    mediumHaptic.impactOccurred()
                    selectedMainTab = 0
                    selectedControlTab = 2
                }) {
                    Label("IPTV 大屏频道", systemImage: "tv.inset.filled")
                }
                
                Button(action: {
                    mediumHaptic.impactOccurred()
                    selectedMainTab = 0
                    selectedControlTab = 3
                }) {
                    Label("PDF 演示幻灯", systemImage: "doc.text.fill")
                }
                
                Button(action: {
                    mediumHaptic.impactOccurred()
                    selectedMainTab = 1
                }) {
                    Label("大屏应用生态", systemImage: "square.grid.2x2.fill")
                }
            } label: {
                actionKeyContent(
                    icon: currentExtraModeIcon,
                    label: currentExtraModeLabel,
                    isSelected: isExtraModeActive
                )
            }
            .buttonStyle(DuoPhysicalKeyStyle(isSelected: isExtraModeActive))
            
            // 实体按键 4: 打字键盘输入 (Keyboard Action Key)
            Button(action: {
                mediumHaptic.impactOccurred()
                NotificationCenter.default.post(name: Notification.Name("HSBToggleRemoteKeyboardNotification"), object: nil)
            }) {
                actionKeyContent(
                    icon: "keyboard.fill",
                    label: "打字",
                    isSelected: false
                )
            }
            .buttonStyle(DuoPhysicalKeyStyle(isSelected: false))
        }
        // 完全不设置任何外层浮层背景、阴影或药丸卡片边框
    }
    
    /// 独立实体操作按键组件
    private func actionKeyButton(icon: String, label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: {
            mediumHaptic.impactOccurred()
            withAnimation(.easeInOut(duration: 0.22)) {
                action()
            }
        }) {
            actionKeyContent(icon: icon, label: label, isSelected: isSelected)
        }
        .buttonStyle(DuoPhysicalKeyStyle(isSelected: isSelected))
    }
    
    /// 实体按键内容视图 (大图标 + 语义清晰文案 + 极致考究的选中/未选中质感渲染)
    private func actionKeyContent(icon: String, label: String, isSelected: Bool) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 23, weight: isSelected ? .bold : .semibold))
                .foregroundColor(isSelected ? .white : Color(white: 0.90))
            
            Text(label)
                .font(.system(size: 11.5, weight: isSelected ? .bold : .medium, design: .rounded))
                .foregroundColor(isSelected ? .white : Color(white: 0.82))
        }
        .frame(width: 70, height: 62)
        .background(
            ZStack {
                if isSelected {
                    // === 选中态：奢华极光红宝石立体渐变 + 晶莹高光 + 环境氛围光晕 ===
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 248/255, green: 62/255, blue: 80/255),
                            Color(red: 224/255, green: 36/255, blue: 56/255),
                            Color(red: 192/255, green: 20/255, blue: 38/255)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    
                    // 顶部反光倒角
                    LinearGradient(
                        gradient: Gradient(colors: [Color.white.opacity(0.42), Color.clear]),
                        startPoint: .top,
                        endPoint: .center
                    )
                } else {
                    // === 未选中态：精密深邃双层物理微渐变底座 + 金属漫反射 ===
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(white: 0.22).opacity(0.92),
                            Color(white: 0.14).opacity(0.96)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    
                    // 顶部微弱漫反射光
                    LinearGradient(
                        gradient: Gradient(colors: [Color.white.opacity(0.09), Color.clear]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            // 精巧边缘高光描边 (选中晶莹亮边，未选中微光亚克力边)
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(
                    isSelected
                        ? LinearGradient(
                            colors: [Color.white.opacity(0.65), Color.white.opacity(0.18)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        : LinearGradient(
                            colors: [Color.white.opacity(0.20), Color.white.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                    lineWidth: isSelected ? 1.2 : 1.0
                )
        )
        .shadow(
            color: isSelected
                ? Color.tanghuluAccentRed.opacity(0.55)
                : Color.black.opacity(0.38),
            radius: isSelected ? 10 : 6,
            x: 0,
            y: isSelected ? 4 : 3
        )
    }
    
    private var isExtraModeActive: Bool {
        return selectedMainTab == 1 || (selectedMainTab == 0 && selectedControlTab >= 2)
    }
    
    private var currentExtraModeIcon: String {
        if selectedMainTab == 1 {
            return "square.grid.2x2.fill"
        } else if selectedControlTab == 2 {
            return "tv.inset.filled"
        } else if selectedControlTab == 3 {
            return "doc.text.fill"
        } else {
            return "square.grid.2x2.fill"
        }
    }
    
    private var currentExtraModeLabel: String {
        if selectedMainTab == 1 {
            return "生态"
        } else if selectedControlTab == 2 {
            return "IPTV"
        } else if selectedControlTab == 3 {
            return "演讲"
        } else {
            return "扩展"
        }
    }
}

/// 带有物理微弹按下深度的按键交互样式
private struct DuoPhysicalKeyStyle: ButtonStyle {
    let isSelected: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .opacity(configuration.isPressed ? 0.88 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.65), value: configuration.isPressed)
    }
}
