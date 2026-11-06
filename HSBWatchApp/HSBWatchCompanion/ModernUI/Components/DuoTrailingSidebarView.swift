//
//  DuoTrailingSidebarView.swift
//  HSBWatchCompanion
//
//  Created for iPhone Duo Foldable Display Optimization.
//

import SwiftUI

/// 专为 iPhone Duo 折叠双屏展开态（宽屏）打造的右侧垂直一体化悬浮控制侧边栏
/// 替换传统的屏幕顶部导航横条，将返回、大屏与系统双模状态、模式切换、打字与扫码置于右手拇指黄金操作热区
struct DuoTrailingSidebarView: View {
    @ObservedObject var coordinatorObserver: CoordinatorObservable
    @Binding var selectedMainTab: Int
    @Binding var selectedControlTab: Int
    @Binding var showingBrowserGuide: Bool
    @Binding var showingSystemGuide: Bool
    
    @State private var showingBrowserManageActionSheet: Bool = false
    private let lightHaptic = UIImpactFeedbackGenerator(style: .light)
    
    var body: some View {
        VStack(spacing: 10) {
            // 1. 顶部返回按钮 (带触感与呼吸高光)
            Button(action: {
                lightHaptic.impactOccurred()
                NotificationCenter.default.post(name: Notification.Name("HSBExitRemotePageNotification"), object: nil)
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.primary)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(Color(UIColor.secondarySystemBackground).opacity(0.85))
                    )
            }
            .buttonStyle(PlainButtonStyle())
            
            Divider()
                .frame(width: 32)
                .background(Color.white.opacity(0.18))
            
            // 2. 双通道连接状态指示 (大屏专线 + 系统原生通道)
            VStack(spacing: 8) {
                // 2.1 大屏连接通道指示灯 (糖葫芦浏览器)
                Button(action: {
                    lightHaptic.impactOccurred()
                    if coordinatorObserver.isHSBBrowserConnected {
                        showingBrowserManageActionSheet = true
                    } else {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showingBrowserGuide = true
                        }
                    }
                }) {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "tv")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(coordinatorObserver.isHSBBrowserConnected ? .primary : .secondary)
                            .frame(width: 44, height: 40)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(UIColor.secondarySystemBackground).opacity(0.85))
                            )
                        
                        Circle()
                            .fill(browserStatusColor)
                            .frame(width: 8, height: 8)
                            .offset(x: -3, y: 3)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .actionSheet(isPresented: $showingBrowserManageActionSheet) {
                    ActionSheet(
                        title: Text("大屏通道控制 (\(coordinatorObserver.browserDeviceName.isEmpty ? "糖葫芦浏览器" : coordinatorObserver.browserDeviceName))"),
                        message: Text("当前已建立 TLS 1.2 加密长连接专线 (端口 56789)，支持触控板滑动、双指滚动与 EPG 协同。"),
                        buttons: [
                            .default(Text("🔄 刷新与测试大屏通道")) {
                                lightHaptic.impactOccurred()
                                coordinatorObserver.refreshBrowserChannel()
                            },
                            .default(Text("📱 重新扫码配对新大屏")) {
                                lightHaptic.impactOccurred()
                                coordinatorObserver.forgetPairedBrowserAndRescan()
                            },
                            .destructive(Text("🚫 断开大屏连接")) {
                                lightHaptic.impactOccurred()
                                coordinatorObserver.disconnectBrowserChannel()
                            },
                            .cancel(Text("取消"))
                        ]
                    )
                }
                
                // 2.2 系统硬件原生通道指示灯 (Apple TV / Mac)
                Button(action: {
                    lightHaptic.impactOccurred()
                    withAnimation(.easeInOut(duration: 0.25)) {
                        showingSystemGuide = true
                    }
                }) {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: coordinatorObserver.isTargetMac ? "desktopcomputer" : "appletv")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(coordinatorObserver.isNativeConnected ? .primary : .secondary)
                            .frame(width: 44, height: 40)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(UIColor.secondarySystemBackground).opacity(0.85))
                            )
                        
                        Circle()
                            .fill(coordinatorObserver.isNativeConnected ? Color.green : Color.gray)
                            .frame(width: 8, height: 8)
                            .offset(x: -3, y: 3)
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            Divider()
                .frame(width: 32)
                .background(Color.white.opacity(0.18))
            
            // 3. 垂直微操模式快速切换 Toolstrip (系统、触控、IPTV、演讲、应用生态)
            VStack(spacing: 6) {
                sidebarModeItem(
                    icon: "dpad",
                    label: "系统",
                    isSelected: (selectedMainTab == 0 && selectedControlTab == 0)
                ) {
                    selectedMainTab = 0
                    selectedControlTab = 0
                }
                
                sidebarModeItem(
                    icon: "hand.point.up.left.and.text",
                    label: "触控",
                    isSelected: (selectedMainTab == 0 && selectedControlTab == 1)
                ) {
                    selectedMainTab = 0
                    selectedControlTab = 1
                }
                
                sidebarModeItem(
                    icon: "tv.inset.filled",
                    label: "IPTV",
                    isSelected: (selectedMainTab == 0 && selectedControlTab == 2)
                ) {
                    selectedMainTab = 0
                    selectedControlTab = 2
                }
                
                sidebarModeItem(
                    icon: "doc.text.fill",
                    label: "演讲",
                    isSelected: (selectedMainTab == 0 && selectedControlTab == 3)
                ) {
                    selectedMainTab = 0
                    selectedControlTab = 3
                }
                
                sidebarModeItem(
                    icon: "square.grid.2x2.fill",
                    label: "生态",
                    isSelected: (selectedMainTab == 1)
                ) {
                    selectedMainTab = 1
                }
            }
            
            Spacer(minLength: 6)
            
            // 4. 底部快捷工具 (扫码配对 + 键盘打字)
            VStack(spacing: 8) {
                // 扫码连接
                Button(action: {
                    lightHaptic.impactOccurred()
                    NotificationCenter.default.post(name: Notification.Name("HSBOpenQRCodeScannerNotification"), object: nil)
                }) {
                    Image(systemName: "qrcode.viewfinder")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.tanghuluBrandBlue)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(Color(UIColor.secondarySystemBackground).opacity(0.85))
                        )
                }
                .buttonStyle(PlainButtonStyle())
                
                // 键盘打字
                Button(action: {
                    lightHaptic.impactOccurred()
                    NotificationCenter.default.post(name: Notification.Name("HSBToggleRemoteKeyboardNotification"), object: nil)
                }) {
                    Image(systemName: "keyboard")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(Color(UIColor.secondarySystemBackground).opacity(0.85))
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(UIColor.tertiarySystemBackground).opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.35), radius: 10, x: -2, y: 4)
        )
        .frame(width: 60)
        .padding(.trailing, 10)
    }
    
    private func sidebarModeItem(icon: String, label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: {
            lightHaptic.impactOccurred()
            withAnimation(.easeInOut(duration: 0.2)) {
                action()
            }
        }) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: isSelected ? .bold : .medium))
                Text(label)
                    .font(.system(size: 9.5, weight: isSelected ? .bold : .regular, design: .rounded))
            }
            .foregroundColor(isSelected ? .white : .secondary)
            .frame(width: 46, height: 42)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.tanghuluAccentRed : Color.clear)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var browserStatusColor: Color {
        if coordinatorObserver.isTargetMac {
            return .gray
        } else if coordinatorObserver.isHSBBrowserConnected {
            return .green
        } else if coordinatorObserver.isHSBBrowserReconnecting {
            return .orange
        } else if coordinatorObserver.nearbyDiscoveredBrowserTV != nil {
            return .orange
        } else {
            return .gray
        }
    }
}
