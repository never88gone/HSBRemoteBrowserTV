//
//  TanghuluLaunchAnimationView.swift
//  HSBWatchCompanion
//
//  糖葫芦遥控器入场动画：
//  小人（糖葫芦拟人）从侧边迈步走出，到达中央后双脚向上收缩消失，
//  外围舒展白色遥控器线框与顶部信号波，中心浮现极简播放键，完整蜕变为 App 图标。
//

import SwiftUI

public struct TanghuluLaunchAnimationView: View {
    public var onFinished: (() -> Void)?
    
    // 动画状态机控制
    @State private var walkProgress: CGFloat = 0.0     // 0 -> 1 从左侧走出到中央
    @State private var walkCycle: CGFloat = 0.0        // 双腿交替摆动时钟
    @State private var legsRetracted: CGFloat = 0.0    // 0 (展开) -> 1 (完全收起消失)
    @State private var remoteFrameTrim: CGFloat = 0.0  // 遥控器外框线条展开
    @State private var playButtonOpacity: Double = 0.0 // 播放三角形显现
    @State private var signalWaveTrim: CGFloat = 0.0   // 顶部信号弧线展开
    @State private var iconGlowOpacity: Double = 0.0   // 完成时的微光
    @State private var isDismissed: Bool = false
    
    // 颜色规范：深炭黑底色 + 朱砂红糖葫芦 + 纯白遥控外框
    private let backgroundColor = Color(red: 34.0 / 255.0, green: 34.0 / 255.0, blue: 34.0 / 255.0)
    private let hawthornRed = Color(red: 224.0 / 255.0, green: 36.0 / 255.0, blue: 56.0 / 255.0)
    
    public init(onFinished: (() -> Void)? = nil) {
        self.onFinished = onFinished
    }
    
