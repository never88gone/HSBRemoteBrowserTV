//
//  ModernIPTVControlView.swift
//  HSBWatchCompanion
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

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

    @StateObject private var vm = ModernIPTVViewModel()

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
                ModernIPTVNowPlayingCard(
                    isConnected: isConnected,
                    isPlaying: vm.isPlaying,
                    playbackSummary: vm.playbackSummary,
                    currentName: vm.currentName,
                    currentId: vm.currentId,
                    currentIsFavorite: vm.currentIsFavorite,
                    onFavoriteToggle: {
                        guard let currentId = vm.currentId else { return }
                        onFavoriteChange?(currentId, !vm.currentIsFavorite)
                    }
                )
                ModernIPTVChannelVolumeTowers(
                    isConnected: isConnected,
                    onAction: onAction
                )
                ModernIPTVActionBar(
                    isConnected: isConnected,
                    wantsPlayback: vm.wantsPlayback,
                    onAction: onAction,
                    onRefresh: { vm.requestCatalog(isConnected: isConnected, reset: true, onRequestCatalog: onRequestCatalog) }
                )
                sourceManagementButton
                ModernIPTVFavoritesSection(
                    isConnected: isConnected,
                    favorites: vm.favorites,
                    onPlay: { vm.play($0, onPlayChannel: onPlayChannel) }
                )
                ModernIPTVChannelDirectoryView(
                    isConnected: isConnected,
                    sourceNames: vm.sourceNames,
                    selectedSource: $vm.selectedSource,
                    selectedGroup: $vm.selectedGroup,
                    searchText: $vm.searchText,
                    groups: vm.groups,
                    channels: vm.channels,
                    total: vm.total,
                    isLoading: vm.isLoading,
                    catalogError: vm.catalogError,
                    currentId: vm.currentId,
                    onPlay: { vm.play($0, onPlayChannel: onPlayChannel) },
                    onFavoriteChange: onFavoriteChange,
                    onRequestCatalog: { vm.requestCatalog(isConnected: isConnected, reset: $0, onRequestCatalog: onRequestCatalog) }
                )
                ModernIPTVNumberPadView(
                    isConnected: isConnected,
                    inputDigits: $vm.inputDigits,
                    onCommit: { vm.commitDigits(isConnected: isConnected, onPlayChannel: onPlayChannel) }
                )
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
                vm.resetConnectionData()
            }
        }
        .task(id: IPTVCatalogScope(query: vm.searchText, group: vm.selectedGroup, source: vm.selectedSource, connected: isConnected)) {
            guard isConnected else { return }
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            vm.requestCatalog(isConnected: isConnected, reset: true, onRequestCatalog: onRequestCatalog)
        }
        .task(id: vm.pendingRequestId) {
            guard let requestId = vm.pendingRequestId else { return }
            try? await Task.sleep(for: .seconds(8))
            guard !Task.isCancelled, vm.pendingRequestId == requestId else { return }
            vm.pendingRequestId = nil
            vm.isLoading = false
            vm.catalogError = "读取频道超时，请重试。"
        }
        .task(id: vm.pendingImportRequestID) {
            guard let requestId = vm.pendingImportRequestID else { return }
            try? await Task.sleep(for: .seconds(90))
            guard !Task.isCancelled, vm.pendingImportRequestID == requestId else { return }
            vm.pendingImportRequestID = nil
            vm.importStatus = "电视未返回导入结果，请检查连接后重试。"
        }
        .task(id: vm.inputDigits) {
            guard !vm.inputDigits.isEmpty else { return }
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            vm.commitDigits(isConnected: isConnected, onPlayChannel: onPlayChannel)
        }
        .onReceive(NotificationCenter.default.publisher(for: .HSBIPTVCatalogUpdated)) {
            vm.receiveCatalog(isConnected: isConnected, info: $0.userInfo)
        }
        .onReceive(NotificationCenter.default.publisher(for: .HSBIPTVStateUpdated)) {
            vm.receiveState(isConnected: isConnected, info: $0.userInfo)
        }
        .onReceive(NotificationCenter.default.publisher(for: .HSBIPTVFavoritesUpdated)) {
            vm.receiveFavorites(isConnected: isConnected, info: $0.userInfo)
        }
        .onReceive(NotificationCenter.default.publisher(for: .HSBIPTVImportResultUpdated)) {
            vm.receiveImportResult(
                isConnected: isConnected,
                info: $0.userInfo,
                onRequestSources: onRequestSources,
                onRequestCatalog: { vm.requestCatalog(isConnected: isConnected, reset: $0, onRequestCatalog: onRequestCatalog) }
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .HSBIPTVSourcesUpdated)) {
            vm.receiveSources(isConnected: isConnected, info: $0.userInfo)
        }
        .onReceive(NotificationCenter.default.publisher(for: .HSBIPTVEPGBindingsUpdated)) {
            vm.receiveEPGBindings(
                isConnected: isConnected,
                info: $0.userInfo,
                onRequestCatalog: { vm.requestCatalog(isConnected: isConnected, reset: $0, onRequestCatalog: onRequestCatalog) }
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .HSBIPTVEPGCandidatesUpdated)) {
            vm.receiveEPGCandidates(isConnected: isConnected, info: $0.userInfo)
        }
        .sheet(isPresented: $vm.isSourceManagerPresented) {
            ModernIPTVSourceManagerSheet(
                isConnected: isConnected,
                isPresented: $vm.isSourceManagerPresented,
                selectedSource: $vm.selectedSource,
                sourceNames: vm.sourceNames,
                sourceEPGCandidates: vm.sourceEPGCandidates,
                importSourceName: $vm.importSourceName,
                playlistURLText: $vm.playlistURLText,
                epgURLText: $vm.epgURLText,
                importStatus: $vm.importStatus,
                pendingImportRequestID: $vm.pendingImportRequestID,
                pendingPlaylistImportPreview: $vm.pendingPlaylistImportPreview,
                pendingSourceRefreshConfirmation: $vm.pendingSourceRefreshConfirmation,
                isPlaylistFileImporterPresented: $vm.isPlaylistFileImporterPresented,
                isEPGFileImporterPresented: $vm.isEPGFileImporterPresented,
                onRequestSources: onRequestSources,
                onSubmitPlaylistURL: { vm.submitPlaylistURL(onImportSource: onImportSource) },
                onSubmitEPGURL: { vm.submitEPGURL(onImportEPG: onImportEPG) },
                onImportEPGCandidate: { vm.importEPGCandidate(for: $0, onImportEPG: onImportEPG) },
                onRefreshSource: { vm.refreshSource($0, onRefreshSource: onRefreshSource) },
                onDeleteSource: onDeleteSource,
                onConfirmSourceRefresh: onConfirmSourceRefresh,
                onConfirmPlaylistImport: onConfirmPlaylistImport,
                epgBindingMessage: vm.epgBindingMessage,
                epgBindingRows: vm.epgBindingRows,
                epgBindingTotal: vm.epgBindingTotal,
                epgBindingQuery: $vm.epgBindingQuery,
                onRequestBindings: { vm.requestEPGBindings(isConnected: isConnected, sourceName: $0, offset: $1, query: $2, append: $3, onEPGBindingRequest: onEPGBindingRequest) },
                onSubmitBinding: { vm.submitEPGBinding($0, onEPGBindingRequest: onEPGBindingRequest) },
                onRequestCandidates: { vm.requestEPGCandidates(isConnected: isConnected, for: $0, sourceName: $1, offset: $2, query: $3, append: $4, onEPGBindingRequest: onEPGBindingRequest) },
                epgCandidates: vm.epgCandidates,
                epgCandidateTotal: vm.epgCandidateTotal,
                epgCandidateQuery: $vm.epgCandidateQuery,
                epgCandidateChannel: $vm.epgCandidateChannel
            )
        }
        .fileImporter(isPresented: $vm.isPlaylistFileImporterPresented, allowedContentTypes: playlistContentTypes) {
            vm.handleFileImport($0, type: "playlist", onImportFile: onImportFile)
        }
        .fileImporter(isPresented: $vm.isEPGFileImporterPresented, allowedContentTypes: epgContentTypes) {
            vm.handleFileImport($0, type: "epg", onImportFile: onImportFile)
        }
    }

    private var sourceManagementButton: some View {
        Button {
            onRequestSources?()
            vm.importStatus = nil
            vm.isSourceManagerPresented = true
        } label: {
            Label("管理频道源与节目单", systemImage: "square.and.arrow.down")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(!isConnected)
    }
}
