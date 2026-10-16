//
//  CompanionSessionTypes.swift
//  HSBWatchCompanion
//

import Foundation

// MARK: - Delegate

/// Callbacks from `CompanionSession` to its owner (`CompanionConnection`).
/// All calls are dispatched to the main queue before firing.
@MainActor
public protocol CompanionSessionDelegate: AnyObject {
    func sessionDidUpdateNowPlaying(_ info: CompanionNowPlayingUpdate)
    func sessionDidChangeKeyboardActive(_ active: Bool, data: Data?)
    func sessionDidUpdateAttentionState(_ state: Int)
    func sessionDidReadError(_ message: String, epoch: Int)
    func sessionDidClose(epoch: Int)
    func sessionDidConfirmStart()
    func sessionDidReceivePairingFrame(_ frame: CompanionFrame)
    func sessionDidFetchApps(_ apps: [(id: String, name: String)])
}

// MARK: - CompanionNowPlayingUpdate

/// Raw now-playing key/value map as received from an `_iMC` push, passed
/// straight through to `CompanionConnection` for merging into `NowPlayingInfo`.
public struct CompanionNowPlayingUpdate {
    public let inner: [String: Any]
    public init(_ inner: [String: Any]) { self.inner = inner }
}

// MARK: - Errors

public enum CompanionError: LocalizedError {
    case unexpectedResponse
    case notConnected
    public var errorDescription: String? {
        switch self {
        case .unexpectedResponse: return "Unexpected response from Apple TV"
        case .notConnected:       return "Not connected to Apple TV"
        }
    }
}

public enum TextInputError: LocalizedError {
    case notConnected
    case noActiveTextField
    case sessionUUIDMissing

    public var errorDescription: String? {
        switch self {
        case .notConnected:       return "Not connected to an Apple TV"
        case .noActiveTextField:  return "No text input active on Apple TV"
        case .sessionUUIDMissing: return "Text input session UUID missing from ATV response"
        }
    }
}
