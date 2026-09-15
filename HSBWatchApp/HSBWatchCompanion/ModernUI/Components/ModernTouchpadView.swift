//
//  ModernTouchpadView.swift
//  HSBWatchCompanion
//

import SwiftUI
import UIKit

public struct ModernTouchpadView: View {
    public var onPan: ((CGFloat, CGFloat) -> Void)?
    public var onTap: ((Int, CGPoint?) -> Void)?
    public var onScroll: ((CGFloat, CGFloat) -> Void)?
    public var onDrag: ((DragState, CGFloat, CGFloat) -> Void)?
    public var onZoom: ((CGFloat) -> Void)?
    
    // 虚拟 1000x1000 空间坐标
    @State private var virtualX: CGFloat = 500.0
    @State private var virtualY: CGFloat = 500.0
    
    // 惯性滑动状态
    @State private var velocityX: CGFloat = 0.0
    @State private var velocityY: CGFloat = 0.0
    @State private var inertiaTimer: Timer? = nil
    @State private var lastDragLocation: CGPoint? = nil
    @State private var lastDragTime: Date = Date()
    @State private var isTouching: Bool = false
    
    // 缩放手势状态
    @State private var currentMagnification: CGFloat = 1.0
    
    private let lightHaptic = UIImpactFeedbackGenerator(style: .light)
    
    public init(
        onPan: ((CGFloat, CGFloat) -> Void)? = nil,
        onTap: ((Int, CGPoint?) -> Void)? = nil,
        onScroll: ((CGFloat, CGFloat) -> Void)? = nil,
        onDrag: ((DragState, CGFloat, CGFloat) -> Void)? = nil,
        onZoom: ((CGFloat) -> Void)? = nil
    ) {
        self.onPan = onPan
        self.onTap = onTap
        self.onScroll = onScroll
        self.onDrag = onDrag
        self.onZoom = onZoom
    }
    
    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 触控板背景底盘
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(UIColor.secondarySystemBackground),
                                Color(UIColor.tertiarySystemBackground)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1.5)
                    )
                    .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 6)
                
                // 触控微操视觉参考线与提示
                VStack(spacing: 8) {
                    Image(systemName: "cursorarrow.motionlines")
                        .font(.system(size: 28, weight: .light))
                        .foregroundColor(Color.primary.opacity(0.35))
                    Text(isTouching ? "触控微操中" : "单指滑动光标 · 双指滚动页面")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(Color.primary.opacity(0.4))
                }
                
                // 触控点动态指示器
                if isTouching, let loc = lastDragLocation {
                    Circle()
                        .fill(Color.accentColor.opacity(0.35))
                        .frame(width: 36, height: 36)
                        .position(loc)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .contentShape(Rectangle())
            .gesture(
                // 拖拽手势
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        stopInertia()
                        
                        let now = Date()
                        let dt = max(now.timeIntervalSince(lastDragTime), 0.008)
                        
                        if let lastLoc = lastDragLocation {
                            let dx = value.location.x - lastLoc.x
                            let dy = value.location.y - lastLoc.y
                            
                            // 更新速度
                            velocityX = dx / CGFloat(dt)
                            velocityY = dy / CGFloat(dt)
                            
                            // 虚拟 1000x1000 空间累加与自动重置
                            virtualX += dx
                            virtualY += dy
                            if virtualX < 0 || virtualX > 1000 || virtualY < 0 || virtualY > 1000 {
                                // 触碰虚拟边界触发瞬移重置
                                virtualX = 500.0
                                virtualY = 500.0
                            }
                            
                            onPan?(dx, dy)
                        } else {
                            isTouching = true
                            lightHaptic.prepare()
                        }
                        
                        lastDragLocation = value.location
                        lastDragTime = now
                    }
                    .onEnded { value in
                        isTouching = false
                        let distance = hypot(value.translation.width, value.translation.height)
                        
                        if distance < 4.0 {
                            // 轻点触发单击
                            lightHaptic.impactOccurred()
                            onTap?(1, value.location)
                        } else {
                            // 抬手触发 8 阶二次缓出惯性滑动
                            startQuadEaseOutInertia()
                        }
                        
                        lastDragLocation = nil
                    }
            )
            .simultaneousGesture(
                // 双指捏合缩放手势
                MagnificationGesture()
                    .onChanged { scale in
                        let delta = scale / currentMagnification
                        currentMagnification = scale
                        onZoom?(delta)
                    }
                    .onEnded { _ in
                        currentMagnification = 1.0
                    }
            )
        }
    }
    
    // MARK: - 8 阶二次缓出惯性滑动算法 (Quad Ease-Out Glide)
    private func startQuadEaseOutInertia() {
        stopInertia()
        
        var step = 0
        let totalSteps = 8
        var currentVx = velocityX * 0.4
        var currentVy = velocityY * 0.4
        
        inertiaTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { timer in
            step += 1
            if step > totalSteps || (abs(currentVx) < 1.0 && abs(currentVy) < 1.0) {
                timer.invalidate()
                inertiaTimer = nil
                return
            }
            
            // 归一化进度 t (0~1)
            let t = CGFloat(step) / CGFloat(totalSteps)
            // 二次缓出衰减因子
            let decay = 1.0 - t * t
            
            let stepDx = (currentVx / 60.0) * decay
            let stepDy = (currentVy / 60.0) * decay
            
            onPan?(stepDx, stepDy)
            
            currentVx *= 0.85
            currentVy *= 0.85
        }
    }
    
    private func stopInertia() {
        inertiaTimer?.invalidate()
        inertiaTimer = nil
        velocityX = 0
        velocityY = 0
    }
}
