//
//  ModernPDFControlView.swift
//  HSBWatchCompanion
//

import SwiftUI
import UIKit

public struct ModernPDFControlView: View {
    public var isWideDuo: Bool = false
    public var onPageChange: ((_ isNext: Bool) -> Void)?
    public var onJumpPage: ((_ isFirst: Bool) -> Void)?
    public var onDrawAction: ((_ type: String, _ point: CGPoint, _ color: String, _ width: CGFloat) -> Void)?
    public var onClear: (() -> Void)?
    public var onUndo: (() -> Void)?
    
    @State private var selectedColorKey: String = HSBRemoteDrawColorRed
    @State private var selectedWidth: CGFloat = 4.0
    @State private var isEraserActive: Bool = false
    @State private var isLaserPointerActive: Bool = true
    @State private var completedStrokes: [(points: [CGPoint], color: Color, width: CGFloat)] = []
    @State private var currentStrokePoints: [CGPoint] = []
    @State private var livePointerPoint: CGPoint? = nil
    @State private var elapsedSeconds: Int = 0
    @State private var isTimerRunning: Bool = false
    
    private let haptic = UIImpactFeedbackGenerator(style: .medium)
    private let lightHaptic = UIImpactFeedbackGenerator(style: .light)
    private let presentationTimer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
    
    private let colorPalette: [(key: String, color: Color, name: String)] = [
        (HSBRemoteDrawColorRed, .red, "红"),
        (HSBRemoteDrawColorBlue, .tanghuluBrandBlue, "蓝"),
        (HSBRemoteDrawColorYellow, .yellow, "黄"),
        (HSBRemoteDrawColorGreen, .green, "绿"),
        (HSBRemoteDrawColorWhite, .white, "白")
    ]
    
    public init(
        isWideDuo: Bool = false,
        onPageChange: ((_ isNext: Bool) -> Void)? = nil,
        onJumpPage: ((_ isFirst: Bool) -> Void)? = nil,
        onDrawAction: ((_ type: String, _ point: CGPoint, _ color: String, _ width: CGFloat) -> Void)? = nil,
        onClear: (() -> Void)? = nil,
        onUndo: (() -> Void)? = nil
    ) {
        self.isWideDuo = isWideDuo
        self.onPageChange = onPageChange
        self.onJumpPage = onJumpPage
        self.onDrawAction = onDrawAction
        self.onClear = onClear
        self.onUndo = onUndo
    }
    
    public var body: some View {
        Group {
            if isWideDuo {
                wideDuoBody
            } else {
                compactBody
            }
        }
        .onReceive(presentationTimer) { _ in
            if isTimerRunning {
                elapsedSeconds += 1
            }
        }
    }
    
    private var activeStrokeColor: Color {
        colorPalette.first(where: { $0.key == selectedColorKey })?.color ?? .red
    }
    
    private func triggerUndo() {
        lightHaptic.impactOccurred()
        if !completedStrokes.isEmpty {
            completedStrokes.removeLast()
        }
        onUndo?()
    }
    
    private func triggerClear() {
        lightHaptic.impactOccurred()
        completedStrokes.removeAll()
        currentStrokePoints.removeAll()
        livePointerPoint = nil
        onClear?()
    }
    
    private var compactBody: some View {
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
                    triggerUndo()
                }
                quickNavButton(title: "清空画布", icon: "trash.fill") {
                    triggerClear()
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
                    colorDotsRow
                }
                .padding(.horizontal, 16)
                
