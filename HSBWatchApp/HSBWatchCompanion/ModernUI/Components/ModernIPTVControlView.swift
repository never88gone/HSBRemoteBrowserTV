//
//  ModernIPTVControlView.swift
//  HSBWatchCompanion
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

private struct IPTVRemoteChannel: Identifiable {
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

private struct IPTVRemoteGroup: Identifiable {
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

private struct IPTVCatalogScope: Hashable {
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

private struct IPTVRemoteEPGBindingRow: Identifiable {
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

private struct IPTVRemoteEPGCandidate: Identifiable {
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

private struct IPTVPlaylistImportPreview: Identifiable, Hashable {
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

public struct ModernIPTVControlView: View {
    public let isConnected: Bool
    public var onAction: ((HSBRemoteSimulateAction) -> Void)?
    public var onPlayChannel: ((String, String) -> Void)?
    public var onRequestCatalog: ((String, String, Int, Int, String, String) -> Void)?
    public var onFavoriteChange: ((String, Bool) -> Void)?
    public var onImportSource: ((String, String, String?, String) -> Void)?
    public var onImportEPG: ((String, String, String) -> Void)?
    public var onImportFile: ((String, String, Data, String) -> Void)?
    public var onRequestSources: (() -> Void)?
    public var onDeleteSource: ((String) -> Void)?
    public var onRefreshSource: ((String, String) -> Void)?
    public var onConfirmSourceRefresh: ((String, Bool) -> Void)?
    public var onEPGBindingRequest: ((IPTVEPGBindingRequest) -> Void)?
    public var onConfirmPlaylistImport: ((String, Bool, Bool) -> Void)?

    @State private var searchText = ""
    @State private var selectedGroup = ""
    @State private var selectedSource = ""
    @State private var sourceNames: [String] = []
    @State private var sourceEPGCandidates: [String: String] = [:]
    @State private var sourcePendingDeletion: String?
    @State private var isDeleteConfirmationPresented = false
    @State private var isSourceManagerPresented = false
    @State private var isPlaylistFileImporterPresented = false
    @State private var isEPGFileImporterPresented = false
    @State private var importSourceName = ""
    @State private var playlistURLText = ""
    @State private var epgURLText = ""
    @State private var importStatus: String?
    @State private var pendingImportRequestID: String?
    @State private var pendingPlaylistImportPreview: IPTVPlaylistImportPreview?
    @State private var includeEPGInPlaylistImport = false
    @State private var pendingSourceRefreshConfirmation: PendingSourceRefreshConfirmation?
    @State private var epgBindingsSourceName = ""
    @State private var epgBindingRows: [IPTVRemoteEPGBindingRow] = []
    @State private var epgBindingQuery = ""
    @State private var epgBindingTotal = 0
    @State private var epgBindingRequestID: String?
    @State private var epgBindingMessage: String?
    @State private var epgCandidateChannel: IPTVRemoteEPGBindingRow?
    @State private var epgCandidates: [IPTVRemoteEPGCandidate] = []
    @State private var epgCandidateQuery = ""
    @State private var epgCandidateTotal = 0
    @State private var epgCandidateRequestID: String?
    @State private var inputDigits = ""
    @State private var channels: [IPTVRemoteChannel] = []
    @State private var favorites: [IPTVRemoteChannel] = []
    @State private var groups: [IPTVRemoteGroup] = []
    @State private var total = 0
    @State private var isLoading = false
    @State private var catalogError: String?
    @State private var pendingRequestId: String?
    @State private var requestedOffset = 0
    @State private var currentId: String?
    @State private var currentName: String?
    @State private var isPlaying = false
    @State private var wantsPlayback = false
    @State private var playbackState = "idle"
    @State private var playbackSessionID: String?
    @State private var lastPlaybackSequence: Int64 = -1
    @State private var currentIsFavorite = false

    private let pageSize = 100
    private let haptic = UIImpactFeedbackGenerator(style: .medium)
    private let lightHaptic = UIImpactFeedbackGenerator(style: .light)

