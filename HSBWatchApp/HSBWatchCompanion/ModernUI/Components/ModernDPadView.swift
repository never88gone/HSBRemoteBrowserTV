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
    private let outerSize: CGFloat
    private let centerSize: CGFloat
    private let hitTargetSize: CGFloat = 48.0
    
    private var offsetDistance: CGFloat {
        return outerSize * 0.35
    }
    
    // 触觉反馈发生器
    private let lightHaptic = UIImpactFeedbackGenerator(style: .light)
    private let mediumHaptic = UIImpactFeedbackGenerator(style: .medium)
    
    // 按压高光状态
    @State private var pressedDirection: DPadDirection? = nil
    @State private var isCenterPressed: Bool = false
    
    public init(
        size: CGFloat = 260.0,
        onDirection: ((DPadDirection, KeyAction) -> Void)? = nil,
        onSelect: ((KeyAction) -> Void)? = nil
    ) {
        self.outerSize = size
        self.centerSize = size * 0.44
        self.onDirection = onDirection
        self.onSelect = onSelect
    }
    
    public var body: some View {
        ZStack {
            // 外盘圆环底座 (质感深色微渐变)
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color(UIColor.secondarySystemBackground),
                            Color(UIColor.secondarySystemBackground).opacity(0.8)
                        ]),
                        center: .center,
                        startRadius: 20,
                        endRadius: outerSize * 0.5
                    )
                )
                .frame(width: outerSize, height: outerSize)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.12), lineWidth: 1.5)
                )
                .shadow(color: Color.black.opacity(0.2), radius: 12, x: 0, y: 6)
            
            // 四向按压白色高光动效
            if let dir = pressedDirection {
                directionHighlight(for: dir)
            }
            
            // 四向视觉方向箭头与 48x48 扩展触控热区（符合 Apple HIG 规范）
            directionHitButton(direction: .up, offset: CGSize(width: 0, height: -offsetDistance))
            directionHitButton(direction: .down, offset: CGSize(width: 0, height: offsetDistance))
            directionHitButton(direction: .left, offset: CGSize(width: -offsetDistance, height: 0))
            directionHitButton(direction: .right, offset: CGSize(width: offsetDistance, height: 0))
            
            // 中心确认键
            Button(action: {}) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(UIColor.tertiarySystemBackground),
                                    Color(UIColor.secondarySystemBackground)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: centerSize, height: centerSize)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.15), radius: 6, x: 0, y: 3)
                    
                    if isCenterPressed {
                        Circle()
                            .fill(Color.white.opacity(HSBRemoteConstants.blinkOpacity))
                            .frame(width: centerSize, height: centerSize)
                    }
                    
                    Text("OK")
                        .font(.system(size: max(17, outerSize * 0.08), weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                }
                .scaleEffect(isCenterPressed ? 0.94 : 1.0)
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
                    endRadius: outerSize * 0.35
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
        let isPressed = (pressedDirection == direction)
        ZStack {
            // 精致 SF Symbol 方向指示图标 (取代单调小圆点)
            Image(systemName: chevronIcon(for: direction))
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(isPressed ? Color.accentColor : Color.primary.opacity(0.45))
                .scaleEffect(isPressed ? 1.25 : 1.0)
            
            // 48x48 扩展触控透明热区
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
    
    private func chevronIcon(for direction: DPadDirection) -> String {
        switch direction {
        case .up: return "chevron.up"
        case .down: return "chevron.down"
        case .left: return "chevron.left"
        case .right: return "chevron.right"
        }
    }
}
