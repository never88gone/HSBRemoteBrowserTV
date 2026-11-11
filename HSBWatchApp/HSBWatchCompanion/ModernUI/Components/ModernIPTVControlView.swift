//
//  ModernIPTVControlView.swift
//  HSBWatchCompanion
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

public struct ModernIPTVControlView: View {
    public let isConnected: Bool
    public var isWideDuo: Bool = false
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
        isWideDuo: Bool = false,
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
        self.isWideDuo = isWideDuo
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
        Group {
            if isWideDuo {
                wideDuoBody
            } else {
                compactBody
            }
        }
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

    private var compactBody: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                nowPlayingCard
                channelVolumeTowers
                actionBar
                sourceManagementButton
                favoritesSection
                channelDirectoryView
                numberPadView
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
    }

    private var wideDuoBody: some View {
        HStack(alignment: .top, spacing: DuoMetrics.columnGap) {
            // 左栏：顶部状态微条 (消除顶部大黑空) + 正播放态 + 物理频道/音量双塔 + 快捷功能栏 + 0-9 数字直选键盘
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label("IPTV 实体控制双塔", systemImage: "tv.fill")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(DuoPalette.textPrimary)
                        Spacer()
                        HStack(spacing: 5) {
                            Circle()
                                .fill(isConnected ? DuoPalette.readyGreen : DuoPalette.warmOrange)
                                .frame(width: 6, height: 6)
                            Text(isConnected ? "已建立直播信令直连" : "等待连接大屏 TV")
                                .font(.system(size: 10.5, weight: .semibold))
                                .foregroundColor(DuoPalette.textSecondary)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(DuoPalette.cardElevated, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                    
                    nowPlayingCard
                    channelVolumeTowers
                    actionBar
                    numberPadView
                }
                .padding(.bottom, 16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            // 右栏：高清收藏频道与频道目录 + 左收窄 L 型「频道源管理」底栏 (撑满右栏消除黑洞与顶部留白)
            VStack(spacing: 12) {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label("高清直播目录与 EPG 节目单", systemImage: "list.and.film")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(DuoPalette.textPrimary)
                            Spacer()
                            Text("一屏全览")
                                .font(.system(size: 10.5, weight: .semibold))
                                .foregroundColor(DuoPalette.brandBlue)
                        }
                        .padding(.horizontal, 4)
                        .padding(.top, 2)
                        
                        favoritesSection
                        channelDirectoryView
                        
                        if !isConnected {
                            VStack(spacing: 12) {
                                Image(systemName: "tv.and.mediabox")
                                    .font(.system(size: 32, weight: .regular))
                                    .foregroundColor(DuoPalette.brandBlue.opacity(0.75))
                                Text("等待与糖葫芦大屏同步直播目录")
                                    .font(.system(size: 13.5, weight: .bold))
                                    .foregroundColor(DuoPalette.textPrimary)
                                Text("建立加密专线后，收藏频道、直播分组与 EPG 实时节目表将在此整栏平铺。")
                                    .font(.system(size: 11.5))
                                    .foregroundColor(DuoPalette.textSecondary)
                                    .multilineTextAlignment(.center)
                                Button {
                                    NotificationCenter.default.post(name: Notification.Name("HSBOpenQRCodeScannerNotification"), object: nil)
                                } label: {
                                    Label("扫码连接大屏电视端", systemImage: "qrcode.viewfinder")
                                        .font(.system(size: 12.5, weight: .semibold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 9)
                                        .background(DuoPalette.brandBlue, in: Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                            .padding(.horizontal, 14)
                            .duoCard(cornerRadius: DuoMetrics.innerCardRadius, fill: DuoPalette.cardElevated)
                        }
                    }
                    .padding(14)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .duoCard(cornerRadius: DuoMetrics.cardRadius)

                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Label("直播源与目录管理", systemImage: "antenna.radiowaves.left.and.right")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(DuoPalette.textPrimary)
                            Spacer()
                            Text(isConnected ? "已加密直连" : "等待电视端")
                                .font(.system(size: 10.5, weight: .semibold))
                                .foregroundColor(isConnected ? DuoPalette.readyGreen : DuoPalette.warmOrange)
                        }
                        
                        sourceManagementButton
                        
                        HStack(spacing: 8) {
                            Button {
                                vm.requestCatalog(isConnected: isConnected, reset: true, onRequestCatalog: onRequestCatalog)
                            } label: {
                                Label("同步目录", systemImage: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 12, weight: .semibold))
                                    .frame(maxWidth: .infinity, minHeight: 42)
                                    .duoCard(cornerRadius: 12, fill: DuoPalette.cardElevated)
                                    .foregroundColor(isConnected ? DuoPalette.textPrimary : DuoPalette.textMuted)
                            }
                            .buttonStyle(.plain)
                            .disabled(!isConnected)
                            
                            Button {
                                NotificationCenter.default.post(name: NSNotification.Name("HSBOpenQRCodeScannerNotification"), object: nil)
                            } label: {
                                Label("扫码连电视", systemImage: "qrcode.viewfinder")
                                    .font(.system(size: 12, weight: .semibold))
                                    .frame(maxWidth: .infinity, minHeight: 42)
                                    .duoCard(cornerRadius: 12, fill: DuoPalette.brandBlue.opacity(0.16), stroke: DuoPalette.brandBlue.opacity(0.35))
                                    .foregroundColor(DuoPalette.brandBlue)
                            }
                            .buttonStyle(.plain)
                        }
                        
                        Spacer(minLength: 0)
                        
                        HStack(spacing: 6) {
                            Image(systemName: isConnected ? "checkmark.shield.fill" : "exclamationmark.triangle.fill")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(isConnected ? DuoPalette.readyGreen : DuoPalette.warmOrange)
                            Text(isConnected ? "已与大屏糖葫芦TV实时同步 EPG 与播放列表" : "连接大屏糖葫芦TV后即可解锁全网频道与 EPG 管理")
                                .font(.system(size: 10.5, weight: .medium))
                                .foregroundColor(DuoPalette.textSecondary)
                                .lineLimit(1)
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .duoCard(cornerRadius: DuoMetrics.cardRadius)

                    Spacer()
                        .frame(width: DuoMetrics.sidebarReserveWidth - DuoMetrics.trailingPadding)
                }
                .frame(height: 224)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    private var nowPlayingCard: some View {
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
    }

    private var channelVolumeTowers: some View {
        ModernIPTVChannelVolumeTowers(
            isConnected: isConnected,
            onAction: onAction
        )
    }

    private var actionBar: some View {
        ModernIPTVActionBar(
            isConnected: isConnected,
            wantsPlayback: vm.wantsPlayback,
            onAction: onAction,
            onRefresh: { vm.requestCatalog(isConnected: isConnected, reset: true, onRequestCatalog: onRequestCatalog) }
        )
    }

    private var favoritesSection: some View {
        ModernIPTVFavoritesSection(
            isConnected: isConnected,
            favorites: vm.favorites,
            onPlay: { vm.play($0, onPlayChannel: onPlayChannel) }
        )
    }

    private var channelDirectoryView: some View {
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
    }

    private var numberPadView: some View {
        ModernIPTVNumberPadView(
            isConnected: isConnected,
            inputDigits: $vm.inputDigits,
            onCommit: { vm.commitDigits(isConnected: isConnected, onPlayChannel: onPlayChannel) }
        )
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
                .background(isWideDuo ? DuoPalette.cardElevated : Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                .foregroundColor(isWideDuo ? DuoPalette.textPrimary : .primary)
        }
        .buttonStyle(.plain)
        .disabled(!isConnected)
    }
}

#if DEBUG
#Preview("IPTV 电视频道控制台 · 折叠窄屏") {
    DuoPreviewContainer(expandedDuo: false) {
        ModernIPTVControlView(isConnected: true, isWideDuo: false)
    }
}

#Preview("IPTV 电视频道控制台 · iPhone Duo 双栏") {
    DuoPreviewContainer(expandedDuo: true) {
        ModernIPTVControlView(isConnected: true, isWideDuo: true)
            .padding(18)
    }
}
#endif
