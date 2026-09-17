//
//  ModernPDFControlView.swift
//  HSBWatchCompanion
//

import SwiftUI
import UIKit

public struct ModernPDFControlView: View {
    public var onPageChange: ((_ isNext: Bool) -> Void)?
    public var onJumpPage: ((_ isFirst: Bool) -> Void)?
    public var onDrawAction: ((_ type: String, _ point: CGPoint, _ color: String, _ width: CGFloat) -> Void)?
    public var onClear: (() -> Void)?
    public var onUndo: (() -> Void)?
    
    @State private var selectedColorKey: String = HSBRemoteDrawColorRed
    @State private var selectedWidth: CGFloat = 4.0
    @State private var isEraserActive: Bool = false
    @State private var isLaserPointerActive: Bool = false
    @State private var currentDrawingPath = Path()
    
    private let haptic = UIImpactFeedbackGenerator(style: .medium)
    private let lightHaptic = UIImpactFeedbackGenerator(style: .light)
    
    private let colorPalette: [(key: String, color: Color, name: String)] = [
        (HSBRemoteDrawColorRed, .red, "红"),
        (HSBRemoteDrawColorBlue, .tanghuluBrandBlue, "蓝"),
        (HSBRemoteDrawColorYellow, .yellow, "黄"),
        (HSBRemoteDrawColorGreen, .green, "绿"),
        (HSBRemoteDrawColorWhite, .white, "白")
    ]
    
    public init(
        onPageChange: ((_ isNext: Bool) -> Void)? = nil,
        onJumpPage: ((_ isFirst: Bool) -> Void)? = nil,
        onDrawAction: ((_ type: String, _ point: CGPoint, _ color: String, _ width: CGFloat) -> Void)? = nil,
        onClear: (() -> Void)? = nil,
        onUndo: (() -> Void)? = nil
    ) {
        self.onPageChange = onPageChange
        self.onJumpPage = onJumpPage
        self.onDrawAction = onDrawAction
        self.onClear = onClear
        self.onUndo = onUndo
    }
    
    public var body: some View {
        VStack(spacing: 16) {
            // 1. 商务翻页双子大键
            HStack(spacing: 16) {
                Button {
                    haptic.impactOccurred()
                    onPageChange?(false)
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "arrow.left.circle.fill")
                            .font(.system(size: 32, weight: .semibold))
                        Text("上一页")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .buttonStyle(PresentationButtonStyle(backgroundColor: Color.tanghuluBrandBlue.opacity(0.15)))
                
                Button {
                    haptic.impactOccurred()
                    onPageChange?(true)
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 32, weight: .semibold))
                        Text("下一页")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .buttonStyle(PresentationButtonStyle(backgroundColor: Color.accentColor.opacity(0.2)))
            }
            .frame(height: 120)
            .padding(.horizontal, 16)
            
            // 2. 页面快速导航 (首页 / 尾页)
            HStack(spacing: 12) {
                quickNavButton(title: "跳转首页", icon: "backward.end.fill") {
                    onJumpPage?(true)
                }
                quickNavButton(title: "撤销标注", icon: "arrow.uturn.backward") {
                    onUndo?()
                }
                quickNavButton(title: "清空画布", icon: "trash.fill") {
                    onClear?()
                }
                quickNavButton(title: "跳转尾页", icon: "forward.end.fill") {
                    onJumpPage?(false)
                }
            }
            .padding(.horizontal, 16)
            
            // 3. 激光笔与画板触控区域
            VStack(spacing: 10) {
                HStack {
                    Image(systemName: "pencil.and.scribble")
                        .foregroundColor(.accentColor)
                    Text("屏幕激光笔与涂鸦板")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                    Spacer()
                    
                    // 颜色选择圆点
                    HStack(spacing: 8) {
                        ForEach(colorPalette, id: \.key) { item in
                            Circle()
                                .fill(item.color)
                                .frame(width: 22, height: 22)
                                .overlay(
                                    Circle()
                                        .stroke(Color.primary, lineWidth: selectedColorKey == item.key && !isEraserActive ? 2 : 0)
                                )
                                .onTapGesture {
                                    lightHaptic.impactOccurred()
                                    selectedColorKey = item.key
                                    isEraserActive = false
                                }
                        }
                    }
                }
                .padding(.horizontal, 16)
                
                // 涂鸦手势画板
                GeometryReader { geo in
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(UIColor.secondarySystemBackground))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                            )
                        
                        VStack {
                            Image(systemName: "hand.draw.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.secondary.opacity(0.4))
                            Text("在区域内滑动实时在大屏上标注或聚光")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary.opacity(0.6))
                        }
                    }
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let normalizedX = value.location.x / geo.size.width
                                let normalizedY = value.location.y / geo.size.height
                                let normPt = CGPoint(x: normalizedX, y: normalizedY)
                                onDrawAction?(HSBRemoteDrawTypeMoved, normPt, selectedColorKey, selectedWidth)
                            }
                            .onEnded { value in
                                let normalizedX = value.location.x / geo.size.width
                                let normalizedY = value.location.y / geo.size.height
                                let normPt = CGPoint(x: normalizedX, y: normalizedY)
                                onDrawAction?(HSBRemoteDrawTypeEnded, normPt, selectedColorKey, selectedWidth)
                            }
                    )
                }
                .frame(maxHeight: .infinity)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
        }
    }
    
    @ViewBuilder
    private func quickNavButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            lightHaptic.impactOccurred()
            action()
        }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .medium))
                Text(title)
                    .font(.system(size: 11, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color(UIColor.secondarySystemBackground))
            .foregroundColor(.primary)
            .cornerRadius(12)
        }
    }
}

private struct PresentationButtonStyle: ButtonStyle {
    var backgroundColor: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? backgroundColor.opacity(0.8) : backgroundColor)
            .foregroundColor(.primary)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