                // 涂鸦手势画板
                laserDrawingCanvas
                    .frame(maxHeight: .infinity)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            }
        }
    }
    
    // MARK: - V2 展开态：跨中轴 16:9 同步激光画板 + 左下盲操翻页 + 右下调色/计时 L 型避让
    
    private var wideDuoBody: some View {
        VStack(spacing: 11) {
            // 上区：16:9 同步大屏涂鸦 / 激光聚光画板 (紧凑向上舒展，彻底消除顶部大面积留白)
            VStack(spacing: 8) {
                HStack(spacing: 10) {
                    Label("16:9 大屏同步激光笔与画板", systemImage: "laser.burst")
                        .font(.system(size: 13.5, weight: .bold, design: .rounded))
                        .foregroundColor(DuoPalette.textPrimary)
                    
                    Text(isLaserPointerActive ? "激光聚光中" : "标注笔迹同步")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundColor(activeStrokeColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(activeStrokeColor.opacity(0.14), in: Capsule())
                    
                    Spacer()
                    
                    Text("已绘 \(completedStrokes.count) 笔 · 线宽 \(Int(selectedWidth))pt")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(DuoPalette.textSecondary)
                }
                
                laserDrawingCanvas
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .duoCard(cornerRadius: DuoMetrics.cardRadius)
            
            // 下区：左下盲操翻页岛 + 右下调色/线宽/演讲计时 (L 型避让 86pt 侧边栏)
            HStack(alignment: .top, spacing: DuoMetrics.columnGap) {
                // 左下区：幻灯翻页与快捷导航
                VStack(spacing: 10) {
                    HStack(spacing: 12) {
                        Button {
                            haptic.impactOccurred()
                            onPageChange?(false)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.left.circle.fill")
                                    .font(.system(size: 26, weight: .semibold))
                                Text("上一页")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        .buttonStyle(PresentationButtonStyle(backgroundColor: DuoPalette.brandBlue.opacity(0.22)))
                        
                        Button {
                            haptic.impactOccurred()
                            onPageChange?(true)
                        } label: {
                            HStack(spacing: 8) {
                                Text("下一页")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                Image(systemName: "arrow.right.circle.fill")
                                    .font(.system(size: 26, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        .buttonStyle(PresentationButtonStyle(backgroundColor: DuoPalette.accentRed.opacity(0.26)))
                    }
                    .frame(height: 114)
                    
                    HStack(spacing: 8) {
                        quickNavButton(title: "跳转首页", icon: "backward.end.fill") { onJumpPage?(true) }
                        quickNavButton(title: "撤销标注", icon: "arrow.uturn.backward") { triggerUndo() }
                        quickNavButton(title: "清空画布", icon: "trash.fill") { triggerClear() }
                        quickNavButton(title: "跳转尾页", icon: "forward.end.fill") { onJumpPage?(false) }
                    }
                    .frame(maxHeight: .infinity)
                }
                .padding(12)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .duoCard(cornerRadius: DuoMetrics.cardRadius)
                
                // 右下 L 型让位区：收缩让出右下侧边栏（224pt 高防止画板重叠边栏）
                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 8) {
                        // 色盘 + 线宽控制卡
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("笔迹色盘与粗细")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundColor(DuoPalette.textSecondary)
                                Spacer()
                                HStack(spacing: 6) {
                                    ForEach([2.0, 4.0, 8.0], id: \.self) { w in
                                        Button {
                                            lightHaptic.impactOccurred()
                                            selectedWidth = CGFloat(w)
                                        } label: {
                                            Text("\(Int(w))")
                                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                                .foregroundColor(selectedWidth == CGFloat(w) ? DuoPalette.textPrimary : DuoPalette.textMuted)
                                                .frame(width: 24, height: 24)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 6)
                                                        .fill(selectedWidth == CGFloat(w) ? DuoPalette.accentRed.opacity(0.26) : DuoPalette.cardElevated)
                                                )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            colorDotsRow
                        }
                        .padding(10)
                        .duoCard(cornerRadius: DuoMetrics.innerCardRadius, fill: DuoPalette.cardElevated)
                        
                        // 激光指示模式切换胶囊
                        Button {
                            lightHaptic.impactOccurred()
                            isLaserPointerActive.toggle()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: isLaserPointerActive ? "laser.burst" : "scribble.variable")
                                    .font(.system(size: 13.5, weight: .bold))
                                    .foregroundColor(isLaserPointerActive ? DuoPalette.accentRed : DuoPalette.brandBlue)
                                Text(isLaserPointerActive ? "激光实时聚光模式" : "大屏笔迹永久标注")
                                    .font(.system(size: 11.5, weight: .semibold))
                                    .foregroundColor(DuoPalette.textPrimary)
                                    .lineLimit(1)
                                Spacer(minLength: 0)
                                Text("切换")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(DuoPalette.textSecondary)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background(DuoPalette.cardFill, in: Capsule())
                            }
                            .padding(.horizontal, 10)
                            .frame(height: 36)
                            .duoCard(cornerRadius: 11, fill: DuoPalette.cardElevated)
                        }
                        .buttonStyle(.plain)
                        
                        // 演讲计时器条
                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text("演讲计时器")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(DuoPalette.textSecondary)
                                Text(formattedElapsedTime)
                                    .font(.system(size: 17, weight: .bold, design: .monospaced))
                                    .foregroundColor(isTimerRunning ? DuoPalette.readyGreen : DuoPalette.textPrimary)
                            }
                            Spacer(minLength: 0)
                            Button {
                                lightHaptic.impactOccurred()
                                isTimerRunning.toggle()
                            } label: {
                                Image(systemName: isTimerRunning ? "pause.fill" : "play.fill")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 34, height: 34)
                                    .background(isTimerRunning ? DuoPalette.warmOrange : DuoPalette.readyGreen, in: Circle())
                            }
                            .buttonStyle(.plain)
                            Button {
                                lightHaptic.impactOccurred()
                                isTimerRunning = false
                                elapsedSeconds = 0
                            } label: {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(DuoPalette.textSecondary)
                                    .frame(width: 32, height: 34)
                                    .background(DuoPalette.cardFill, in: Circle())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 10)
                        .frame(maxHeight: .infinity)
                        .duoCard(cornerRadius: DuoMetrics.innerCardRadius, fill: DuoPalette.cardElevated)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .duoCard(cornerRadius: DuoMetrics.cardRadius)
                    
                    Spacer()
                        .frame(width: DuoMetrics.sidebarReserveWidth - DuoMetrics.trailingPadding)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(height: 224)
        }
    }
    
    private var formattedElapsedTime: String {
        let mins = elapsedSeconds / 60
        let secs = elapsedSeconds % 60
        return String(format: "%02d:%02d", mins, secs)
    }
    
    private var colorDotsRow: some View {
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
    
    private var laserDrawingCanvas: some View {
        GeometryReader { geo in
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isWideDuo ? DuoPalette.cardElevated : Color(UIColor.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(isWideDuo ? DuoPalette.stroke : Color.primary.opacity(0.08), lineWidth: 1)
                    )
                
                if completedStrokes.isEmpty && currentStrokePoints.isEmpty {
                    VStack(spacing: 6) {
                        Image(systemName: "hand.draw.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.secondary.opacity(0.4))
                        Text("在区域内滑动实时在大屏上标注或聚光")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary.opacity(0.6))
                    }
                }
                
                // 已完成笔迹叠加层
                ForEach(Array(completedStrokes.enumerated()), id: \.offset) { _, stroke in
                    Path { path in
                        guard let first = stroke.points.first else { return }
                        path.move(to: CGPoint(x: first.x * geo.size.width, y: first.y * geo.size.height))
                        for pt in stroke.points.dropFirst() {
                            path.addLine(to: CGPoint(x: pt.x * geo.size.width, y: pt.y * geo.size.height))
                        }
                    }
                    .stroke(stroke.color, style: StrokeStyle(lineWidth: stroke.width, lineCap: .round, lineJoin: .round))
                }
                
                // 当前绘制中笔迹
                if !currentStrokePoints.isEmpty {
                    Path { path in
                        guard let first = currentStrokePoints.first else { return }
                        path.move(to: CGPoint(x: first.x * geo.size.width, y: first.y * geo.size.height))
                        for pt in currentStrokePoints.dropFirst() {
                            path.addLine(to: CGPoint(x: pt.x * geo.size.width, y: pt.y * geo.size.height))
                        }
                    }
                    .stroke(activeStrokeColor, style: StrokeStyle(lineWidth: selectedWidth, lineCap: .round, lineJoin: .round))
                }
                
                // 实时激光指示光点
                if let pt = livePointerPoint {
                    Circle()
                        .fill(activeStrokeColor.opacity(0.32))
                        .frame(width: 28, height: 28)
                        .overlay(Circle().fill(activeStrokeColor).frame(width: 10, height: 10))
                        .position(x: pt.x * geo.size.width, y: pt.y * geo.size.height)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let nx = max(0, min(1, value.location.x / max(1, geo.size.width)))
                        let ny = max(0, min(1, value.location.y / max(1, geo.size.height)))
                        let normPt = CGPoint(x: nx, y: ny)
                        currentStrokePoints.append(normPt)
                        livePointerPoint = normPt
                        onDrawAction?(HSBRemoteDrawTypeMoved, normPt, selectedColorKey, selectedWidth)
                    }
                    .onEnded { value in
                        let nx = max(0, min(1, value.location.x / max(1, geo.size.width)))
                        let ny = max(0, min(1, value.location.y / max(1, geo.size.height)))
                        let normPt = CGPoint(x: nx, y: ny)
                        if !currentStrokePoints.isEmpty {
                            completedStrokes.append((points: currentStrokePoints, color: activeStrokeColor, width: selectedWidth))
                            currentStrokePoints.removeAll()
                        }
                        livePointerPoint = nil
                        onDrawAction?(HSBRemoteDrawTypeEnded, normPt, selectedColorKey, selectedWidth)
                    }
            )
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
            .background(isWideDuo ? DuoPalette.cardElevated : Color(UIColor.secondarySystemBackground))
            .foregroundColor(isWideDuo ? DuoPalette.textPrimary : .primary)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
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

#if DEBUG
#Preview("PDF 演讲笔迹板 · 折叠窄屏") {
    DuoPreviewContainer(expandedDuo: false) {
        ModernPDFControlView(isWideDuo: false)
    }
}

#Preview("PDF 演讲笔迹板 · iPhone Duo 双栏") {
    DuoPreviewContainer(expandedDuo: true) {
        ModernPDFControlView(isWideDuo: true)
            .padding(18)
    }
}
#endif
