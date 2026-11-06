//
//  DuoTrailingSidebarView.swift
//  HSBWatchCompanion
//
//  Created for iPhone Duo Foldable Display Optimization.
//

import SwiftUI

/// 专为 iPhone Duo 折叠双屏展开态（宽屏）打造的右下方垂直悬浮操控侧边栏
/// 遵循严格约束：
/// 1. 位于右下方，吻合右手大拇指黄金热区；
/// 2. 顶部带有精致设备实时电池电量显示；
/// 3. 按钮总数严格控制在 5 个以内（返回、系统轮盘、触控板、扩展形态、打字键盘）。
struct DuoTrailingSidebarView: View {
    @ObservedObject var coordinatorObserver: CoordinatorObservable
    @Binding var selectedMainTab: Int
    @Binding var selectedControlTab: Int
    @Binding var showingBrowserGuide: Bool
    @Binding var showingSystemGuide: Bool
    
    @StateObject private var batteryMonitor = DeviceBatteryMonitor()
    @State private var showingModePickerMenu: Bool = false
    
    private let lightHaptic = UIImpactFeedbackGenerator(style: .light)
    
    var body: some View {
        VStack(spacing: 8) {
            // === 顶部：实时电池电量显示 (Battery Display) ===
            VStack(spacing: 2) {
                Image(systemName: batteryMonitor.iconName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(batteryMonitor.tintColor)
                Text("\(batteryMonitor.batteryLevel)%")
                    .font(.system(size: 8.5, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 5)
            .padding(.horizontal, 6)
            .background(
                Capsule()
                    .fill(Color(UIColor.secondarySystemBackground).opacity(0.85))
            )
            .padding(.top, 4)
            
            Divider()
                .frame(width: 28)
                .background(Color.white.opacity(0.18))
            
            // === 核心按钮区：严格 5 个按钮 ===
            
            // 按钮 1: 返回按钮 (Back)
            Button(action: {
                lightHaptic.impactOccurred()
                NotificationCenter.default.post(name: Notification.Name("HSBExitRemotePageNotification"), object: nil)
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.primary)
                    .frame(width: 44, height: 42)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(UIColor.secondarySystemBackground).opacity(0.85))
                    )
            }
            .buttonStyle(PlainButtonStyle())
            
            // 按钮 2: 系统轮盘模式 (System D-Pad)
            sidebarButton(
                icon: "dpad",
                label: "轮盘",
                isSelected: (selectedMainTab == 0 && selectedControlTab == 0)
            ) {
                selectedMainTab = 0
                selectedControlTab = 0
            }
            
            // 按钮 3: 无线触控板模式 (Touchpad)
            sidebarButton(
                icon: "hand.point.up.left.and.text",
                label: "触控",
                isSelected: (selectedMainTab == 0 && selectedControlTab == 1)
            ) {
                selectedMainTab = 0
                selectedControlTab = 1
            }
            
            // 按钮 4: 扩展多模形态 (IPTV / 演讲 / 应用生态 切换)
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
                VStack(spacing: 2) {
                    Image(systemName: currentExtraModeIcon)
                        .font(.system(size: 13, weight: isExtraModeActive ? .bold : .medium))
                    Text(currentExtraModeLabel)
                        .font(.system(size: 9, weight: isExtraModeActive ? .bold : .regular, design: .rounded))
                }
                .foregroundColor(isExtraModeActive ? .white : .secondary)
                .frame(width: 44, height: 42)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isExtraModeActive ? Color.tanghuluAccentRed : Color(UIColor.secondarySystemBackground).opacity(0.85))
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            // 按钮 5: 打字键盘输入 (Keyboard)
            Button(action: {
                lightHaptic.impactOccurred()
                NotificationCenter.default.post(name: Notification.Name("HSBToggleRemoteKeyboardNotification"), object: nil)
            }) {
                Image(systemName: "keyboard")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                    .frame(width: 44, height: 42)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(UIColor.secondarySystemBackground).opacity(0.85))
                    )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color(UIColor.tertiarySystemBackground).opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.35), radius: 10, x: -2, y: 4)
        )
        .frame(width: 58)
    }
    
    private func sidebarButton(icon: String, label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: {
            lightHaptic.impactOccurred()
            withAnimation(.easeInOut(duration: 0.2)) {
                action()
            }
        }) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                Text(label)
                    .font(.system(size: 9, weight: isSelected ? .bold : .regular, design: .rounded))
            }
            .foregroundColor(isSelected ? .white : .secondary)
            .frame(width: 44, height: 42)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.tanghuluAccentRed : Color.clear)
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
            return "ellipsis.circle"
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
            return "更多"
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
            // 模拟器环境或未读取到时，优雅展示 100%
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
