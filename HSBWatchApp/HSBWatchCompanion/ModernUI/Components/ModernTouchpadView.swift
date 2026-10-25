//
//  ModernTouchpadView.swift
//  HSBWatchCompanion
//
//  基于 UIKit 高精度手势引擎实现的现代化仿 Mac 触控板。
//  精准分离：单指滑动光标 (onPan)、双指无级滚动页面 (onScroll / mac_scroll)、
//  单指轻点 (单击)、双指轻点 (右键/菜单)、双指捏合缩放 (onZoom) 与 8 阶物理惯性平滑衰减。
//

import SwiftUI
import UIKit

public struct ModernTouchpadView: View {
    public var isFullScreen: Binding<Bool>?
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
    @State private var isInTwoFingerScroll: Bool = false
    @State private var inertiaTimer: Timer? = nil
    @State private var lastTouchLocation: CGPoint? = nil
    @State private var isTouching: Bool = false
    
    private let lightHaptic = UIImpactFeedbackGenerator(style: .light)
    private let mediumHaptic = UIImpactFeedbackGenerator(style: .medium)
    
    public init(
        isFullScreen: Binding<Bool>? = nil,
        onPan: ((CGFloat, CGFloat) -> Void)? = nil,
        onTap: ((Int, CGPoint?) -> Void)? = nil,
        onScroll: ((CGFloat, CGFloat) -> Void)? = nil,
        onDrag: ((DragState, CGFloat, CGFloat) -> Void)? = nil,
        onZoom: ((CGFloat) -> Void)? = nil
    ) {
        self.isFullScreen = isFullScreen
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
                    Image(systemName: isInTwoFingerScroll ? "arrow.up.and.down" : "cursorarrow.motionlines")
                        .font(.system(size: 28, weight: .light))
                        .foregroundColor(isInTwoFingerScroll ? Color.accentColor : Color.primary.opacity(0.35))
                        .animation(.easeInOut(duration: 0.15), value: isInTwoFingerScroll)
                    
                    Text(touchpadStatusText)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(isInTwoFingerScroll ? Color.accentColor : Color.primary.opacity(0.4))
                }
                
                // 触控点动态指示器
                if isTouching, let loc = lastTouchLocation {
                    Circle()
                        .fill((isInTwoFingerScroll ? Color.green : Color.accentColor).opacity(0.35))
                        .frame(width: isInTwoFingerScroll ? 44 : 36, height: isInTwoFingerScroll ? 44 : 36)
                        .position(loc)
                        .transition(.scale.combined(with: .opacity))
                }
                
                // UIKit 高精度多指手势识别层
                NativeTouchpadGestureOverlay(
                    onOneFingerPan: { dx, dy in
                        handleOneFingerPan(dx: dx, dy: dy)
                    },
                    onTwoFingerPan: { dx, dy in
                        handleTwoFingerPan(dx: dx, dy: dy)
                    },
                    onPanEnded: { location, vx, vy, isTwoFinger in
                        handlePanEnded(location: location, vx: vx, vy: vy, isTwoFinger: isTwoFinger)
                    },
                    onOneFingerTap: { pt in
                        lightHaptic.impactOccurred()
                        onTap?(1, pt)
                    },
                    onTwoFingerTap: { pt in
                        lightHaptic.impactOccurred()
                        onTap?(3, pt)
                    },
                    onZoom: { scale in
                        onZoom?(scale)
                    },
                    onTouchStateChanged: { touching, loc in
                        let wasTouching = self.isTouching
                        self.isTouching = touching
                        self.lastTouchLocation = loc
                        if touching && !wasTouching {
                            stopInertia()
                            lightHaptic.prepare()
                        } else if !touching {
                            self.isInTwoFingerScroll = false
                        }
                    }
                )
                
