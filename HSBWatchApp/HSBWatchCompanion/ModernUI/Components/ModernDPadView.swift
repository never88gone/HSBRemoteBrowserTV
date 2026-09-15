//
//  ModernDPadView.swift
//  HSBWatchCompanion
//

import SwiftUI
import UIKit

public struct ModernDPadView: View {
    public var onDirection: ((DPadDirection, KeyAction) -> Void)?
    public var onSelect: ((KeyAction) -> Void)?
    
    // 布局常量
    private let outerSize: CGFloat = HSBRemoteConstants.dpadOuterSize       // 150pt
    private let centerSize: CGFloat = HSBRemoteConstants.dpadCenterSize     // 75pt
    private let visualDotSize: CGFloat = HSBRemoteConstants.visualDotSize   // 5pt
    private let hitTargetSize: CGFloat = HSBRemoteConstants.hitTargetSize   // 30pt
    
    // 触觉反馈发生器
    private let lightHaptic = UIImpactFeedbackGenerator(style: .light)
    private let mediumHaptic = UIImpactFeedbackGenerator(style: .medium)
    
    // 按压高光状态
    @State private var pressedDirection: DPadDirection? = nil
    @State private var isCenterPressed: Bool = false
    
    public init(
        onDirection: ((DPadDirection, KeyAction) -> Void)? = nil,
        onSelect: ((KeyAction) -> Void)? = nil
    ) {
        self.onDirection = onDirection
        self.onSelect = onSelect
    }
    
    public var body: some View {
        ZStack {
            // 外盘圆环底座
            Circle()
                .fill(Color(UIColor.secondarySystemBackground).opacity(0.85))
                .frame(width: outerSize, height: outerSize)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.12), lineWidth: 1.5)
                )
                .shadow(color: Color.black.opacity(0.18), radius: 10, x: 0, y: 5)
            
            // 四向按压白色高光动效 (25% 不透明度)
            if let dir = pressedDirection {
                directionHighlight(for: dir)
            }
            
            // 四向视觉圆点与 30x30 扩展触控热区
            directionHitButton(direction: .up, offset: CGSize(width: 0, height: -46))
            directionHitButton(direction: .down, offset: CGSize(width: 0, height: 46))
            directionHitButton(direction: .left, offset: CGSize(width: -46, height: 0))
            directionHitButton(direction: .right, offset: CGSize(width: 46, height: 0))
            
            // 中心确认键 (75pt, 精准 50% 比例)
            Button(action: {}) {
                ZStack {
                    Circle()
                        .fill(Color(UIColor.tertiarySystemBackground))
                        .frame(width: centerSize, height: centerSize)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.12), radius: 4, x: 0, y: 2)
                    
                    if isCenterPressed {
                        Circle()
                            .fill(Color.white.opacity(HSBRemoteConstants.blinkOpacity))
                            .frame(width: centerSize, height: centerSize)
                    }
                    
                    Text("OK")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                }
            }
            .buttonStyle(PlainButtonStyle())
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isCenterPressed {
                            isCenterPressed = true
                            mediumHaptic.prepare()
                            mediumHaptic.impactOccurred()
                            onSelect?(.press)
                        }
                    }
                    .onEnded { _ in
                        withAnimation(.easeOut(duration: HSBRemoteConstants.blinkDuration)) {
                            isCenterPressed = false
                        }
                        onSelect?(.release)
                        onSelect?(.tap)
                    }
            )
        }
        .frame(width: outerSize, height: outerSize)
    }
    
    @ViewBuilder
    private func directionHighlight(for direction: DPadDirection) -> some View {
        Circle()
            .fill(
                RadialGradient(
                    gradient: Gradient(colors: [Color.white.opacity(HSBRemoteConstants.blinkOpacity), Color.clear]),
                    center: highlightCenter(for: direction),
                    startRadius: 5,
                    endRadius: 50
                )
            )
            .frame(width: outerSize, height: outerSize)
            .transition(.opacity)
    }
    
    private func highlightCenter(for direction: DPadDirection) -> UnitPoint {
        switch direction {
        case .up: return .top
        case .down: return .bottom
        case .left: return .leading
        case .right: return .trailing
        }
    }
    
    @ViewBuilder
    private func directionHitButton(direction: DPadDirection, offset: CGSize) -> some View {
        ZStack {
            // 5x5 视觉指示器
            Circle()
                .fill(Color.primary.opacity(0.55))
                .frame(width: visualDotSize, height: visualDotSize)
            
            // 30x30 扩展触控透明热区
            Color.clear
                .frame(width: hitTargetSize, height: hitTargetSize)
                .contentShape(Rectangle())
        }
        .offset(offset)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if pressedDirection != direction {
                        pressedDirection = direction
                        lightHaptic.prepare()
                        lightHaptic.impactOccurred()
                        onDirection?(direction, .press)
                    }
                }
                .onEnded { _ in
                    withAnimation(.easeOut(duration: HSBRemoteConstants.blinkDuration)) {
                        pressedDirection = nil
                    }
                    onDirection?(direction, .release)
                    onDirection?(direction, .tap)
                }
        )
    }
}
