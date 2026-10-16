//
//  ModernIPTVChannelDirectoryView.swift
//  HSBWatchCompanion
//

import SwiftUI
import UIKit

struct ModernIPTVFavoritesSection: View {
    let isConnected: Bool
    let favorites: [IPTVRemoteChannel]
    let onPlay: (IPTVRemoteChannel) -> Void

    var body: some View {
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
                                onPlay(channel)
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
}

struct ModernIPTVChannelDirectoryView: View {
    let isConnected: Bool
    let sourceNames: [String]
    @Binding var selectedSource: String
    @Binding var selectedGroup: String
    @Binding var searchText: String
    let groups: [IPTVRemoteGroup]
    let channels: [IPTVRemoteChannel]
    let total: Int
    let isLoading: Bool
    let catalogError: String?
    let currentId: String?
    let onPlay: (IPTVRemoteChannel) -> Void
    let onFavoriteChange: ((String, Bool) -> Void)?
    let onRequestCatalog: (Bool) -> Void

    private let lightHaptic = UIImpactFeedbackGenerator(style: .light)

    var body: some View {
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
                Button("重试读取频道") { onRequestCatalog(true) }
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
                    onRequestCatalog(false)
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
                onPlay(channel)
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
}

struct ModernIPTVNumberPadView: View {
    let isConnected: Bool
    @Binding var inputDigits: String
    let onCommit: () -> Void

    private let lightHaptic = UIImpactFeedbackGenerator(style: .light)

    var body: some View {
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
                            onCommit()
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
}
