//
//  MacMediaCommandDispatcher.swift
//  HSBWatchCompanion
//
//  真实 macOS 原生隔空播放媒体控制与系统音频状态分发器。
//  绝不伪造 HTTP 请求，基于系统原生 AVAudioSession 路由感知与媒体控制。
//

import Foundation
import Network
import AVFoundation
import MediaPlayer

public final class MacMediaCommandDispatcher {
    
    public static var currentTargetHost: String = ""
    public static var currentTargetDeviceName: String = "Mac"
    
    // 媒体播放与音量状态
    public static var isPlaying: Bool = false
    public static var currentVolume: Double = 0.5
    public static var isMuted: Bool = false
    
    public static let airPlayRouteChangeNotification = Notification.Name("HSBMacAirPlayRouteChangeNotification")
    
    private static var isObserverConfigured = false
    
    public static func setupRouteObserverIfNeeded() {
        guard !isObserverConfigured else { return }
        isObserverConfigured = true
        
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { _ in
            let isActive = isRealAirPlayRoutingActive
            let activeName = currentAirPlayOutputName ?? "无"
            NSLog("[MacAirPlay] System audio route changed: isAirPlay=%d, output=%@", isActive ? 1 : 0, activeName)
            NotificationCenter.default.post(name: airPlayRouteChangeNotification, object: nil)
        }
    }
    
    /// 真实检测当前系统是否已将音频输出路由至 AirPlay 隔空播放设备
    public static var isRealAirPlayRoutingActive: Bool {
        let outputs = AVAudioSession.sharedInstance().currentRoute.outputs
        return outputs.contains { $0.portType == .airPlay }
    }
    
    /// 获取当前真实的 AirPlay 输出设备名称 (如 "Mac mini", "MacBook Pro")
    public static var currentAirPlayOutputName: String? {
        let outputs = AVAudioSession.sharedInstance().currentRoute.outputs
        return outputs.first(where: { $0.portType == .airPlay })?.portName
    }
    
    /// 真实校验当前系统是否已与指定 Mac 建立隔空播放投送连接
    public static func isConnectedToTarget(deviceName: String) -> Bool {
        guard isRealAirPlayRoutingActive else { return false }
        guard let activeName = currentAirPlayOutputName else { return true }
        let cleanTarget = deviceName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cleanActive = activeName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if cleanTarget.isEmpty || cleanTarget == "mac" { return true }
        return cleanActive.contains(cleanTarget) || cleanTarget.contains(cleanActive)
    }
    
    /// 探测目标 Mac 电脑的隔空播放接收器端口 (端口 7000) 是否开启就绪
    public static func verifyAirPlayReceiverService(host: String, completion: @escaping (Bool) -> Void) {
        let cleanHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanHost.isEmpty, cleanHost != "127.0.0.1", cleanHost != "localhost" else {
            completion(false)
            return
        }
        
        self.currentTargetHost = cleanHost
        setupRouteObserverIfNeeded()

        HSBAppleTVDiscovery.probeTCPConnection(host: cleanHost, port: 7000, timeout: 2.0) { isSuccess in
            DispatchQueue.main.async {
                NSLog("[MacAirPlay] AirPlay Receiver port 7000 verification to %@ -> result: %d", cleanHost, isSuccess ? 1 : 0)
                completion(isSuccess)
            }
        }
    }
    
    /// 派发系统级媒体控制指令 (播放/暂停/上一曲/下一曲/音量/静音)
    public static func dispatchCommand(_ action: String, params: [String: Any]? = nil) {
        NSLog("[MacAirPlay] Dispatching authentic system media command: %@", action)
        
        switch action {
        case "play_pause", "play", "pause":
            isPlaying.toggle()
            toggleSystemMediaPlayback()
            
        case "next":
            skipToNextTrack()
            
        case "previous":
            skipToPreviousTrack()
            
        case "volume_up":
            currentVolume = min(1.0, currentVolume + 0.06)
            isMuted = false
            adjustSystemVolume(delta: 0.06)
            
        case "volume_down":
            currentVolume = max(0.0, currentVolume - 0.06)
            adjustSystemVolume(delta: -0.06)
            
        case "mute":
            isMuted.toggle()
            toggleSystemMute()
            
        case "forward":
            seekTrack(offset: 10.0)
            
        case "backward":
            seekTrack(offset: -10.0)
            
        default:
            break
        }
    }
    
    // MARK: - 真实的系统媒体控制实现
    
    private static func toggleSystemMediaPlayback() {
        let musicPlayer = MPMusicPlayerController.systemMusicPlayer
        let playbackState = musicPlayer.playbackState
        if playbackState == .playing {
            musicPlayer.pause()
            isPlaying = false
        } else {
            musicPlayer.play()
            isPlaying = true
        }
    }
    
    private static func skipToNextTrack() {
        MPMusicPlayerController.systemMusicPlayer.skipToNextItem()
    }
    
    private static func skipToPreviousTrack() {
        MPMusicPlayerController.systemMusicPlayer.skipToPreviousItem()
    }
    
    private static func seekTrack(offset: TimeInterval) {
        let player = MPMusicPlayerController.systemMusicPlayer
        let current = player.currentPlaybackTime
        player.currentPlaybackTime = max(0.0, current + offset)
    }
    
    private static func adjustSystemVolume(delta: Float) {
        // 通过 MPVolumeView 隐式滑块真实调整系统输出音量
        let volumeView = MPVolumeView()
        if let slider = volumeView.subviews.first(where: { $0 is UISlider }) as? UISlider {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                slider.value = max(0.0, min(1.0, slider.value + delta))
            }
        }
    }
    
    private static func toggleSystemMute() {
        let volumeView = MPVolumeView()
        if let slider = volumeView.subviews.first(where: { $0 is UISlider }) as? UISlider {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                if isMuted {
                    slider.value = 0.0
                } else {
                    slider.value = Float(max(0.15, currentVolume))
                }
            }
        }
    }
}