    public var body: some View {
        ZStack {
            backgroundColor
                .ignoresSafeArea()
            
            // 主图标容器（320x320 标准视窗）
            ZStack {
                // 1. 遥控器外围圆角矩形白线轮廓
                RoundedRectangle(cornerRadius: 32)
                    .trim(from: 0, to: remoteFrameTrim)
                    .stroke(Color.white, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                    .frame(width: 140, height: 320)
                
                // 2. 顶部发射信号弧线 (两道无线信号波)
                VStack(spacing: 8) {
                    SignalArc(radius: 26)
                        .trim(from: 0, to: signalWaveTrim)
                        .stroke(Color.white, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 44, height: 14)
                    
                    SignalArc(radius: 16)
                        .trim(from: 0, to: signalWaveTrim)
                        .stroke(Color.white, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 28, height: 10)
                    
                    Spacer()
                }
                .frame(width: 140, height: 320)
                .offset(y: -24)
                
                // 3. 糖葫芦小人 / 核心串珠
                ZStack {
                    // 竹签中轴（贯穿三球，底端延伸）
                    Path { path in
                        path.move(to: CGPoint(x: 70, y: 35))
                        path.addLine(to: CGPoint(x: 70, y: 285))
                    }
                    .stroke(hawthornRed, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                    
                    // 顶部球（小人头部）
                    Circle()
                        .stroke(hawthornRed, lineWidth: 4)
                        .frame(width: 64, height: 64)
                        .offset(y: -65)
                    
                    // 中间球（小人胸腹躯干）
                    Circle()
                        .stroke(hawthornRed, lineWidth: 4)
                        .frame(width: 64, height: 64)
                        .offset(y: 0)
                    
                    // 中间球内部的极简白色播放键（定格蜕变时亮起）
                    PlayTriangle()
                        .fill(Color.white)
                        .frame(width: 18, height: 20)
                        .offset(x: 2, y: 0)
                        .opacity(playButtonOpacity)
                    
                    // 底部球（小人臀部/下肢连接点）
                    Circle()
                        .stroke(hawthornRed, lineWidth: 4)
                        .frame(width: 64, height: 64)
                        .offset(y: 65)
                    
                    // 4. 小人的两条行走小脚（随迈步摆动，之后收起消失）
                    if legsRetracted < 1.0 {
                        let legLength: CGFloat = 26.0 * (1.0 - legsRetracted)
                        let leftAngle: Double = Double(sin(walkCycle) * 28.0) * Double(1.0 - legsRetracted)
                        let rightAngle: Double = Double(-sin(walkCycle) * 28.0) * Double(1.0 - legsRetracted)
                        
                        // 左腿
                        LegShape(angleDegrees: leftAngle, length: legLength)
                            .stroke(hawthornRed, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                            .position(x: 60, y: 228)
                            .opacity(Double(1.0 - legsRetracted))
                        
                        // 右腿
                        LegShape(angleDegrees: rightAngle, length: legLength)
                            .stroke(hawthornRed, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                            .position(x: 80, y: 228)
                            .opacity(Double(1.0 - legsRetracted))
                    }
                }
                .frame(width: 140, height: 320)
                // 走动时的 X 偏移（-140 -> 0）及微幅上下颠簸（Bobbing）
                .offset(
                    x: (1.0 - walkProgress) * -160,
                    y: legsRetracted < 1.0 ? abs(sin(walkCycle)) * -5 : 0
                )
            }
            .scaleEffect(isDismissed ? 1.08 : 1.0)
            .opacity(isDismissed ? 0.0 : 1.0)
            
            // 跳过提示（可点击屏幕任意位置跳过动画）
            VStack {
                Spacer()
                Text("点击跳过")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(Color.white.opacity(0.35))
                    .padding(.bottom, 40)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            finishEarly()
        }
        .onAppear {
            startAnimationSequence()
        }
    }
    
    // MARK: - 动画编排时间线
    private func startAnimationSequence() {
        // Step 1: 小人开始交替迈步，从左侧走到屏幕正中（时长约 0.9s）
        withAnimation(.linear(duration: 0.9)) {
            walkProgress = 1.0
        }
        withAnimation(.easeInOut(duration: 0.9).repeatCount(3, autoreverses: true)) {
            walkCycle = CGFloat.pi * 3
        }
        
        // Step 2: 到达中心后小人站定，双脚向上缩回并消失（0.9s ~ 1.25s）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            withAnimation(.easeInOut(duration: 0.35)) {
                legsRetracted = 1.0
            }
        }
        
        // Step 3: 遥控器外框展开、信号波发射、播放按键浮现（1.25s ~ 1.85s）
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.25) {
            withAnimation(.easeInOut(duration: 0.55)) {
                remoteFrameTrim = 1.0
                signalWaveTrim = 1.0
                playButtonOpacity = 1.0
            }
        }
        
        // Step 4: 图标成型微光定格，随后平滑过渡进入主页（2.2s）
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.1) {
            withAnimation(.easeInOut(duration: 0.4)) {
                isDismissed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                onFinished?()
            }
        }
    }
    
    private func finishEarly() {
        withAnimation(.easeInOut(duration: 0.25)) {
            isDismissed = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            onFinished?()
        }
    }
}

// MARK: - 辅助图形
private struct SignalArc: Shape {
    let radius: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.maxY + radius * 0.4)
        path.addArc(center: center, radius: radius, startAngle: .degrees(210), endAngle: .degrees(330), clockwise: false)
        return path
    }
}

private struct PlayTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct LegShape: Shape {
    let angleDegrees: Double
    let length: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        
        let rad = angleDegrees * .pi / 180.0
        let endX = rect.midX + sin(rad) * length
        let endY = rect.minY + cos(rad) * length
        path.addLine(to: CGPoint(x: endX, y: endY))
        
        // 小脚掌
        let footX = endX + (angleDegrees >= 0 ? 5.0 : 3.0)
        let footY = endY
        path.addLine(to: CGPoint(x: footX, y: footY))
        
        return path
    }
}
