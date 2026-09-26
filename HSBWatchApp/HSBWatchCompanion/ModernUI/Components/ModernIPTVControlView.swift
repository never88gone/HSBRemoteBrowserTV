//
//  ModernIPTVControlView.swift
//  HSBWatchCompanion
//

import SwiftUI
import UIKit

private struct IPTVRemoteChannel: Identifiable {
    let id: String
    let name: String
    let group: String
    let number: Int?
    var isFavorite: Bool

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
    let connected: Bool
}

public struct ModernIPTVControlView: View {
    public let isConnected: Bool
    public var onAction: ((HSBRemoteSimulateAction) -> Void)?
    public var onPlayChannel: ((String, String) -> Void)?
    public var onRequestCatalog: ((String, String, Int, Int, String) -> Void)?
    public var onFavoriteChange: ((String, Bool) -> Void)?

    @State private var searchText = ""
    @State private var selectedGroup = ""
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
    @State private var currentIsFavorite = false

    private let pageSize = 100
    private let haptic = UIImpactFeedbackGenerator(style: .medium)
    private let lightHaptic = UIImpactFeedbackGenerator(style: .light)

    public init(
        isConnected: Bool = false,
        onAction: ((HSBRemoteSimulateAction) -> Void)? = nil,
        onPlayChannel: ((String, String) -> Void)? = nil,
        onRequestCatalog: ((String, String, Int, Int, String) -> Void)? = nil,
        onFavoriteChange: ((String, Bool) -> Void)? = nil
    ) {
        self.isConnected = isConnected
        self.onAction = onAction
        self.onPlayChannel = onPlayChannel
        self.onRequestCatalog = onRequestCatalog
        self.onFavoriteChange = onFavoriteChange
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                nowPlayingCard
                channelAndVolumeControls
                actionBar
                favoritesSection
                channelDirectory
                numberPad
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .onAppear {
            if isConnected { onAction?(.iptvGetFavorites) }
        }
        .onChange(of: isConnected) { _, connected in
            if connected {
                onAction?(.iptvGetFavorites)
            } else {
                resetConnectionData()
            }
        }
        .task(id: IPTVCatalogScope(query: searchText, group: selectedGroup, connected: isConnected)) {
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
    }

    private var nowPlayingCard: some View {
        HStack(spacing: 12) {
            Image(systemName: isPlaying ? "play.tv.fill" : "tv")
                .font(.title2)
                .foregroundStyle(Color.accentColor)
                .frame(width: 44, height: 44)
                .background(Color.accentColor.opacity(0.13), in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 4) {
                Text(isConnected ? (isPlaying ? "正在观看" : "当前频道") : "未连接电视")
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
            actionButton(isPlaying ? "暂停" : "播放", icon: isPlaying ? "pause.fill" : "play.fill") {
                onAction?(isPlaying ? .pause : .play)
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
                        if !channel.group.isEmpty {
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
                .frame(minHeight: 42)
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
        onRequestCatalog?(searchText.trimmingCharacters(in: .whitespacesAndNewlines), selectedGroup, offset, pageSize, requestId)
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
        currentId = info[HSBRemotePayloadKeyId] as? String
        currentName = info[HSBRemotePayloadKeyName] as? String
        isPlaying = info["isPlaying"] as? Bool ?? false
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

    private func resetConnectionData() {
        channels = []
        favorites = []
        groups = []
        total = 0
        pendingRequestId = nil
        isLoading = false
        catalogError = nil
        currentId = nil
        currentName = nil
        isPlaying = false
        currentIsFavorite = false
        inputDigits = ""
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
