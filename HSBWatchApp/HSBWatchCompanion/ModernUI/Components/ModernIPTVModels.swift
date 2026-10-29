//
//  ModernIPTVModels.swift
//  HSBWatchCompanion
//

import SwiftUI
import Foundation

struct IPTVRemoteChannel: Identifiable {
    let id: String
    let name: String
    let group: String
    let number: Int?
    var isFavorite: Bool
    let programTitle: String?
    let programTimeRange: String?

    init?(payload: [String: Any]) {
        guard let id = payload[HSBRemotePayloadKeyId] as? String, !id.isEmpty,
              let name = payload[HSBRemotePayloadKeyName] as? String, !name.isEmpty else {
            return nil
        }
        self.id = id
        self.name = name
        self.group = payload[HSBRemotePayloadKeyGroup] as? String ?? ""
        self.number = payload["number"] as? Int
        self.isFavorite = payload["favorite"] as? Bool ?? false
        let program = payload["program"] as? [String: Any]
        self.programTitle = program?["title"] as? String
        self.programTimeRange = program?["timeRange"] as? String
    }
}

struct IPTVRemoteGroup: Identifiable {
    let name: String
    let count: Int
    var id: String { name }

    init?(payload: [String: Any]) {
        guard let name = payload[HSBRemotePayloadKeyName] as? String, !name.isEmpty else {
            return nil
        }
        self.name = name
        self.count = payload["count"] as? Int ?? 0
    }
}

struct IPTVCatalogScope: Hashable {
    let query: String
    let group: String
    let source: String
    let connected: Bool
}

public struct IPTVEPGBindingRequest {
    public let operation: String
    public let sourceName: String
    public let requestID: String
    public let channelID: String?
    public let epgChannelID: String?
    public let mode: String?
    public let query: String
    public let offset: Int
    public let limit: Int

    public init(operation: String, sourceName: String, requestID: String = UUID().uuidString,
                channelID: String? = nil, epgChannelID: String? = nil, mode: String? = nil,
                query: String = "", offset: Int = 0, limit: Int = 50) {
        self.operation = operation
        self.sourceName = sourceName
        self.requestID = requestID
        self.channelID = channelID
        self.epgChannelID = epgChannelID
        self.mode = mode
        self.query = query
        self.offset = offset
        self.limit = limit
    }
}

struct IPTVRemoteEPGBindingRow: Identifiable {
    let id: String
    let name: String
    let group: String
    let state: String
    let targetID: String?
    let targetName: String

    init?(payload: [String: Any]) {
        guard let id = payload["id"] as? String,
              let name = payload["name"] as? String else { return nil }
        self.id = id
        self.name = name
        self.group = payload["group"] as? String ?? ""
        self.state = payload["state"] as? String ?? "unmatched"
        self.targetID = payload["targetID"] as? String
        self.targetName = payload["targetName"] as? String ?? ""
    }

    var stateLabel: String {
        switch state {
        case "manual": return "手动匹配：\(targetName)"
        case "disabled": return "已关闭节目单"
        case "invalid": return "绑定失效：\(targetName)"
        case "matched": return "自动匹配：\(targetName)"
        case "id_unmatched": return "节目单 ID 未匹配"
        default: return "尚未匹配"
        }
    }

    var stateColor: Color {
        switch state {
        case "manual", "matched": return .secondary
        case "disabled": return .gray
        default: return .orange
        }
    }
}

struct IPTVRemoteEPGCandidate: Identifiable {
    let id: String
    let name: String
    let aliases: [String]
    let sampleProgram: String

    init?(payload: [String: Any]) {
        guard let id = payload["id"] as? String,
              let name = payload["name"] as? String else { return nil }
        self.id = id
        self.name = name
        self.aliases = payload["aliases"] as? [String] ?? []
        self.sampleProgram = payload["sampleProgram"] as? String ?? ""
    }
}

struct IPTVPlaylistImportPreview: Identifiable, Hashable {
    let requestID: String
    let sourceName: String
    let originalEntryCount: Int
    let channelCount: Int
    let filteredEntryCount: Int
    let groupCount: Int
    let sampleChannels: [String]
    let epgURLCandidate: String?
    let epgWasExplicit: Bool

    var id: String { requestID }

    init?(payload: [AnyHashable: Any]) {
        guard let requestID = payload[HSBRemotePayloadKeyRequestId] as? String,
              let sourceName = payload[HSBRemotePayloadKeyName] as? String,
              let channelCount = (payload["channelCount"] as? NSNumber)?.intValue else { return nil }
        self.requestID = requestID
        self.sourceName = sourceName
        self.originalEntryCount = (payload["originalEntryCount"] as? NSNumber)?.intValue ?? channelCount
        self.channelCount = channelCount
        self.filteredEntryCount = (payload["filteredEntryCount"] as? NSNumber)?.intValue ?? 0
        self.groupCount = (payload["groupCount"] as? NSNumber)?.intValue ?? 0
        self.sampleChannels = payload["sampleChannels"] as? [String] ?? []
        self.epgURLCandidate = payload["epgURLCandidate"] as? String
        self.epgWasExplicit = payload["epgWasExplicit"] as? Bool ?? false
    }
}

struct PendingSourceRefreshConfirmation: Identifiable {
    let requestID: String
    let sourceName: String
    let previousChannelCount: Int
    let updatedChannelCount: Int

    var id: String { requestID }
}

public struct PresetIPTVSource: Identifiable, Hashable {
    public let id: String
    public let name: String
    public let url: String
    public let epgURL: String?
    public let author: String
    public let tag: String
    public let icon: String

    public init(id: String, name: String, url: String, epgURL: String?, author: String, tag: String, icon: String) {
        self.id = id
        self.name = name
        self.url = url
        self.epgURL = epgURL
        self.author = author
        self.tag = tag
        self.icon = icon
    }
}

public let defaultPresetIPTVSources: [PresetIPTVSource] = []
