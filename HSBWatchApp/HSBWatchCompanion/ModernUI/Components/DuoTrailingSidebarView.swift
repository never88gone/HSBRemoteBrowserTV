//
//  DuoTrailingSidebarView.swift
//  HSBWatchCompanion
//
//  Created for iPhone Duo Foldable Display Optimization.
//

import SwiftUI

/// 专为 iPhone Duo 折叠双屏展开态（宽屏）打造的右下方实体操作按钮组 (Action Keypad)
/// 遵循设计规范：
/// 1. 彻底去除整体浮层容器，直接呈现为界面底层的独立实体操作按键；
/// 2. 大幅放大图标（22~24pt）与清晰标签（11pt），一目了然看清功能；
/// 3. 严格控制在 5 个核心操作按钮以内（返回、轮盘、触控、多模扩展、打字键盘）；
/// 4. 按钮群上方带有独立精致的设备实时电池电量显示。
struct DuoTrailingSidebarView: View {
    @ObservedObject var coordinatorObserver: CoordinatorObservable
    @Binding var selectedMainTab: Int
    @Binding var selectedControlTab: Int
    @Binding var showingBrowserGuide: Bool
    @Binding var showingSystemGuide: Bool
    
    @StateObject private var batteryMonitor = DeviceBatteryMonitor()
    
    private let lightHaptic = UIImpactFeedbackGenerator(style: .light)
    
    var body: some View {
        VStack(spacing: 8) {
            // === 顶部：独立实时电池电量指示 (Battery Status Pill) ===
            HStack(spacing: 4) {
                Image(systemName: batteryMonitor.iconName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(batteryMonitor.tintColor)
                Text("\(batteryMonitor.batteryLevel)%")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(
                Capsule()
                    .fill(Color(UIColor.secondarySystemFill))
            )
            .padding(.bottom, 2)
            
            // === 核心操作按钮区：严格 5 个独立实体按键 ===
            
            // 按钮 1: 返回按钮 (Back Action Button)
            Button(action: {
                lightHaptic.impactOccurred()
                NotificationCenter.default.post(name: Notification.Name("HSBExitRemotePageNotification"), object: nil)
            }) {
                VStack(spacing: 3) {
                    Image(systemName: "chevron.backward")
                        .font(.system(size: 21, weight: .bold))
                    Text("返回")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                }
                .foregroundColor(.primary)
                .frame(width: 66, height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(UIColor.secondarySystemFill))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            // 按钮 2: 系统硬件轮盘模式 (D-Pad Action Button)
            actionKeyButton(
                icon: "dpad.fill",
                label: "轮盘",
                isSelected: (selectedMainTab == 0 && selectedControlTab == 0)
            ) {
                selectedMainTab = 0
                selectedControlTab = 0
            }
            
            // 按钮 3: 无线触控板模式 (Touchpad Action Button)
            actionKeyButton(
                icon: "hand.point.up.left.fill",
                label: "触控",
                isSelected: (selectedMainTab == 0 && selectedControlTab == 1)
            ) {
                selectedMainTab = 0
                selectedControlTab = 1
            }
            
            // 按钮 4: 扩展多模形态切换 (Multi-Mode Menu Button)
            Menu {
                Button(action: {
                    lightHaptic.impactOccurred()
                    selectedMainTab = 0
                    selectedControlTab = 2
                }) {
                    Label("IPTV 大屏频道", systemImage: "tv.inset.filled")
                }
                
                Button(action: {
                    lightHaptic.impactOccurred()
                    selectedMainTab = 0
                    selectedControlTab = 3
                }) {
                    Label("PDF 演示幻灯", systemImage: "doc.text.fill")
                }
                
                Button(action: {
                    lightHaptic.impactOccurred()
                    selectedMainTab = 1
                }) {
                    Label("大屏应用生态", systemImage: "square.grid.2x2.fill")
                }
            } label: {
                VStack(spacing: 3) {
                    Image(systemName: currentExtraModeIcon)
                        .font(.system(size: 22, weight: .semibold))
                    Text(currentExtraModeLabel)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                }
                .foregroundColor(isExtraModeActive ? .white : .primary)
                .frame(width: 66, height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isExtraModeActive ? Color.tanghuluAccentRed : Color(UIColor.secondarySystemFill))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            // 按钮 5: 打字键盘输入 (Keyboard Action Button)
            Button(action: {
                lightHaptic.impactOccurred()
                NotificationCenter.default.post(name: Notification.Name("HSBToggleRemoteKeyboardNotification"), object: nil)
            }) {
                VStack(spacing: 3) {
                    Image(systemName: "keyboard.fill")
                        .font(.system(size: 22, weight: .semibold))
                    Text("打字")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                }
                .foregroundColor(.primary)
                .frame(width: 66, height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(UIColor.secondarySystemFill))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
        // 注意：此处不再设置任何外层毛玻璃浮层背景、大边框或整体阴影，完全呈现为右下方独立的实体操作按钮组！
    }
    
    /// 独立实体操作按键
    private func actionKeyButton(icon: String, label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: {
            lightHaptic.impactOccurred()
            withAnimation(.easeInOut(duration: 0.2)) {
                action()
            }
        }) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: isSelected ? .bold : .semibold))
                Text(label)
                    .font(.system(size: 11, weight: isSelected ? .bold : .medium, design: .rounded))
            }
            .foregroundColor(isSelected ? .white : .primary)
            .frame(width: 66, height: 56)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.tanghuluAccentRed : Color(UIColor.secondarySystemFill))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
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
            return "ellipsis.circle.fill"
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

/// 实时设备电池电量监控器
private final class DeviceBatteryMonitor: ObservableObject {
    @Published var batteryLevel: Int = 100
    @Published var isCharging: Bool = false
    
    init() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        updateBattery()
        NotificationCenter.default.addObserver(self, selector: #selector(batteryChanged), name: UIDevice.batteryLevelDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(batteryChanged), name: UIDevice.batteryStateDidChangeNotification, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func batteryChanged() {
        DispatchQueue.main.async {
            self.updateBattery()
        }
    }
    
    private func updateBattery() {
        let raw = UIDevice.current.batteryLevel
        if raw < 0 {
            // 模拟器环境或未读取到时展示 100%
            self.batteryLevel = 100
        } else {
            self.batteryLevel = max(1, min(100, Int(raw * 100)))
        }
        let state = UIDevice.current.batteryState
        self.isCharging = (state == .charging || state == .full)
    }
    
    var iconName: String {
        if isCharging {
            return "battery.100percent.bolt"
        }
        if batteryLevel >= 90 {
            return "battery.100percent"
        } else if batteryLevel >= 65 {
            return "battery.75percent"
        } else if batteryLevel >= 35 {
            return "battery.50percent"
        } else if batteryLevel >= 15 {
            return "battery.25percent"
        } else {
            return "battery.0percent"
        }
    }
    
    var tintColor: Color {
        if isCharging {
            return .green
        }
        if batteryLevel <= 20 {
            return .red
        }
        return .primary
    }
}
