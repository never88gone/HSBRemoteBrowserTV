//
//  ModernIPTVViewModel.swift
//  HSBWatchCompanion
//

import SwiftUI
import UIKit
import Combine

final class ModernIPTVViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var selectedGroup = ""
    @Published var selectedSource = ""
    @Published var sourceNames: [String] = []
    @Published var sourceEPGCandidates: [String: String] = [:]
    @Published var isSourceManagerPresented = false
    @Published var isPlaylistFileImporterPresented = false
    @Published var isEPGFileImporterPresented = false
    @Published var importSourceName = ""
    @Published var playlistURLText = ""
    @Published var epgURLText = ""
    @Published var importStatus: String?
    @Published var pendingImportRequestID: String?
    @Published var pendingPlaylistImportPreview: IPTVPlaylistImportPreview?
    @Published var pendingSourceRefreshConfirmation: PendingSourceRefreshConfirmation?
    @Published var epgBindingsSourceName = ""
    @Published var epgBindingRows: [IPTVRemoteEPGBindingRow] = []
    @Published var epgBindingQuery = ""
    @Published var epgBindingTotal = 0
    @Published var epgBindingRequestID: String?
    @Published var epgBindingMessage: String?
    @Published var epgCandidateChannel: IPTVRemoteEPGBindingRow?
    @Published var epgCandidates: [IPTVRemoteEPGCandidate] = []
    @Published var epgCandidateQuery = ""
    @Published var epgCandidateTotal = 0
    @Published var epgCandidateRequestID: String?
    @Published var inputDigits = ""
    @Published var channels: [IPTVRemoteChannel] = []
    @Published var favorites: [IPTVRemoteChannel] = []
    @Published var groups: [IPTVRemoteGroup] = []
    @Published var total = 0
    @Published var isLoading = false
    @Published var catalogError: String?
    @Published var currentId: String?
    @Published var currentName: String?
    @Published var isPlaying = false
    @Published var wantsPlayback = false
    @Published var playbackState = "idle"
    @Published var currentIsFavorite = false

    var pendingRequestId: String?
    var requestedOffset = 0
    var playbackSessionID: String?
    var lastPlaybackSequence: Int64 = -1
    let pageSize = 100

    private let haptic = UIImpactFeedbackGenerator(style: .medium)

    var playbackSummary: String {
        switch playbackState {
        case "playing": return "正在观看"
        case "buffering": return "正在连接频道"
        case "failed": return "播放失败，可重试或换台"
        case "paused": return "已暂停"
        default: return currentName == nil ? "连接电视后即可选台" : "当前频道"
        }
    }

    func play(_ channel: IPTVRemoteChannel, onPlayChannel: ((String, String) -> Void)?) {
        haptic.impactOccurred()
        currentId = channel.id
        currentName = channel.name
        isPlaying = true
        wantsPlayback = true
        onPlayChannel?(channel.name, channel.id)
    }

    func commitDigits(isConnected: Bool, onPlayChannel: ((String, String) -> Void)?) {
        guard isConnected, !inputDigits.isEmpty else { return }
        let number = inputDigits
        inputDigits = ""
        haptic.impactOccurred()
        onPlayChannel?(number, number)
    }

    func requestCatalog(isConnected: Bool, reset: Bool, onRequestCatalog: ((String, String, Int, Int, String, String) -> Void)?) {
        guard isConnected, onRequestCatalog != nil else { return }
        if !reset && (isLoading || channels.count >= total) { return }
        let offset = reset ? 0 : channels.count
        if reset {
            channels = []
            total = 0
        }
        requestedOffset = offset
        let requestId = UUID().uuidString
        pendingRequestId = requestId
        isLoading = true
        catalogError = nil
        onRequestCatalog?(searchText.trimmingCharacters(in: .whitespacesAndNewlines), selectedGroup, offset, pageSize, selectedSource, requestId)
    }

    func receiveCatalog(isConnected: Bool, info: [AnyHashable: Any]?) {
        guard isConnected,
              let info,
              let requestId = info[HSBRemotePayloadKeyRequestId] as? String,
              requestId == pendingRequestId,
              let rawChannels = info[HSBRemotePayloadKeyChannels] as? [[String: Any]],
              let offset = info["offset"] as? Int,
              offset == requestedOffset else { return }
        let page = rawChannels.compactMap(IPTVRemoteChannel.init(payload:))
        if offset == 0 {
            channels = page
            if let rawGroups = info["groups"] as? [[String: Any]] {
                groups = rawGroups.compactMap(IPTVRemoteGroup.init(payload:))
            }
        } else {
            let existingIDs = Set(channels.map(\.id))
            channels.append(contentsOf: page.filter { !existingIDs.contains($0.id) })
        }
        total = max(channels.count, info["total"] as? Int ?? channels.count)
        if let id = info["currentId"] as? String {
            currentId = id
            if currentName == nil {
                currentName = channels.first(where: { $0.id == id })?.name
            }
        }
        pendingRequestId = nil
        isLoading = false
        catalogError = nil
    }

    func receiveState(isConnected: Bool, info: [AnyHashable: Any]?) {
        guard isConnected, let info else { return }
        if let sessionID = info["playbackSessionID"] as? String,
           let sequence = (info["playbackSequence"] as? NSNumber)?.int64Value {
            guard sequence > lastPlaybackSequence else { return }
            playbackSessionID = sessionID
            lastPlaybackSequence = sequence
        } else if playbackSessionID != nil {
            return
        }
        currentId = info[HSBRemotePayloadKeyId] as? String
        currentName = info[HSBRemotePayloadKeyName] as? String
        isPlaying = info["isPlaying"] as? Bool ?? false
        wantsPlayback = info["wantsPlayback"] as? Bool ?? isPlaying
        playbackState = info["playbackState"] as? String ?? (isPlaying ? "playing" : "idle")
        currentIsFavorite = info["isFavorite"] as? Bool ?? false
    }

    func receiveFavorites(isConnected: Bool, info: [AnyHashable: Any]?) {
        guard isConnected,
              let rawChannels = info?[HSBRemotePayloadKeyChannels] as? [[String: Any]] else { return }
        favorites = rawChannels.compactMap(IPTVRemoteChannel.init(payload:))
        let favoriteIDs = Set(favorites.map(\.id))
        channels = channels.map { channel in
            var updated = channel
            updated.isFavorite = favoriteIDs.contains(channel.id)
            return updated
        }
        if let currentId {
            currentIsFavorite = favoriteIDs.contains(currentId)
        }
    }

    func receiveSources(isConnected: Bool, info: [AnyHashable: Any]?) {
        guard isConnected, let info,
              let rawSources = info[HSBRemotePayloadKeyChannels] as? [[String: Any]] else { return }
        sourceNames = rawSources.compactMap { $0[HSBRemotePayloadKeyName] as? String }.filter { !$0.isEmpty }
        sourceEPGCandidates = Dictionary(uniqueKeysWithValues: rawSources.compactMap { source in
            guard let name = source[HSBRemotePayloadKeyName] as? String,
                  let epgURL = source["epgURL"] as? String else { return nil }
            return (name, epgURL)
        })
        let remoteSelected = info["selected"] as? String ?? ""
        if sourceNames.contains(remoteSelected) {
            selectedSource = remoteSelected
        } else if !sourceNames.contains(selectedSource) {
            selectedSource = sourceNames.first ?? ""
        }
    }

    func requestEPGBindings(isConnected: Bool, sourceName: String, offset: Int, query: String, append: Bool,
                            onEPGBindingRequest: ((IPTVEPGBindingRequest) -> Void)?) {
        guard isConnected else { return }
        if !append {
            epgBindingsSourceName = sourceName
            epgBindingRows = []
            epgBindingTotal = 0
            epgBindingMessage = nil
        }
        let request = IPTVEPGBindingRequest(
            operation: "listBindings", sourceName: sourceName,
            query: query, offset: offset, limit: 50
        )
        epgBindingRequestID = request.requestID
        onEPGBindingRequest?(request)
    }

    func requestEPGCandidates(isConnected: Bool, for channel: IPTVRemoteEPGBindingRow, sourceName: String,
                             offset: Int, query: String, append: Bool,
                             onEPGBindingRequest: ((IPTVEPGBindingRequest) -> Void)?) {
        guard isConnected else { return }
        if !append {
            epgCandidates = []
            epgCandidateTotal = 0
        }
        let request = IPTVEPGBindingRequest(
            operation: "candidates", sourceName: sourceName,
            channelID: channel.id, query: query, offset: offset, limit: 50
        )
        epgCandidateRequestID = request.requestID
        onEPGBindingRequest?(request)
    }

    func submitEPGBinding(_ request: IPTVEPGBindingRequest, onEPGBindingRequest: ((IPTVEPGBindingRequest) -> Void)?) {
        epgCandidateRequestID = UUID().uuidString
        onEPGBindingRequest?(request)
        epgBindingMessage = "正在保存匹配设置…"
    }

    func receiveEPGBindings(isConnected: Bool, info: [AnyHashable: Any]?, onRequestCatalog: ((Bool) -> Void)?) {
        guard isConnected, let info,
              (info["sourceName"] as? String) == epgBindingsSourceName else { return }
        if let requestID = info[HSBRemotePayloadKeyRequestId] as? String,
           let expectedID = epgBindingRequestID,
           requestID != expectedID { return }
        if let message = info[HSBRemotePayloadKeyMessage] as? String {
            epgBindingMessage = message
            if message == "匹配设置已保存。" {
                onRequestCatalog?(true)
            }
        }
        guard let rawRows = info[HSBRemotePayloadKeyChannels] as? [[String: Any]] else { return }
        let rows = rawRows.compactMap(IPTVRemoteEPGBindingRow.init(payload:))
        let offset = (info["offset"] as? NSNumber)?.intValue ?? 0
        if offset == 0 {
            epgBindingRows = rows
        } else {
            var merged = Dictionary(uniqueKeysWithValues: epgBindingRows.map { ($0.id, $0) })
            rows.forEach { merged[$0.id] = $0 }
            let order = epgBindingRows.map(\.id) + rows.map(\.id).filter { id in !epgBindingRows.contains(where: { $0.id == id }) }
            epgBindingRows = order.compactMap { merged[$0] }
        }
        epgBindingTotal = (info["total"] as? NSNumber)?.intValue ?? epgBindingRows.count
    }

    func receiveEPGCandidates(isConnected: Bool, info: [AnyHashable: Any]?) {
        guard isConnected, let info,
              (info["sourceName"] as? String) == epgBindingsSourceName,
              (info["channelID"] as? String) == epgCandidateChannel?.id else { return }
        if let requestID = info[HSBRemotePayloadKeyRequestId] as? String,
           let expectedID = epgCandidateRequestID,
           requestID != expectedID { return }
        guard let rawCandidates = info["candidates"] as? [[String: Any]] else { return }
        let candidates = rawCandidates.compactMap(IPTVRemoteEPGCandidate.init(payload:))
        let offset = (info["offset"] as? NSNumber)?.intValue ?? 0
        if offset == 0 {
            epgCandidates = candidates
        } else {
            var merged = Dictionary(uniqueKeysWithValues: epgCandidates.map { ($0.id, $0) })
            candidates.forEach { merged[$0.id] = $0 }
            let order = epgCandidates.map(\.id) + candidates.map(\.id).filter { id in !epgCandidates.contains(where: { $0.id == id }) }
            epgCandidates = order.compactMap { merged[$0] }
        }
        epgCandidateTotal = (info["total"] as? NSNumber)?.intValue ?? epgCandidates.count
    }

    func receiveImportResult(isConnected: Bool, info: [AnyHashable: Any]?,
                            onRequestSources: (() -> Void)?,
                            onRequestCatalog: ((Bool) -> Void)?) {
        guard isConnected, let info else { return }
        if let requestId = info[HSBRemotePayloadKeyRequestId] as? String,
           requestId != pendingImportRequestID { return }
        importStatus = info[HSBRemotePayloadKeyMessage] as? String
            ?? (info["success"] as? Bool == true ? "导入完成。" : "导入失败。")
        if info["previewRequired"] as? Bool == true,
           let preview = IPTVPlaylistImportPreview(payload: info) {
            pendingPlaylistImportPreview = preview
            pendingImportRequestID = nil
            return
        }
        if info["confirmationRequired"] as? Bool == true,
           let requestId = info[HSBRemotePayloadKeyRequestId] as? String,
           let sourceName = info[HSBRemotePayloadKeyName] as? String,
           let previousCount = (info["previousChannelCount"] as? NSNumber)?.intValue,
           let updatedCount = (info["channelCount"] as? NSNumber)?.intValue {
            pendingSourceRefreshConfirmation = PendingSourceRefreshConfirmation(
                requestID: requestId,
                sourceName: sourceName,
                previousChannelCount: previousCount,
                updatedChannelCount: updatedCount
            )
            pendingImportRequestID = nil
            return
        }
        if info["success"] as? Bool == true,
           let name = info[HSBRemotePayloadKeyName] as? String,
           !name.isEmpty {
            selectedSource = name
            onRequestSources?()
            onRequestCatalog?(true)
        }
        pendingImportRequestID = nil
    }

    func submitPlaylistURL(onImportSource: ((String, String, String?, String) -> Void)?) {
        let url = playlistURLText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isHTTPURL(url) else { return }
        let epgURL = epgURLText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard epgURL.isEmpty || isHTTPURL(epgURL) else {
            importStatus = "节目单地址必须是有效的 HTTP 或 HTTPS 地址。"
            return
        }
        let requestId = UUID().uuidString
        pendingImportRequestID = requestId
        importStatus = "正在电视上验证并导入频道源…"
        var name = importSourceName.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty {
            if let matched = defaultPresetIPTVSources.first(where: { $0.url == url }) {
                name = matched.name
            } else if let host = URL(string: url)?.host {
                name = host
            } else {
                name = "频道源"
            }
        }
        onImportSource?(name, url, epgURL.isEmpty ? nil : epgURL, requestId)
    }

    func submitEPGURL(onImportEPG: ((String, String, String) -> Void)?) {
        let url = epgURLText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isHTTPURL(url) else { return }
        guard sourceNames.contains(selectedSource), !selectedSource.isEmpty else {
            importStatus = "请先选择要关联的频道源。"
            return
        }
        let requestId = UUID().uuidString
        pendingImportRequestID = requestId
        importStatus = "正在电视上导入节目单…"
        onImportEPG?(selectedSource, url, requestId)
    }

    func importEPGCandidate(for source: String, onImportEPG: ((String, String, String) -> Void)?) {
        guard let candidate = sourceEPGCandidates[source], isHTTPURL(candidate) else { return }
        selectedSource = source
        epgURLText = candidate
        submitEPGURL(onImportEPG: onImportEPG)
    }

    func refreshSource(_ name: String, onRefreshSource: ((String, String) -> Void)?) {
        let requestId = UUID().uuidString
        pendingImportRequestID = requestId
        importStatus = "正在刷新 \(name)…"
        onRefreshSource?(name, requestId)
    }

    func handleFileImport(_ result: Result<URL, Error>, type: String, onImportFile: ((String, String, Data, String) -> Void)?) {
        do {
            let url = try result.get()
            let requestId = UUID().uuidString
            pendingImportRequestID = requestId
            importStatus = "正在读取文件…"
            let trimmedName = importSourceName.trimmingCharacters(in: .whitespacesAndNewlines)
            let name: String
            if type == "epg" {
                guard sourceNames.contains(selectedSource), !selectedSource.isEmpty else {
                    importStatus = "请先选择要关联的频道源。"
                    pendingImportRequestID = nil
                    return
                }
                name = selectedSource
            } else {
                name = trimmedName.isEmpty ? url.deletingPathExtension().lastPathComponent : trimmedName
            }
            let hasAccess = url.startAccessingSecurityScopedResource()
            Task {
                defer { if hasAccess { url.stopAccessingSecurityScopedResource() } }
                do {
                    let data = try await Task.detached(priority: .userInitiated) {
                        try Data(contentsOf: url, options: .mappedIfSafe)
                    }.value
                    let maximum = 32 * 1024 * 1024
                    guard data.count <= maximum else {
                        await MainActor.run {
                            importStatus = "文件超过大小限制。"
                            pendingImportRequestID = nil
                        }
                        return
                    }
                    await MainActor.run {
                        importStatus = "正在传输文件到电视…"
                        onImportFile?(type, name, data, requestId)
                    }
                } catch {
                    await MainActor.run {
                        importStatus = "文件读取失败：\(error.localizedDescription)"
                        pendingImportRequestID = nil
                    }
                }
            }
        } catch {
            importStatus = "文件选择失败：\(error.localizedDescription)"
        }
    }

    func resetConnectionData() {
        channels = []
        favorites = []
        groups = []
        sourceNames = []
        sourceEPGCandidates = [:]
        selectedSource = ""
        total = 0
        pendingRequestId = nil
        isLoading = false
        catalogError = nil
        currentId = nil
        currentName = nil
        isPlaying = false
        wantsPlayback = false
        playbackState = "idle"
        playbackSessionID = nil
        lastPlaybackSequence = -1
        currentIsFavorite = false
        inputDigits = ""
        pendingImportRequestID = nil
        pendingPlaylistImportPreview = nil
        pendingSourceRefreshConfirmation = nil
        epgBindingsSourceName = ""
        epgBindingRows = []
        epgBindingQuery = ""
        epgBindingTotal = 0
        epgBindingRequestID = nil
        epgBindingMessage = nil
        epgCandidateChannel = nil
        epgCandidates = []
        epgCandidateQuery = ""
        epgCandidateTotal = 0
        epgCandidateRequestID = nil
    }
}
