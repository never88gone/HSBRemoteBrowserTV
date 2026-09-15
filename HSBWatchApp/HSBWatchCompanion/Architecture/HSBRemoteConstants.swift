//
//  HSBRemoteConstants.swift
//  HSBWatchCompanion
//

import Foundation
import CoreGraphics

// MARK: - Extension on existing HSBRemoteMode
extension HSBRemoteMode {
    public var identifier: String {
        switch self {
        case .dual: return "dual"
        case .screenOnly: return "screenOnly"
        case .nativeOnly: return "nativeOnly"
        }
    }
}

// MARK: - D-pad & Navigation
@objc public enum DPadDirection: Int {
    case up = 0
    case down = 1
    case left = 2
    case right = 3
    
    public var actionName: String {
        switch self {
        case .up: return "up"
        case .down: return "down"
        case .left: return "left"
        case .right: return "right"
        }
    }
}

@objc public enum KeyAction: Int {
    case press = 0
    case release = 1
    case tap = 2
}

// MARK: - Touch & Mouse Gestures
@objc public enum DragState: Int {
    case began = 0
    case changed = 1
    case ended = 2
    
    public var stringValue: String {
        switch self {
        case .began: return "began"
        case .changed: return "changed"
        case .ended: return "ended"
        }
    }
}

// MARK: - Special & System Keys
@objc public enum SpecialKey: Int {
    case backspace = 0
    case enter = 1
    case escape = 2
    case space = 3
}

@objc public enum SystemKey: Int {
    case power = 0
    case home = 1
    case menu = 2
    case volumeUp = 3
    case volumeDown = 4
    case mute = 5
    case playPause = 6
    
    public var nativeButtonCode: Int64 {
        switch self {
        case .home: return 7
        case .menu: return 1
        case .playPause: return 11
        case .volumeUp: return 10
        case .volumeDown: return 9
        case .power: return 15
        case .mute: return 102
        }
    }
}

// MARK: - Page & Browser Actions
@objc public enum PageAction: Int {
    case back = 0
    case forward = 1
    case reload = 2
    case home = 3
    
    public var actionName: String {
        switch self {
        case .back: return "page_back"
        case .forward: return "page_forward"
        case .reload: return "page_reload"
        case .home: return "page_home"
        }
    }
}

// MARK: - Media Actions
@objc public enum MediaAction: Int {
    case play = 0
    case pause = 1
    case stop = 2
    case seekRelative = 3
    case seekPercent = 4
    case setRate = 5
    case toggleSubtitle = 6
    
    public var actionName: String {
        switch self {
        case .play: return "play"
        case .pause: return "pause"
        case .stop: return "stop"
        case .seekRelative: return "seek_relative"
        case .seekPercent: return "seek_percent"
        case .setRate: return "set_rate"
        case .toggleSubtitle: return "toggle_subtitle"
        }
    }
}

// MARK: - Network & Protocol Constants
public struct HSBRemoteConstants {
    public static let defaultScreenBonjourType = "_thltv._tcp"
    public static let defaultNativeCompanionBonjourType = "_companion-link._tcp"
    public static let defaultNativeAirPlayBonjourType = "_airplay._tcp"
    
    public static let screenDefaultPort: UInt16 = 56789
    public static let companionDefaultPort: UInt16 = 49152
    public static let airPlayDefaultPort: UInt16 = 7000
    
    // Scale & Tuning Constants
    public static let cursorScale: CGFloat = 5.5
    public static let scrollScale: CGFloat = 3.0
    
    // Touchpad Dimensions
    public static let virtualSpaceSize: CGFloat = 1000.0
    public static let virtualCenter = CGPoint(x: 500.0, y: 500.0)
    
    // D-pad UI Constants
    public static let dpadOuterSize: CGFloat = 150.0
    public static let dpadCenterSize: CGFloat = 75.0
    public static let visualDotSize: CGFloat = 5.0
    public static let hitTargetSize: CGFloat = 30.0
    public static let blinkOpacity: Double = 0.25
    public static let blinkDuration: TimeInterval = 0.2
}