    public init(
        isConnected: Bool = false,
        onAction: ((HSBRemoteSimulateAction) -> Void)? = nil,
        onPlayChannel: ((String, String) -> Void)? = nil,
        onRequestCatalog: ((String, String, Int, Int, String, String) -> Void)? = nil,
        onFavoriteChange: ((String, Bool) -> Void)? = nil,
        onImportSource: ((String, String, String?, String) -> Void)? = nil,
        onImportEPG: ((String, String, String) -> Void)? = nil,
        onImportFile: ((String, String, Data, String) -> Void)? = nil,
        onRequestSources: (() -> Void)? = nil,
        onDeleteSource: ((String) -> Void)? = nil,
        onRefreshSource: ((String, String) -> Void)? = nil,
        onConfirmSourceRefresh: ((String, Bool) -> Void)? = nil,
        onEPGBindingRequest: ((IPTVEPGBindingRequest) -> Void)? = nil,
        onConfirmPlaylistImport: ((String, Bool, Bool) -> Void)? = nil
    ) {
        self.isConnected = isConnected
        self.onAction = onAction
        self.onPlayChannel = onPlayChannel
        self.onRequestCatalog = onRequestCatalog
        self.onFavoriteChange = onFavoriteChange
        self.onImportSource = onImportSource
        self.onImportEPG = onImportEPG
        self.onImportFile = onImportFile
        self.onRequestSources = onRequestSources
        self.onDeleteSource = onDeleteSource
        self.onRefreshSource = onRefreshSource
        self.onConfirmSourceRefresh = onConfirmSourceRefresh
        self.onEPGBindingRequest = onEPGBindingRequest
        self.onConfirmPlaylistImport = onConfirmPlaylistImport
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                nowPlayingCard
                channelAndVolumeControls
                actionBar
                sourceManagementButton
                favoritesSection
                channelDirectory
                numberPad
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .onAppear {
            if isConnected {
                onAction?(.iptvGetFavorites)
                onRequestSources?()
            }
        }
        .onChange(of: isConnected) { _, connected in
            if connected {
                onAction?(.iptvGetFavorites)
                onRequestSources?()
            } else {
                resetConnectionData()
            }
        }
        .task(id: IPTVCatalogScope(query: searchText, group: selectedGroup, source: selectedSource, connected: isConnected)) {
            guard isConnected else { return }
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            requestCatalog(reset: true)
        }
        .task(id: pendingRequestId) {
            guard let requestId = pendingRequestId else { return }
            try? await Task.sleep(for: .seconds(8))
            guard !Task.isCancelled, pendingRequestId == requestId else { return }
            pendingRequestId = nil
            isLoading = false
            catalogError = "读取频道超时，请重试。"
        }
        .task(id: pendingImportRequestID) {
            guard let requestId = pendingImportRequestID else { return }
            try? await Task.sleep(for: .seconds(90))
            guard !Task.isCancelled, pendingImportRequestID == requestId else { return }
            pendingImportRequestID = nil
            importStatus = "电视未返回导入结果，请检查连接后重试。"
        }
        .task(id: inputDigits) {
            guard !inputDigits.isEmpty else { return }
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            commitDigits()
        }
        .onReceive(NotificationCenter.default.publisher(for: .HSBIPTVCatalogUpdated)) {
            receiveCatalog($0.userInfo)
        }
        .onReceive(NotificationCenter.default.publisher(for: .HSBIPTVStateUpdated)) {
            receiveState($0.userInfo)
        }
        .onReceive(NotificationCenter.default.publisher(for: .HSBIPTVFavoritesUpdated)) {
            receiveFavorites($0.userInfo)
        }
        .onReceive(NotificationCenter.default.publisher(for: .HSBIPTVImportResultUpdated)) {
            receiveImportResult($0.userInfo)
        }
        .onReceive(NotificationCenter.default.publisher(for: .HSBIPTVSourcesUpdated)) {
            receiveSources($0.userInfo)
        }
        .onReceive(NotificationCenter.default.publisher(for: .HSBIPTVEPGBindingsUpdated)) {
            receiveEPGBindings($0.userInfo)
        }
        .onReceive(NotificationCenter.default.publisher(for: .HSBIPTVEPGCandidatesUpdated)) {
            receiveEPGCandidates($0.userInfo)
        }
        .sheet(isPresented: $isSourceManagerPresented) {
            sourceManagerSheet
        }
        .fileImporter(isPresented: $isPlaylistFileImporterPresented, allowedContentTypes: playlistContentTypes) {
            handleFileImport($0, type: "playlist")
        }
        .fileImporter(isPresented: $isEPGFileImporterPresented, allowedContentTypes: epgContentTypes) {
            handleFileImport($0, type: "epg")
        }
    }