                // 右上角全屏触控切换按钮 (置于手势层上方，确保点击即刻触发全屏/退出全屏)
                if let fullScreenBinding = isFullScreen {
                    VStack {
                        HStack {
                            Spacer()
                            Button(action: {
                                mediumHaptic.impactOccurred()
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                                    fullScreenBinding.wrappedValue.toggle()
                                }
                                NotificationCenter.default.post(
                                    name: Notification.Name("HSBTrackpadFullScreenChangedNotification"),
                                    object: nil,
                                    userInfo: ["isFullScreen": fullScreenBinding.wrappedValue]
                                )
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: fullScreenBinding.wrappedValue ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                                        .font(.system(size: 11, weight: .bold))
                                    Text(fullScreenBinding.wrappedValue ? "退出全屏" : "全屏")
                                        .font(.system(size: 11.5, weight: .semibold))
                                }
                                .foregroundColor(.white.opacity(0.92))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(fullScreenBinding.wrappedValue ? Color(red: 224.0 / 255.0, green: 36.0 / 255.0, blue: 56.0 / 255.0).opacity(0.88) : Color.black.opacity(0.45))
                                        .overlay(
                                            Capsule().stroke(Color.white.opacity(0.18), lineWidth: 1)
                                        )
                                )
                            }
                            .accessibilityIdentifier(fullScreenBinding.wrappedValue ? "mac_exit_fullscreen_trackpad_button" : "mac_fullscreen_trackpad_button")
                            .accessibilityLabel(fullScreenBinding.wrappedValue ? "退出全屏" : "全屏触控")
                        }
                        .padding(.top, 10)
                        .padding(.trailing, 12)
                        Spacer()
                    }
                }
            }
        }
    }
    
    private var touchpadStatusText: String {
        if isInTwoFingerScroll {
            return "双指无级滚动中"
        } else if isTouching {
            return "单指光标微操中"
        } else {
            return "单指滑动光标 · 双指无级滚动"
        }
    }
    
    // MARK: - Handlers
    private func handleOneFingerPan(dx: CGFloat, dy: CGFloat) {
        isInTwoFingerScroll = false
        virtualX += dx
        virtualY += dy
        if virtualX < 0 || virtualX > 1000 || virtualY < 0 || virtualY > 1000 {
            virtualX = 500.0
            virtualY = 500.0
        }
        onPan?(dx, dy)
    }
    
    private func handleTwoFingerPan(dx: CGFloat, dy: CGFloat) {
        isInTwoFingerScroll = true
        // 自然滚动换算：两指向下滑动，内容向下移动(dy为正向增加)
        onScroll?(-dx, -dy)
    }
    
    private func handlePanEnded(location: CGPoint, vx: CGFloat, vy: CGFloat, isTwoFinger: Bool) {
        isTouching = false
        lastTouchLocation = nil
        velocityX = vx
        velocityY = vy
        
        let speed = hypot(vx, vy)
        if speed > 100.0 {
            // 抬手触发 8 阶二次缓出惯性平滑滑动
            startQuadEaseOutInertia(isTwoFinger: isTwoFinger)
        }
        isInTwoFingerScroll = false
    }
    
    // MARK: - 8 阶二次缓出惯性滑动算法 (Quad Ease-Out Glide)
    private func startQuadEaseOutInertia(isTwoFinger: Bool) {
        stopInertia()
        
        var step = 0
        let totalSteps = 8
        var currentVx = velocityX * 0.35
        var currentVy = velocityY * 0.35
        
        inertiaTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { timer in
            step += 1
            if step > totalSteps || (abs(currentVx) < 1.0 && abs(currentVy) < 1.0) {
                timer.invalidate()
                inertiaTimer = nil
                return
            }
            
            let t = CGFloat(step) / CGFloat(totalSteps)
            let decay = 1.0 - t * t
            let stepDx = (currentVx / 60.0) * decay
            let stepDy = (currentVy / 60.0) * decay
            
            if isTwoFinger {
                onScroll?(-stepDx, -stepDy)
            } else {
                onPan?(stepDx, stepDy)
            }
            
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

// MARK: - UIKit 多指手势识别封装
private struct NativeTouchpadGestureOverlay: UIViewRepresentable {
    var onOneFingerPan: (CGFloat, CGFloat) -> Void
    var onTwoFingerPan: (CGFloat, CGFloat) -> Void
    var onPanEnded: (CGPoint, CGFloat, CGFloat, Bool) -> Void
    var onOneFingerTap: (CGPoint) -> Void
    var onTwoFingerTap: (CGPoint) -> Void
    var onZoom: (CGFloat) -> Void
    var onTouchStateChanged: (Bool, CGPoint?) -> Void
    
    func makeUIView(context: Context) -> UIView {
        let view = TouchpadOverlayUIView()
        view.backgroundColor = .clear
        view.coordinator = context.coordinator
        
        // 1. 单指移动平移手势
        let oneFingerPan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleOneFingerPan(_:)))
        oneFingerPan.minimumNumberOfTouches = 1
        oneFingerPan.maximumNumberOfTouches = 1
        oneFingerPan.delegate = context.coordinator
        view.addGestureRecognizer(oneFingerPan)
        
        // 2. 双指滚动平移手势
        let twoFingerPan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTwoFingerPan(_:)))
        twoFingerPan.minimumNumberOfTouches = 2
        twoFingerPan.maximumNumberOfTouches = 2
        twoFingerPan.delegate = context.coordinator
        view.addGestureRecognizer(twoFingerPan)
        
        // 3. 单指轻点
        let singleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleSingleTap(_:)))
        singleTap.numberOfTapsRequired = 1
        singleTap.numberOfTouchesRequired = 1
        singleTap.delegate = context.coordinator
        singleTap.require(toFail: oneFingerPan)
        view.addGestureRecognizer(singleTap)
        
        // 4. 双指轻点 (右键)
        let twoFingerTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTwoFingerTap(_:)))
        twoFingerTap.numberOfTapsRequired = 1
        twoFingerTap.numberOfTouchesRequired = 2
        twoFingerTap.delegate = context.coordinator
        twoFingerTap.require(toFail: twoFingerPan)
        view.addGestureRecognizer(twoFingerTap)
        
        // 5. 缩放手势
        let pinch = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePinch(_:)))
        pinch.delegate = context.coordinator
        view.addGestureRecognizer(pinch)
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.parent = self
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var parent: NativeTouchpadGestureOverlay
        
        init(parent: NativeTouchpadGestureOverlay) {
            self.parent = parent
        }
        
        @objc func handleOneFingerPan(_ recognizer: UIPanGestureRecognizer) {
            guard let view = recognizer.view else { return }
            let loc = recognizer.location(in: view)
            
            switch recognizer.state {
            case .began:
                let initial = recognizer.translation(in: view)
                recognizer.setTranslation(.zero, in: view)
                parent.onTouchStateChanged(true, loc)
                if abs(initial.x) > 0.1 || abs(initial.y) > 0.1 {
                    parent.onOneFingerPan(initial.x, initial.y)
                }
            case .changed:
                let translation = recognizer.translation(in: view)
                recognizer.setTranslation(.zero, in: view)
                parent.onTouchStateChanged(true, loc)
                parent.onOneFingerPan(translation.x, translation.y)
            case .ended, .cancelled:
                let velocity = recognizer.velocity(in: view)
                parent.onPanEnded(loc, velocity.x, velocity.y, false)
            default:
                break
            }
        }
        
        @objc func handleTwoFingerPan(_ recognizer: UIPanGestureRecognizer) {
            guard let view = recognizer.view else { return }
            let loc = recognizer.location(in: view)
            
            switch recognizer.state {
            case .began:
                recognizer.setTranslation(.zero, in: view)
                parent.onTouchStateChanged(true, loc)
            case .changed:
                let translation = recognizer.translation(in: view)
                recognizer.setTranslation(.zero, in: view)
                parent.onTouchStateChanged(true, loc)
                parent.onTwoFingerPan(translation.x, translation.y)
            case .ended, .cancelled:
                let velocity = recognizer.velocity(in: view)
                parent.onPanEnded(loc, velocity.x, velocity.y, true)
            default:
                break
            }
        }
        
        @objc func handleSingleTap(_ recognizer: UITapGestureRecognizer) {
            guard let view = recognizer.view else { return }
            let loc = recognizer.location(in: view)
            parent.onOneFingerTap(loc)
        }
        
        @objc func handleTwoFingerTap(_ recognizer: UITapGestureRecognizer) {
            guard let view = recognizer.view else { return }
            let loc = recognizer.location(in: view)
            parent.onTwoFingerTap(loc)
        }
        
        @objc func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
            if recognizer.state == .changed {
                parent.onZoom(recognizer.scale)
                recognizer.scale = 1.0
            }
        }
        
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            if gestureRecognizer is UIPinchGestureRecognizer || otherGestureRecognizer is UIPinchGestureRecognizer {
                return true
            }
            return false
        }
    }
}

private class TouchpadOverlayUIView: UIView {
    weak var coordinator: NativeTouchpadGestureOverlay.Coordinator?
}
