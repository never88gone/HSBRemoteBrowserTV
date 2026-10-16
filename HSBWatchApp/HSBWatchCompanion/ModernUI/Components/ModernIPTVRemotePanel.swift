//
//  ModernIPTVRemotePanel.swift
//  HSBWatchCompanion
//

import SwiftUI

public struct ModernIPTVRemotePanel: View {
    public let isConnected: Bool
    
    public init(isConnected: Bool) {
        self.isConnected = isConnected
    }
    
    public var body: some View {
        ModernIPTVControlView(
            isConnected: isConnected,
            onAction: { action in
                handleAction(action)
            },
            onPlayChannel: { name, channelId in
                handlePlayChannel(name: name, channelId: channelId)
            },
            onRequestCatalog: { query, group, offset, limit, source, requestId in
                HSBTVOSConnectionManager.shared().sendPayload([
                    HSBRemotePayloadKeyAction: HSBRemoteSimulateAction.iptvChannels.rawValue,
                    "request": "catalog",
                    "query": query,
                    "group": group,
                    "offset": offset,
                    "limit": limit,
                    "source": source,
                    HSBRemotePayloadKeyRequestId: requestId
                ])
            },
            onFavoriteChange: { channelId, shouldFavorite in
                HSBTVOSConnectionManager.shared().sendPayload([
                    HSBRemotePayloadKeyAction: shouldFavorite
                        ? HSBRemoteSimulateAction.iptvAddFavorite.rawValue
                        : HSBRemoteSimulateAction.iptvDeleteFavorite.rawValue,
                    HSBRemotePayloadKeyId: channelId
                ])
            },
            onImportSource: { name, url, epgURL, requestId in
                var payload: [String: Any] = [
                    HSBRemotePayloadKeyAction: HSBRemoteSimulateAction.iptvImportSource.rawValue,
                    HSBRemotePayloadKeyName: name,
                    HSBRemotePayloadKeyUrl: url,
                    HSBRemotePayloadKeyRequestId: requestId
                ]
                if let epgURL, !epgURL.isEmpty { payload["epgURL"] = epgURL }
                HSBTVOSConnectionManager.shared().sendPayload(payload)
            },
            onImportEPG: { sourceName, url, requestId in
                HSBTVOSConnectionManager.shared().sendPayload([
                    HSBRemotePayloadKeyAction: HSBRemoteSimulateAction.iptvImportEPG.rawValue,
                    HSBRemotePayloadKeyUrl: url,
                    "sourceName": sourceName,
                    HSBRemotePayloadKeyRequestId: requestId
                ])
            },
            onImportFile: { type, name, data, requestId in
                handleImportFile(type: type, name: name, data: data, requestId: requestId)
            },
            onRequestSources: {
                HSBTVOSConnectionManager.shared().sendSimulateAction(.iptvGetSources)
            },
            onDeleteSource: { name in
                HSBTVOSConnectionManager.shared().sendSimulateAction(.iptvDeleteSource, withParams: [
                    HSBRemotePayloadKeyName: name
                ])
            },
            onRefreshSource: { name, requestId in
                HSBTVOSConnectionManager.shared().sendSimulateAction(.iptvRefreshSource, withParams: [
                    HSBRemotePayloadKeyName: name,
                    HSBRemotePayloadKeyRequestId: requestId
                ])
            },
            onConfirmSourceRefresh: { requestId, approved in
                HSBTVOSConnectionManager.shared().sendSimulateAction(.iptvRefreshSource, withParams: [
                    HSBRemotePayloadKeyRequestId: requestId,
                    "confirmRefresh": approved
                ])
            },
            onEPGBindingRequest: { request in
                var payload: [String: Any] = [
                    HSBRemotePayloadKeyAction: HSBRemoteSimulateAction.iptvImportEPG.rawValue,
                    "operation": request.operation,
                    "sourceName": request.sourceName,
                    HSBRemotePayloadKeyRequestId: request.requestID,
                    "query": request.query,
                    "offset": request.offset,
                    "limit": request.limit
                ]
                if let channelID = request.channelID { payload["channelID"] = channelID }
                if let epgChannelID = request.epgChannelID { payload["epgChannelID"] = epgChannelID }
                if let mode = request.mode { payload["mode"] = mode }
                HSBTVOSConnectionManager.shared().sendPayload(payload)
            },
            onConfirmPlaylistImport: { requestId, approved, includeEPG in
                HSBTVOSConnectionManager.shared().sendPayload([
                    HSBRemotePayloadKeyAction: HSBRemoteSimulateAction.iptvImportSource.rawValue,
                    HSBRemotePayloadKeyRequestId: requestId,
                    "confirmImport": approved,
                    "includeEPG": includeEPG
                ])
            }
        )
    }
    