    private var nowPlayingCard: some View {
        HStack(spacing: 12) {
            Image(systemName: isPlaying ? "play.tv.fill" : "tv")
                .font(.title2)
                .foregroundStyle(Color.accentColor)
                .frame(width: 44, height: 44)
                .background(Color.accentColor.opacity(0.13), in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 4) {
                Text(isConnected ? playbackSummary : "未连接电视")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(currentName ?? (isConnected ? "请从频道目录选台" : "连接电视后即可选台"))
                    .font(.headline)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Button {
                guard let currentId else { return }
                lightHaptic.impactOccurred()
                onFavoriteChange?(currentId, !currentIsFavorite)
            } label: {
                Image(systemName: currentIsFavorite ? "heart.fill" : "heart")
                    .font(.title3)
                    .foregroundStyle(currentIsFavorite ? Color.pink : Color.secondary)
                    .frame(width: 44, height: 44)
            }
            .disabled(currentId == nil || !isConnected)
            .accessibilityLabel(currentIsFavorite ? "取消收藏当前频道" : "收藏当前频道")
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
    }

    private var channelAndVolumeControls: some View {
        HStack(spacing: 12) {
            controlTower(
                title: "频道 CH", upperIcon: "chevron.up", upperLabel: "频道加",
                lowerIcon: "chevron.down", lowerLabel: "频道减",
                upperAction: { onAction?(.channelUp) }, lowerAction: { onAction?(.channelDown) }
            )
            controlTower(
                title: "音量 VOL", upperIcon: "speaker.plus.fill", upperLabel: "音量加",
                lowerIcon: "speaker.minus.fill", lowerLabel: "音量减",
                upperAction: { onAction?(.volumeUp) }, lowerAction: { onAction?(.volumeDown) }
            )
        }
    }

    private func controlTower(
        title: String, upperIcon: String, upperLabel: String,
        lowerIcon: String, lowerLabel: String,
        upperAction: @escaping () -> Void, lowerAction: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 8) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            Button {
                haptic.impactOccurred()
                upperAction()
            } label: {
                Image(systemName: upperIcon).frame(maxWidth: .infinity, minHeight: 52)
            }
            .buttonStyle(TowerButtonStyle())
            .accessibilityLabel(upperLabel)
            Button {
                haptic.impactOccurred()
                lowerAction()
            } label: {
                Image(systemName: lowerIcon).frame(maxWidth: .infinity, minHeight: 52)
            }
            .buttonStyle(TowerButtonStyle())
            .accessibilityLabel(lowerLabel)
        }
        .font(.title3.weight(.bold))
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
        .disabled(!isConnected)
    }

    private var actionBar: some View {
        HStack(spacing: 8) {
            actionButton("静音", icon: "speaker.slash.fill") { onAction?(.toggleMute) }
            actionButton(wantsPlayback ? "暂停" : "播放", icon: wantsPlayback ? "pause.fill" : "play.fill") {
                onAction?(wantsPlayback ? .pause : .play)
            }
            actionButton("节目单", icon: "list.bullet.rectangle") { onAction?(.iptvEpg) }
            actionButton("电视列表", icon: "rectangle.stack") { onAction?(.iptvChannels) }
            actionButton("刷新", icon: "arrow.clockwise") {
                onAction?(.iptvRefresh)
                requestCatalog(reset: true)
            }
        }
        .disabled(!isConnected)
    }

