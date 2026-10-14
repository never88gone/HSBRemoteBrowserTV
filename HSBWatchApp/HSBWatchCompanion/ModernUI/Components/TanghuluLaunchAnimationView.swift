//
//  TanghuluLaunchAnimationView.swift
//  HSBWatchCompanion
//
//  糖葫芦遥控器入场动画：
//  小人（糖葫芦拟人）从远处迎面踏步走向屏幕正中，
//  到达正中后双脚收拢隐去，竹签向下自然延伸，
//  外围舒展白色遥控器线框与顶部信号波，中心浮现极简播放键，完整蜕变为 App 图标。
//

import SwiftUI

public struct TanghuluLaunchAnimationView: View {
    public var onFinished: (() -> Void)?
    
    // 动画状态机控制
    @State private var approachProgress: CGFloat = 0.0 // 0 -> 1 从远处走向屏幕正中央
    @State private var walkCycle: CGFloat = 0.0        // 双腿交替迎面踏步时钟 (Animatable)
    @State private var legsRetracted: CGFloat = 0.0    // 0 (展开) -> 1 (完全收起消失)
    @State private var remoteFrameTrim: CGFloat = 0.0  // 遥控器外框线条展开
    @State private var playButtonOpacity: Double = 0.0 // 播放三角形显现
    @State private var signalWaveTrim: CGFloat = 0.0   // 顶部信号弧线展开
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
                // 1. 遥控器外围圆角矩形白线轮廓（小人站定收脚后优雅展开）
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
                
                // 3. 糖葫芦拟人核心（从远处走来 -> 屏幕正中站定 -> 变为图标串珠）
                ZStack {
                    // 竹签中轴（贯穿三球，随双脚收回自然延伸到底端 285）
                    TanghuluStickShape(legsRetracted: legsRetracted)
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
                    
                    // 底部球（小人臀部/下肢连接点，中心在 70, 225，下沿在 70, 257）
                    Circle()
                        .stroke(hawthornRed, lineWidth: 4)
                        .frame(width: 64, height: 64)
                        .offset(y: 65)
                    
                    // 4. 小人的迎面行走双腿（正面朝向观众踏步，交替落地与提步，站定后收缩消失）
                    TanghuluFrontalLegsShape(walkCycle: walkCycle, legsRetracted: legsRetracted)
                        .stroke(hawthornRed, style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round))
                }
                .frame(width: 140, height: 320)
                // 空间景深透视变换：从远处（极小尺寸 + 上方远景）迎面踏步走向正中央（标准 1.0 尺寸）
                .scaleEffect(legsRetracted < 1.0 ? (0.16 + 0.84 * approachProgress) : 1.0)
                .offset(
                    x: legsRetracted < 1.0 ? CGFloat(sin(Double(walkCycle))) * 2.5 : 0, // 重心左右轻微自然晃动
                    y: (1.0 - approachProgress) * -60.0 + (legsRetracted < 1.0 ? abs(CGFloat(sin(Double(walkCycle)))) * -5.0 : 0) // 由远处走近，配合步伐上下起伏
                )
                .opacity(legsRetracted < 1.0 ? min(1.0, Double(approachProgress * 2.5)) : 1.0)
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
        // Step 1: 小人从远处迎面欢快踏步走来，由远及近到达屏幕正中央（时长 1.1s）
        withAnimation(.timingCurve(0.25, 0.1, 0.25, 1.0, duration: 1.1)) {
            approachProgress = 1.0
        }
        withAnimation(.linear(duration: 1.1)) {
            walkCycle = CGFloat.pi * 8 // 约 8 步稳健踏步
        }
        
        // Step 2: 到达屏幕正中心站定，双脚自然收缩隐去，竹签延伸到底部（1.1s ~ 1.45s）
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            withAnimation(.easeInOut(duration: 0.35)) {
                legsRetracted = 1.0
                walkCycle = 0
            }
        }
        
        // Step 3: 遥控器外框展开、信号波发射、播放按键浮现（1.45s ~ 2.1s）
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.45) {
            withAnimation(.easeInOut(duration: 0.65)) {
                remoteFrameTrim = 1.0
                signalWaveTrim = 1.0
                playButtonOpacity = 1.0
            }
        }
        
        // Step 4: 图标成型微光定格，随后平滑过渡进入主页（2.4s）
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
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

// MARK: - 辅助图形与动画 Shape

/// 糖葫芦竹签主体（随收脚向下延伸）
private struct TanghuluStickShape: Shape {
    var legsRetracted: CGFloat
    
    var animatableData: CGFloat {
        get { legsRetracted }
        set { legsRetracted = newValue }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 70, y: 35))
        let bottomY: CGFloat = 252.0 + 33.0 * legsRetracted
        path.addLine(to: CGPoint(x: 70, y: bottomY))
        return path
    }
}

/// 糖葫芦小人迎面正面行走双腿 (遵循 Animatable，支持 120FPS 丝滑逐帧动态插值)
private struct TanghuluFrontalLegsShape: Shape {
    var walkCycle: CGFloat
    var legsRetracted: CGFloat
    
    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(walkCycle, legsRetracted) }
        set {
            walkCycle = newValue.first
            legsRetracted = newValue.second
        }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard legsRetracted < 1.0 else { return path }
        
        let retractFactor = CGFloat(1.0 - legsRetracted)
        let baseLength: CGFloat = 26.0 * retractFactor
        
        // 正面迎面步态时钟
        let cycleSin = CGFloat(sin(Double(walkCycle)))
        let leftStep = cycleSin * retractFactor
        let rightStep = -cycleSin * retractFactor
        
        let leftLength = baseLength + leftStep * 4.5
        let rightLength = baseLength + rightStep * 4.5
        
        // 正面微外八字萌态角度 (踏步时富于弹性和拟人感)
        let leftRad = Double(-10.0 - Double(leftStep) * 8.0) * .pi / 180.0
        let rightRad = Double(10.0 + Double(rightStep) * 8.0) * .pi / 180.0
        
        // 左腿与脚掌
        let leftHip = CGPoint(x: 57, y: 252)
        let leftFoot = CGPoint(
            x: leftHip.x + CGFloat(sin(leftRad)) * leftLength,
            y: leftHip.y + CGFloat(cos(leftRad)) * leftLength
        )
        path.move(to: leftHip)
        path.addLine(to: leftFoot)
        path.addLine(to: CGPoint(x: leftFoot.x - 5.0 * retractFactor, y: leftFoot.y + 1.0))
        
        // 右腿与脚掌
        let rightHip = CGPoint(x: 83, y: 252)
        let rightFoot = CGPoint(
            x: rightHip.x + CGFloat(sin(rightRad)) * rightLength,
            y: rightHip.y + CGFloat(cos(rightRad)) * rightLength
        )
        path.move(to: rightHip)
        path.addLine(to: rightFoot)
        path.addLine(to: CGPoint(x: rightFoot.x + 5.0 * retractFactor, y: rightFoot.y + 1.0))
        
        return path
    }
}

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
