//
//  ModernRemoteStatusTopBar.swift
//  HSBWatchCompanion
//

import SwiftUI

struct ModernRemoteStatusTopBar: View {
    @ObservedObject var coordinatorObserver: CoordinatorObservable
    @Binding var showingBrowserGuide: Bool
    @Binding var showingSystemGuide: Bool
    private let lightHaptic = UIImpactFeedbackGenerator(style: .light)
    
    init(
        coordinatorObserver: CoordinatorObservable,
        showingBrowserGuide: Binding<Bool>,
        showingSystemGuide: Binding<Bool>
    ) {
        self.coordinatorObserver = coordinatorObserver
        self._showingBrowserGuide = showingBrowserGuide
        self._showingSystemGuide = showingSystemGuide
    }
    
    public var body: some View {
        HStack(spacing: 8) {
            Spacer()
            
            // 1.1 大屏通道状态 (糖葫芦浏览器/专有控制/双指滚动/高级菜单)
            Button(action: {
                lightHaptic.impactOccurred()
                withAnimation(.easeInOut(duration: 0.25)) {
                    showingBrowserGuide = true
                }
            }) {
                HStack(spacing: 5) {
                    Circle()
                        .fill(browserStatusColor)
                        .frame(width: 6, height: 6)
                    Text(browserStatusText)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(coordinatorObserver.isHSBBrowserConnected ? .primary : .secondary)
                }
                .padding(.vertical, 5)
                .padding(.horizontal, 10)
                .background(
                    Capsule()
                        .fill(Color(UIColor.secondarySystemBackground).opacity(0.85))
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            // 1.2 Apple TV 系统原生通道状态 (Home/电源/全局控制)
            Button(action: {
                lightHaptic.impactOccurred()
                withAnimation(.easeInOut(duration: 0.25)) {
                    showingSystemGuide = true
                }
            }) {
                HStack(spacing: 5) {
                    Circle()
                        .fill(systemStatusColor)
                        .frame(width: 6, height: 6)
                    Text(systemStatusText)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(coordinatorObserver.isNativeConnected ? .primary : .secondary)
                }
                .padding(.vertical, 5)
                .padding(.horizontal, 10)
                .background(
                    Capsule()
                        .fill(Color(UIColor.secondarySystemBackground).opacity(0.85))
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }
    
    // MARK: - Dual Channel Status Displays (大屏通道 & 系统原生通道)
    private var browserStatusColor: Color {
        if coordinatorObserver.isTargetMac || coordinatorObserver.isHSBBrowserConnected {
            return .tanghuluBrandBlue
        } else {
            return .gray
        }
    }
    
    private var browserStatusText: String {
        if coordinatorObserver.isTargetMac {
            return "大屏: 已连接"
        }
        if coordinatorObserver.isHSBBrowserConnected {
            let name = coordinatorObserver.browserDeviceName.isEmpty ? "已连接" : coordinatorObserver.browserDeviceName
            return "大屏: \(name)"
        } else {
            return "大屏: 未连接"
        }
    }
    
    private var systemStatusColor: Color {
        if coordinatorObserver.isTargetMac || coordinatorObserver.isNativeConnected {
            return .tanghuluBrandBlue
        }
        if coordinatorObserver.isHSBBrowserConnected {
            return .tanghuluBrandBlue.opacity(0.8)
        }
        switch coordinatorObserver.state {
        case .ready: return .tanghuluBrandBlue
        case .connecting, .pairing: return .orange
        case .scanning: return .tanghuluBrandBlue
        case .failed: return .orange
        case .disconnected: return .gray
        }
    }
    
    private var systemStatusText: String {
        if coordinatorObserver.isTargetMac {
            return "系统: 已连接"
        }
        if coordinatorObserver.isNativeConnected {
            return "系统: 已连接"
        }
        if coordinatorObserver.isHSBBrowserConnected {
            return "系统: 协同就绪"
        }
        switch coordinatorObserver.state {
        case .ready(let name, _):
            return "系统: \(name)"
        case .connecting:
            return "系统: 连接中..."
        case .pairing:
            return "系统: 配对中..."
        case .scanning:
            return "系统: 扫描中..."
        case .failed(let err):
            if err.contains("待机") {
                return "系统: 待机唤醒"
            }
            return "系统: 未连接"
        case .disconnected:
            return "系统: 未连接"
        }
    }
}