    private var sourceManagementButton: some View {
        Button {
            onRequestSources?()
            importStatus = nil
            isSourceManagerPresented = true
        } label: {
            Label("管理频道源与节目单", systemImage: "square.and.arrow.down")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(!isConnected)
    }

    private var sourceManagerSheet: some View {
        NavigationStack {
            Form {
                Section("导入频道源") {
                    TextField("来源名称", text: $importSourceName)
                        .textInputAutocapitalization(.words)
                    TextField("M3U / M3U8 地址", text: $playlistURLText)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("XMLTV EPG 地址（可选）", text: $epgURLText)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button("检查并预览频道") { submitPlaylistURL() }
                        .disabled(!isConnected || !isHTTPURL(playlistURLText))
                    Button("从文件选择 M3U / M3U8") { isPlaylistFileImporterPresented = true }
                        .disabled(!isConnected)
                }

                Section("单独导入节目单") {
                    Picker("关联频道源", selection: $selectedSource) {
                        Text("请选择频道源").tag("")
                        ForEach(sourceNames, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }
                    TextField("XMLTV / XMLTV.GZ 地址", text: $epgURLText)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button("导入节目单网址") { submitEPGURL() }
                        .disabled(!isConnected || selectedSource.isEmpty || !isHTTPURL(epgURLText))
                    Button("从文件选择 XMLTV") { isEPGFileImporterPresented = true }
                        .disabled(!isConnected || selectedSource.isEmpty)
                }

                Section("已导入来源") {
                    if sourceNames.isEmpty {
                        Text("电视上还没有可管理的频道源。")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(sourceNames, id: \.self) { name in
                        HStack(spacing: 8) {
                            Button {
                                selectedSource = name
                                isSourceManagerPresented = false
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(name)
                                    if selectedSource == name {
                                        Text("当前频道源").font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                            if sourceEPGCandidates[name].map(isHTTPURL) == true {
                                Button {
                                    importEPGCandidate(for: name)
                                } label: {
                                    Image(systemName: "calendar.badge.plus")
                                }
                                .accessibilityLabel("导入 \(name) 声明的节目单")
                            }
                            NavigationLink {
                                epgBindingList(sourceName: name)
                            } label: {
                                Image(systemName: "arrow.left.arrow.right")
                            }
                            .accessibilityLabel("管理 \(name) 的节目单匹配")
                            Button { refreshSource(name) } label: {
                                Image(systemName: "arrow.clockwise")
                            }
                            .accessibilityLabel("刷新 \(name)")
                            Button(role: .destructive) {
                                sourcePendingDeletion = name
                                isDeleteConfirmationPresented = true
                            } label: {
                                Image(systemName: "trash")
                            }
                            .accessibilityLabel("删除 \(name)")
                        }
                    }
                }

                if let importStatus {
                    Section("导入状态") {
                        Text(importStatus)
                            .foregroundStyle(importStatus.contains("失败") ? .red : .secondary)
                    }
                }
            }
            .navigationTitle("IPTV 来源")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(item: $pendingPlaylistImportPreview) { preview in
                playlistImportPreview(preview)
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { isSourceManagerPresented = false }
                }
            }
            .onAppear { onRequestSources?() }
        }
        .confirmationDialog(
            "删除频道源？",
            isPresented: $isDeleteConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("删除 \(sourcePendingDeletion ?? "")", role: .destructive) {
                if let sourcePendingDeletion { onDeleteSource?(sourcePendingDeletion) }
                sourcePendingDeletion = nil
            }
            Button("取消", role: .cancel) { sourcePendingDeletion = nil }
        } message: {
            Text("此来源会从电视目录中移除，依赖它的收藏或历史可能变为不可用。")
        }
        .alert(item: $pendingSourceRefreshConfirmation) { confirmation in
            Alert(
                title: Text("频道列表减少较多"),
                message: Text("“\(confirmation.sourceName)”将从 \(confirmation.previousChannelCount) 个频道变为 \(confirmation.updatedChannelCount) 个。确认后才会替换现有列表。"),
                primaryButton: .destructive(Text("确认替换")) {
                    pendingImportRequestID = confirmation.requestID
                    importStatus = "正在应用频道列表更新…"
                    onConfirmSourceRefresh?(confirmation.requestID, true)
                },
                secondaryButton: .cancel(Text("保留旧目录")) {
                    pendingImportRequestID = confirmation.requestID
                    importStatus = "正在保留原频道列表…"
                    onConfirmSourceRefresh?(confirmation.requestID, false)
                }
            )
        }
        .presentationDetents([.large])
    }

    private func playlistImportPreview(_ preview: IPTVPlaylistImportPreview) -> some View {
        List {
            Section("频道源预览") {
                LabeledContent("来源", value: preview.sourceName)
                LabeledContent("原始条目", value: "\(preview.originalEntryCount)")
                LabeledContent("有效频道", value: "\(preview.channelCount)")
                LabeledContent("未解析或重复", value: "\(preview.filteredEntryCount)")
                LabeledContent("分组", value: "\(preview.groupCount)")
            }
            if let candidate = preview.epgURLCandidate {
                Section("发现节目单") {
                    Text(epgHostSummary(candidate))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Toggle("同时导入节目单", isOn: $includeEPGInPlaylistImport)
                }
            }
            Section("频道样例（最多 20 个）") {
                if preview.sampleChannels.isEmpty {
                    Text("没有可预览的频道。").foregroundStyle(.secondary)
                }
                ForEach(Array(preview.sampleChannels.enumerated()), id: \.offset) { index, name in
                    HStack(spacing: 10) {
                        Text("\(index + 1)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 28, alignment: .trailing)
                        Text(name).lineLimit(2)
                    }
                }
            }
            Section {
                Button("确认导入 \(preview.channelCount) 个频道") {
                    pendingImportRequestID = preview.requestID
                    importStatus = "正在电视上保存频道源…"
                    onConfirmPlaylistImport?(preview.requestID, true, includeEPGInPlaylistImport)
                    pendingPlaylistImportPreview = nil
                }
                .disabled(!isConnected || preview.channelCount == 0)
                Button("取消导入", role: .destructive) {
                    pendingImportRequestID = preview.requestID
                    importStatus = "正在取消导入…"
                    onConfirmPlaylistImport?(preview.requestID, false, false)
                    pendingPlaylistImportPreview = nil
                }
                .disabled(!isConnected)
            }
        }
        .navigationTitle("确认导入")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { includeEPGInPlaylistImport = preview.epgWasExplicit }
    }

    private var playlistContentTypes: [UTType] {
        [UTType(filenameExtension: "m3u") ?? .plainText,
         UTType(filenameExtension: "m3u8") ?? .plainText]
    }

    private var epgContentTypes: [UTType] {
        [UTType(filenameExtension: "xml") ?? .xml,
         UTType(filenameExtension: "xmltv") ?? .xml,
         UTType(filenameExtension: "gz") ?? .gzip]
    }

    private func actionButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button {
            lightHaptic.impactOccurred()
            action()
        } label: {
            VStack(spacing: 5) {
                Image(systemName: icon).font(.body)
                Text(title).font(.caption2).lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    private var playbackSummary: String {
        switch playbackState {
        case "playing": return "正在观看"
        case "buffering": return "正在连接频道"
        case "failed": return "播放失败，可重试或换台"
        case "paused": return "已暂停"
        default: return currentName == nil ? "连接电视后即可选台" : "当前频道"
        }
    }

    private func epgBindingList(sourceName: String) -> some View {
        List {
            if let epgBindingMessage, !epgBindingMessage.isEmpty {
                Text(epgBindingMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if epgBindingRows.isEmpty && epgBindingMessage == nil {
                ProgressView("正在读取频道匹配…")
            }
            ForEach(epgBindingRows) { row in
                NavigationLink {
                    epgCandidatePicker(for: row, sourceName: sourceName)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(row.name).font(.body)
                        Text(row.stateLabel)
                            .font(.caption)
                            .foregroundColor(row.stateColor)
                        if !row.group.isEmpty {
                            Text(row.group).font(.caption2).foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.vertical, 3)
                }
            }
            if epgBindingRows.count < epgBindingTotal {
                Button("加载更多频道（\(epgBindingRows.count)/\(epgBindingTotal)）") {
                    requestEPGBindings(sourceName: sourceName, offset: epgBindingRows.count, query: epgBindingQuery, append: true)
                }
            }
        }
        .navigationTitle("节目单匹配")
        .searchable(text: $epgBindingQuery, prompt: "搜索频道")
        .onAppear {
            if selectedSource != sourceName { selectedSource = sourceName }
            if epgBindingsSourceName != sourceName || epgBindingRows.isEmpty {
                requestEPGBindings(sourceName: sourceName, offset: 0, query: epgBindingQuery, append: false)
            }
        }
        .onChange(of: epgBindingQuery) { _, query in
            Task {
                try? await Task.sleep(for: .milliseconds(250))
                guard query == epgBindingQuery else { return }
                requestEPGBindings(sourceName: sourceName, offset: 0, query: query, append: false)
            }
        }
    }

    private func epgCandidatePicker(for channel: IPTVRemoteEPGBindingRow, sourceName: String) -> some View {
        List {
            Section("当前状态") {
                Text(channel.name).font(.headline)
                Text(channel.stateLabel).font(.subheadline).foregroundStyle(.secondary)
                Button("恢复自动匹配") {
                    submitEPGBinding(IPTVEPGBindingRequest(
                        operation: "setBinding", sourceName: sourceName, channelID: channel.id, mode: "automatic"
                    ))
                }
                Button("关闭此频道节目单", role: .destructive) {
                    submitEPGBinding(IPTVEPGBindingRequest(
                        operation: "setBinding", sourceName: sourceName, channelID: channel.id, mode: "disable"
                    ))
                }
            }
            Section("选择节目单频道") {
                if let epgBindingMessage, !epgBindingMessage.isEmpty {
                    Text(epgBindingMessage).font(.footnote).foregroundStyle(.secondary)
                }
                if epgCandidates.isEmpty {
                    Text(epgCandidateQuery.isEmpty ? "没有可匹配的节目频道。" : "没有找到匹配结果。")
                        .foregroundStyle(.secondary)
                }
                ForEach(epgCandidates) { candidate in
                    Button {
                        submitEPGBinding(IPTVEPGBindingRequest(
                            operation: "setBinding", sourceName: sourceName,
                            channelID: channel.id, epgChannelID: candidate.id, mode: "bind"
                        ))
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(candidate.name).foregroundStyle(.primary)
                            if candidate.aliases.count > 1 {
                                Text(candidate.aliases.dropFirst().joined(separator: "、"))
                                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            }
                            if !candidate.sampleProgram.isEmpty {
                                Text("节目示例：\(candidate.sampleProgram)")
                                    .font(.caption2).foregroundStyle(.tertiary).lineLimit(1)
                            }
                            Text(candidate.id).font(.caption2).foregroundStyle(.tertiary).lineLimit(1)
                        }
                        .padding(.vertical, 3)
                    }
                    .buttonStyle(.plain)
                }
                if epgCandidates.count < epgCandidateTotal {
                    Button("加载更多节目频道（\(epgCandidates.count)/\(epgCandidateTotal)）") {
                        requestEPGCandidates(for: channel, sourceName: sourceName,
                                             offset: epgCandidates.count, query: epgCandidateQuery, append: true)
                    }
                }
            }
        }
        .navigationTitle("修正 EPG")
        .searchable(text: $epgCandidateQuery, prompt: "搜索节目频道或节目名")
        .onAppear {
            if epgCandidateChannel?.id != channel.id || epgCandidates.isEmpty {
                epgCandidateChannel = channel
                epgCandidateQuery = ""
                requestEPGCandidates(for: channel, sourceName: sourceName, offset: 0, query: "", append: false)
            }
        }
        .onChange(of: epgCandidateQuery) { _, query in
            Task {
                try? await Task.sleep(for: .milliseconds(250))
                guard query == epgCandidateQuery else { return }
                requestEPGCandidates(for: channel, sourceName: sourceName, offset: 0, query: query, append: false)
            }
        }
    }

    private var favoritesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("收藏频道", systemImage: "heart.fill")
                .font(.subheadline.weight(.semibold))
            if favorites.isEmpty {
                Text("在电视端或下方频道目录中收藏频道，即可一键直达。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(favorites) { channel in
                            Button {
                                play(channel)
                            } label: {
                                Text(channel.name)
                                    .font(.subheadline.weight(.medium))
                                    .padding(.horizontal, 12)
                                    .frame(minHeight: 38)
                                    .background(Color(uiColor: .secondarySystemBackground), in: Capsule())
                            }
                            .buttonStyle(.plain)
                            .disabled(!isConnected)
                            .accessibilityLabel("播放收藏频道 \(channel.name)")
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
    }

    private var channelDirectory: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("频道目录").font(.headline)
                Spacer()
                if total > 0 {
                    Text("\(channels.count) / \(total)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if !sourceNames.isEmpty {
                Menu {
                    ForEach(sourceNames, id: \.self) { source in
                        Button {
                            selectedSource = source
                            selectedGroup = ""
                        } label: {
                            if selectedSource == source { Label(source, systemImage: "checkmark") }
                            else { Text(source) }
                        }
                    }
                } label: {
                    Label(selectedSource.isEmpty ? "选择频道源" : selectedSource, systemImage: "tv")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(11)
                        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 11))
                }
                .accessibilityLabel("当前频道源：\(selectedSource.isEmpty ? "未选择" : selectedSource)")
            }
            TextField("搜索频道", text: $searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(11)
                .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 11))
                .disabled(!isConnected)
                .accessibilityLabel("搜索频道")

            if !groups.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 7) {
                        groupButton("全部", count: nil, group: "")
                        ForEach(groups) { group in
                            groupButton(group.name, count: group.count, group: group.name)
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
            if channels.isEmpty && !isLoading {
                Text(catalogError ?? (isConnected ? "暂无匹配频道。可检查电视端播放列表或更换搜索条件。" : "连接电视后可查看频道。"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 62)
            }
            if catalogError != nil {
                Button("重试读取频道") { requestCatalog(reset: true) }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                    .disabled(!isConnected)
            }
            LazyVStack(spacing: 6) {
                ForEach(channels) { channel in
                    channelRow(channel)
                }
            }
            if isLoading {
                ProgressView("正在读取频道…")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            } else if channels.count < total {
                Button("加载更多频道") {
                    requestCatalog(reset: false)
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
                .disabled(!isConnected)
            }
        }
    }

    private func groupButton(_ title: String, count: Int?, group: String) -> some View {
        Button {
            selectedGroup = group
        } label: {
            Text(count.map { "\(title) \($0)" } ?? title)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 11)
                .frame(minHeight: 34)
                .background(
                    selectedGroup == group ? Color.accentColor.opacity(0.22) : Color(uiColor: .secondarySystemBackground),
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selectedGroup == group ? .isSelected : [])
    }

    private func channelRow(_ channel: IPTVRemoteChannel) -> some View {
        HStack(spacing: 8) {
            Button {
                play(channel)
            } label: {
                HStack(spacing: 10) {
                    Text(channel.number.map { String($0) } ?? "—")
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 34, alignment: .leading)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(channel.name).font(.subheadline.weight(.medium)).lineLimit(1)
                        if let programTitle = channel.programTitle {
                            Text([programTitle, channel.programTimeRange].compactMap { $0 }.joined(separator: " · "))
                                .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                        } else if !channel.group.isEmpty {
                            Text(channel.group).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                    Spacer(minLength: 0)
                    if channel.id == currentId {
                        Image(systemName: "waveform")
                            .foregroundStyle(Color.accentColor)
                            .accessibilityHidden(true)
                    }
                }
                .frame(minHeight: 50)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("播放 \(channel.number.map { "\($0) 台，" } ?? "")\(channel.name)")
            Button {
                lightHaptic.impactOccurred()
                onFavoriteChange?(channel.id, !channel.isFavorite)
            } label: {
                Image(systemName: channel.isFavorite ? "heart.fill" : "heart")
                    .foregroundStyle(channel.isFavorite ? Color.pink : Color.secondary)
                    .frame(width: 42, height: 42)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(channel.isFavorite ? "取消收藏 \(channel.name)" : "收藏 \(channel.name)")
        }
        .padding(.horizontal, 10)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 11))
        .disabled(!isConnected)
    }

    private var numberPad: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("数字选台").font(.headline)
                Spacer()
                Text(inputDigits.isEmpty ? "输入台号" : "\(inputDigits)  ·  2 秒后自动切换")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            let digits = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "退格", "0", "确定"]
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                ForEach(digits, id: \.self) { label in
                    Button {
                        lightHaptic.impactOccurred()
                        switch label {
                        case "退格":
                            if !inputDigits.isEmpty { inputDigits.removeLast() }
                        case "确定":
                            commitDigits()
                        default:
                            if inputDigits.count < 6 { inputDigits.append(label) }
                        }
                    } label: {
                        Text(label)
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 46)
                            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 11))
                    }
                    .buttonStyle(.plain)
                    .disabled(!isConnected || (label == "确定" && inputDigits.isEmpty))
                    .accessibilityLabel(label == "退格" ? "删除一位台号" : label == "确定" ? "切换到所输台号" : "输入 \(label)")
                }
            }
        }
    }

    private func play(_ channel: IPTVRemoteChannel) {
        haptic.impactOccurred()
        onPlayChannel?(channel.name, channel.id)
    }

    private func commitDigits() {
        guard isConnected, !inputDigits.isEmpty else { return }
        let number = inputDigits
        inputDigits = ""
        haptic.impactOccurred()
        onPlayChannel?(number, number)
    }

    private func requestCatalog(reset: Bool) {
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

    private func receiveCatalog(_ info: [AnyHashable: Any]?) {
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

    private func receiveState(_ info: [AnyHashable: Any]?) {
        guard isConnected, let info else { return }
        if let sessionID = info["playbackSessionID"] as? String,
           let sequence = (info["playbackSequence"] as? NSNumber)?.int64Value {
            guard sequence > lastPlaybackSequence else { return }
            playbackSessionID = sessionID
            lastPlaybackSequence = sequence
        } else if playbackSessionID != nil {
            // Ignore delayed state from older TVs that does not carry ordering metadata.
            return
        }
        currentId = info[HSBRemotePayloadKeyId] as? String
        currentName = info[HSBRemotePayloadKeyName] as? String
        isPlaying = info["isPlaying"] as? Bool ?? false
        wantsPlayback = info["wantsPlayback"] as? Bool ?? isPlaying
        playbackState = info["playbackState"] as? String ?? (isPlaying ? "playing" : "idle")
        currentIsFavorite = info["isFavorite"] as? Bool ?? false
    }

    private func receiveFavorites(_ info: [AnyHashable: Any]?) {
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

    private func receiveSources(_ info: [AnyHashable: Any]?) {
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

    private func requestEPGBindings(sourceName: String, offset: Int, query: String, append: Bool) {
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

    private func requestEPGCandidates(for channel: IPTVRemoteEPGBindingRow, sourceName: String,
                                      offset: Int, query: String, append: Bool) {
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

    private func submitEPGBinding(_ request: IPTVEPGBindingRequest) {
        epgCandidateRequestID = UUID().uuidString
        onEPGBindingRequest?(request)
        epgBindingMessage = "正在保存匹配设置…"
    }

    private func receiveEPGBindings(_ info: [AnyHashable: Any]?) {
        guard isConnected, let info,
              (info["sourceName"] as? String) == epgBindingsSourceName else { return }
        if let requestID = info[HSBRemotePayloadKeyRequestId] as? String,
           let expectedID = epgBindingRequestID,
           requestID != expectedID { return }
        if let message = info[HSBRemotePayloadKeyMessage] as? String {
            epgBindingMessage = message
            if message == "匹配设置已保存。" {
                requestCatalog(reset: true)
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

    private func receiveEPGCandidates(_ info: [AnyHashable: Any]?) {
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

    private func receiveImportResult(_ info: [AnyHashable: Any]?) {
        guard isConnected, let info else { return }
        if let requestId = info[HSBRemotePayloadKeyRequestId] as? String,
           requestId != pendingImportRequestID { return }
        importStatus = info[HSBRemotePayloadKeyMessage] as? String
            ?? (info["success"] as? Bool == true ? "导入完成。" : "导入失败。")
        if info["previewRequired"] as? Bool == true,
           let preview = IPTVPlaylistImportPreview(payload: info) {
            includeEPGInPlaylistImport = preview.epgWasExplicit
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
            requestCatalog(reset: true)
        }
        pendingImportRequestID = nil
    }

    private struct PendingSourceRefreshConfirmation: Identifiable {
        let requestID: String
        let sourceName: String
        let previousChannelCount: Int
        let updatedChannelCount: Int

        var id: String { requestID }
    }

    private func submitPlaylistURL() {
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
        let name = importSourceName.trimmingCharacters(in: .whitespacesAndNewlines)
        onImportSource?(name, url, epgURL.isEmpty ? nil : epgURL, requestId)
    }

    private func submitEPGURL() {
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

    private func importEPGCandidate(for source: String) {
        guard let candidate = sourceEPGCandidates[source], isHTTPURL(candidate) else { return }
        selectedSource = source
        epgURLText = candidate
        submitEPGURL()
    }

    private func refreshSource(_ name: String) {
        let requestId = UUID().uuidString
        pendingImportRequestID = requestId
        importStatus = "正在刷新 \(name)…"
        onRefreshSource?(name, requestId)
    }

    private func handleFileImport(_ result: Result<URL, Error>, type: String) {
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
                        importStatus = "文件超过大小限制。"
                        pendingImportRequestID = nil
                        return
                    }
                    importStatus = "正在传输文件到电视…"
                    onImportFile?(type, name, data, requestId)
                } catch {
                    importStatus = "文件读取失败：\(error.localizedDescription)"
                    pendingImportRequestID = nil
                }
            }
        } catch {
            importStatus = "文件选择失败：\(error.localizedDescription)"
        }
    }

    private func isHTTPURL(_ rawValue: String) -> Bool {
        guard let components = URLComponents(string: rawValue.trimmingCharacters(in: .whitespacesAndNewlines)),
              ["http", "https"].contains(components.scheme?.lowercased() ?? ""),
              components.host != nil else { return false }
        return true
    }

    private func epgHostSummary(_ rawValue: String) -> String {
        guard let host = URLComponents(string: rawValue)?.host else { return "发现 XMLTV 节目单地址" }
        return "已发现 XMLTV 节目单（\(host)）"
    }

    private func resetConnectionData() {
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
        includeEPGInPlaylistImport = false
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

private struct TowerButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                configuration.isPressed ? Color.accentColor.opacity(0.3) : Color(uiColor: .tertiarySystemBackground),
                in: RoundedRectangle(cornerRadius: 12)
            )
            .foregroundStyle(configuration.isPressed ? Color.accentColor : Color.primary)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
