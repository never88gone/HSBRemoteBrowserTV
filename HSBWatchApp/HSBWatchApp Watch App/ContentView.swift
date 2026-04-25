import SwiftUI
import Combine

func L(_ en: String, _ zh: String) -> String {
    let lang = Locale.preferredLanguages.first ?? Locale.current.identifier
    if lang.lowercased().hasPrefix("zh") {
        return zh
    }
    return en
}

struct ContentView: View {
    @StateObject private var motionManager = MotionManager()
    
    var body: some View {
        NavigationStack {
            TargetTVControlView(motionManager: motionManager)
        }
        .alert(isPresented: $motionManager.showErrorAlert) {
            Alert(
                title: Text(L("Error", "错误")),
                message: Text(motionManager.connectionError ?? L("Unknown Error", "未知错误")),
                dismissButton: .default(Text(L("OK", "确定")))
            )
        }
    }
}

struct TargetTVControlView: View {
    @ObservedObject var motionManager: MotionManager
    
    var statusText: String {
        switch motionManager.connectionState {
        case .connecting: return L("Syncing with Phone...", "正在同步手机数据...")
        case .connected: return L("Synced with Phone", "任务数据已同步")
        case .failed: return L("Sync Failed", "同步失败")
        case .disconnected: return L("Not Synced", "等待同步")
        }
    }
    
    var statusColor: Color {
        switch motionManager.connectionState {
        case .connecting: return .yellow
        case .connected: return .green
        case .failed, .disconnected: return .red
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                // 连接状态指示
                HStack(spacing: 4) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 6, height: 6)
                    Text(statusText)
                        .font(.caption2)
                        .foregroundColor(statusColor)
                }
                .padding(.top, 4)
                
                // 后台运行状态提示（仅在服务运行中时显示）
                if motionManager.isServiceRunning && !motionManager.backgroundStatusMessage.isEmpty {
                    HStack(spacing: 4) {
                        Text(motionManager.backgroundStatusMessage)
                            .font(.caption2)
                            .foregroundColor(motionManager.isBackgroundActive ? .green : .orange)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(motionManager.isBackgroundActive
                                  ? Color.green.opacity(0.15)
                                  : Color.orange.opacity(0.15))
                    )
                }
                
                // 主控制按钮
                Button(action: {
                    if motionManager.isServiceRunning {
                        motionManager.stopMotionUpdates()
                    } else {
                        motionManager.startMotionUpdates()
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: motionManager.isServiceRunning ? "flag.checkered.circle.fill" : "figure.run.circle.fill")
                            .font(.caption)
                        Text(motionManager.isServiceRunning
                             ? L("End Task", "结束任务")
                             : L("Start Task", "开始任务"))
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(motionManager.isServiceRunning ? .red : .blue)
                .disabled(!motionManager.isConnected)
                .clipShape(Capsule())
                
                // 打卡统计与最后动作（始终显示以维持布局，未激活时置灰）
                VStack(spacing: 8) {
                    VStack(spacing: 4) {
                        Text(L("Tasks Completed", "有效动作打卡"))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(motionManager.isServiceRunning ? .secondary : .gray)
                        
                        HStack(alignment: .lastTextBaseline, spacing: 2) {
                            Text("\(motionManager.actionCount)")
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .foregroundColor(motionManager.isServiceRunning ? .green : .gray)
                                .contentTransition(.numericText())
                            Text(L("times", "次"))
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(motionManager.isServiceRunning ? .green : .gray)
                        }
                    }
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(motionManager.isServiceRunning ? Color.green.opacity(0.1) : Color.gray.opacity(0.1))
                    )
                    
                    HStack(spacing: 4) {
                        Text(L("Last Action:", "最近判定动作:"))
                            .font(.caption2)
                            .foregroundColor(motionManager.isServiceRunning ? .gray : .secondary)
                        Text(motionManager.isServiceRunning ? motionManager.lastAction : "--")
                            .font(.caption2)
                            .bold()
                            .foregroundColor(motionManager.isServiceRunning ? .blue : .gray)
                    }
                }
                .padding(.vertical, 6)
                .opacity(motionManager.isConnected ? 1.0 : 0.4)
                
                // 调试按钮
                #if DEBUG
                Button(action: {
                    motionManager.simulateShake()
                }) {
                    Label(L("Simulate Shake", "模拟摇动"), systemImage: "waveform.path.ecg")
                        .font(.caption2)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(.purple)
                .disabled(!motionManager.isConnected)
                #endif
                
                // 断开重连提示
                if motionManager.connectionState == .failed || motionManager.connectionState == .disconnected {
                    Text(L("Keep Companion App Open", "请保持手机 App 在前台运行"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }
            }
            .padding(.horizontal, 8)
            .animation(.easeInOut, value: motionManager.isServiceRunning)
            .animation(.easeInOut, value: motionManager.connectionState)
        }
        .navigationTitle(L("Motion Tracker", "体感任务"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