    private func handleAction(_ action: HSBRemoteSimulateAction) {
        switch action {
        case .channelUp, .up:
            DualModeRemoteCoordinator.shared.sendDPad(direction: .up, action: .tap)
        case .channelDown, .down:
            DualModeRemoteCoordinator.shared.sendDPad(direction: .down, action: .tap)
        case .left:
            DualModeRemoteCoordinator.shared.sendDPad(direction: .left, action: .tap)
        case .right:
            DualModeRemoteCoordinator.shared.sendDPad(direction: .right, action: .tap)
        case .select:
            DualModeRemoteCoordinator.shared.sendSelect(action: .tap)
        case .volumeUp:
            DualModeRemoteCoordinator.shared.sendSystemKey(.volumeUp)
        case .volumeDown:
            DualModeRemoteCoordinator.shared.sendSystemKey(.volumeDown)
        case .toggleMute:
            DualModeRemoteCoordinator.shared.sendSystemKey(.mute)
        case .play, .pause:
            DualModeRemoteCoordinator.shared.sendSystemKey(.playPause)
        case .iptvEpg, .menu:
            DualModeRemoteCoordinator.shared.sendSystemKey(.menu)
        default:
            break
        }
        if HSBTVOSConnectionManager.shared().isConnected {
            HSBTVOSConnectionManager.shared().sendSimulateAction(action)
        }
    }
    
    private func handlePlayChannel(name: String, channelId: String) {
        let encodedName = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name
        let url = "thliptv://play?id=\(channelId)&name=\(encodedName)"
        DualModeRemoteCoordinator.shared.launchApp(bundleID: "com.nevergone.huluge.iptv", url: url)
        if HSBTVOSConnectionManager.shared().isConnected {
            HSBTVOSConnectionManager.shared().sendPayload([
                HSBRemotePayloadKeyAction: HSBRemoteSimulateAction.iptvPlayChannel.rawValue,
                HSBRemotePayloadKeyChannel: name,
                HSBRemotePayloadKeyId: channelId
            ])
        }
    }
    
    private func handleImportFile(type: String, name: String, data: Data, requestId: String) {
        guard !data.isEmpty else { return }
        let chunkSize = 128 * 1024
        let chunkCount = (data.count + chunkSize - 1) / chunkSize
        Task.detached(priority: .userInitiated) {
            for index in 0..<chunkCount {
                let lower = index * chunkSize
                let upper = min(lower + chunkSize, data.count)
                let chunk = data.subdata(in: lower..<upper).base64EncodedString()
                HSBTVOSConnectionManager.shared().sendPayload([
                    HSBRemotePayloadKeyAction: HSBRemoteSimulateAction.iptvFileChunk.rawValue,
                    HSBRemotePayloadKeyRequestId: requestId,
                    "fileType": type,
                    HSBRemotePayloadKeyName: name,
                    "index": index,
                    "chunkCount": chunkCount,
                    "data": chunk
                ])
                try? await Task.sleep(for: .milliseconds(12))
            }
        }
    }
}
