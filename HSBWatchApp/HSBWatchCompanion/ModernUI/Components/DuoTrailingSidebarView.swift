//
//  DuoTrailingSidebarView.swift
//  HSBWatchCompanion
//
//  Created for iPhone Duo Foldable Display Optimization.
//

import SwiftUI

/// 专为 iPhone Duo 折叠双屏展开态（宽屏）打造的右下方扁平化纯操作按钮组 (Flat Action Controls)
/// 遵循设计规范：
/// 1. 彻底去除背景框与浮层外壳，无底色无描边无阴影；
/// 2. 状态切换通过图标与文字的颜色变化来表达（选中时为品牌鲜明朱砂红，未选中为次级浅银灰）；
/// 3. 图标大而清晰（26pt），下方文字字号放大（13pt 加粗），文字绝不截断或省略，功能一目了然；
/// 4. 严格保留 4 个核心直观扁平操作按钮（轮盘、触控、多模扩展、打字），无电池显示、无返回按钮。
struct DuoTrailingSidebarView: View {
    @ObservedObject var coordinatorObserver: CoordinatorObservable
    @Binding var selectedMainTab: Int
    @Binding var selectedControlTab: Int
    @Binding var showingBrowserGuide: Bool
    @Binding var showingSystemGuide: Bool
    
    private let lightHaptic = UIImpactFeedbackGenerator(style: .light)
    
    var body: some View {
        VStack(spacing: 22) {
            // 按钮 1: 轮盘遥控模式 (D-Pad)
            flatActionButton(
                icon: (selectedMainTab == 0 && selectedControlTab == 0) ? "dpad.fill" : "dpad",
                label: "轮盘",
                isSelected: (selectedMainTab == 0 && selectedControlTab == 0)
            ) {
                selectedMainTab = 0
                selectedControlTab = 0
            }
            
            // 按钮 2: 无线触控板模式 (Touchpad)
            flatActionButton(
                icon: (selectedMainTab == 0 && selectedControlTab == 1) ? "hand.point.up.left.fill" : "hand.point.up.left",
                label: "触控",
                isSelected: (selectedMainTab == 0 && selectedControlTab == 1)
            ) {
                selectedMainTab = 0
                selectedControlTab = 1
            }
            
            // 按钮 3: 扩展多模形态切换 (IPTV / 演讲 / 生态 菜单)
            Menu {
                Button(action: {
                    lightHaptic.impactOccurred()
                    selectedMainTab = 0
                    selectedControlTab = 2
                }) {
                    Label("IPTV 大屏频道", systemImage: "tv")
                }
                
                Button(action: {
                    lightHaptic.impactOccurred()
                    selectedMainTab = 0
                    selectedControlTab = 3
                }) {
                    Label("PDF 演示幻灯", systemImage: "doc.text")
                }
                
                Button(action: {
                    lightHaptic.impactOccurred()
                    selectedMainTab = 1
                }) {
                    Label("大屏应用生态", systemImage: "square.grid.2x2")
                }
            } label: {
                flatButtonContent(
                    icon: currentExtraModeIcon,
                    label: currentExtraModeLabel,
                    isSelected: isExtraModeActive
                )
            }
            .buttonStyle(FlatPressButtonStyle())
            
            // 按钮 4: 打字键盘输入 (Keyboard)
            Button(action: {
                lightHaptic.impactOccurred()
                NotificationCenter.default.post(name: Notification.Name("HSBToggleRemoteKeyboardNotification"), object: nil)
            }) {
                flatButtonContent(
                    icon: "keyboard",
                    label: "打字",
                    isSelected: false
                )
            }
            .buttonStyle(FlatPressButtonStyle())
        }
        // 完全不设置任何背景、边框或阴影
    }
    
    /// 独立扁平操作按钮
    private func flatActionButton(icon: String, label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: {
            lightHaptic.impactOccurred()
            withAnimation(.easeInOut(duration: 0.18)) {
                action()
            }
        }) {
            flatButtonContent(icon: icon, label: label, isSelected: isSelected)
        }
        .buttonStyle(FlatPressButtonStyle())
    }
    
    /// 纯扁平内容视图：大图标 + 清晰大文字（绝不压缩截断为点），无背景框
    private func flatButtonContent(icon: String, label: String, isSelected: Bool) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 26, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? Color.tanghuluAccentRed : Color.secondary)
            
            Text(label)
                .font(.system(size: 13, weight: isSelected ? .bold : .medium, design: .rounded))
                .foregroundColor(isSelected ? Color.tanghuluAccentRed : Color.secondary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .frame(width: 66, height: 58)
        .contentShape(Rectangle()) // 充足热区
    }
    
    private var isExtraModeActive: Bool {
        return selectedMainTab == 1 || (selectedMainTab == 0 && selectedControlTab >= 2)
    }
    
    private var currentExtraModeIcon: String {
        if selectedMainTab == 1 {
            return isExtraModeActive ? "square.grid.2x2.fill" : "square.grid.2x2"
        } else if selectedControlTab == 2 {
            return isExtraModeActive ? "tv.inset.filled" : "tv"
        } else if selectedControlTab == 3 {
            return isExtraModeActive ? "doc.text.fill" : "doc.text"
        } else {
            return "square.grid.2x2"
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

/// 扁平化按键点击反馈样式
private struct FlatPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.45 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}
