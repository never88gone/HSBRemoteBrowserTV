//
//  ModernIPTVEPGBindingView.swift
//  HSBWatchCompanion
//

import SwiftUI

struct ModernIPTVEPGBindingListView: View {
    let sourceName: String
    let epgBindingMessage: String?
    let epgBindingRows: [IPTVRemoteEPGBindingRow]
    let epgBindingTotal: Int
    @Binding var epgBindingQuery: String
    @Binding var selectedSource: String
    let onRequestBindings: (String, Int, String, Bool) -> Void
    let onSubmitBinding: (IPTVEPGBindingRequest) -> Void
    let onRequestCandidates: (IPTVRemoteEPGBindingRow, String, Int, String, Bool) -> Void
    let epgCandidates: [IPTVRemoteEPGCandidate]
    let epgCandidateTotal: Int
    @Binding var epgCandidateQuery: String
    @Binding var epgCandidateChannel: IPTVRemoteEPGBindingRow?

    var body: some View {
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
                    ModernIPTVEPGCandidatePickerView(
                        channel: row,
                        sourceName: sourceName,
                        epgBindingMessage: epgBindingMessage,
                        epgCandidates: epgCandidates,
                        epgCandidateTotal: epgCandidateTotal,
                        epgCandidateQuery: $epgCandidateQuery,
                        epgCandidateChannel: $epgCandidateChannel,
                        onSubmitBinding: onSubmitBinding,
                        onRequestCandidates: onRequestCandidates
                    )
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
                    onRequestBindings(sourceName, epgBindingRows.count, epgBindingQuery, true)
                }
            }
        }
        .navigationTitle("节目单匹配")
        .searchable(text: $epgBindingQuery, prompt: "搜索频道")
        .onAppear {
            if selectedSource != sourceName { selectedSource = sourceName }
            if epgBindingRows.isEmpty {
                onRequestBindings(sourceName, 0, epgBindingQuery, false)
            }
        }
        .onChange(of: epgBindingQuery) { _, query in
            Task {
                try? await Task.sleep(for: .milliseconds(250))
                guard query == epgBindingQuery else { return }
                onRequestBindings(sourceName, 0, query, false)
            }
        }
    }
}

struct ModernIPTVEPGCandidatePickerView: View {
    let channel: IPTVRemoteEPGBindingRow
    let sourceName: String
    let epgBindingMessage: String?
    let epgCandidates: [IPTVRemoteEPGCandidate]
    let epgCandidateTotal: Int
    @Binding var epgCandidateQuery: String
    @Binding var epgCandidateChannel: IPTVRemoteEPGBindingRow?
    let onSubmitBinding: (IPTVEPGBindingRequest) -> Void
    let onRequestCandidates: (IPTVRemoteEPGBindingRow, String, Int, String, Bool) -> Void

    var body: some View {
        List {
            Section("当前状态") {
                Text(channel.name).font(.headline)
                Text(channel.stateLabel).font(.subheadline).foregroundStyle(.secondary)
                Button("恢复自动匹配") {
                    onSubmitBinding(IPTVEPGBindingRequest(
                        operation: "setBinding", sourceName: sourceName, channelID: channel.id, mode: "automatic"
                    ))
                }
                Button("关闭此频道节目单", role: .destructive) {
                    onSubmitBinding(IPTVEPGBindingRequest(
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
                        onSubmitBinding(IPTVEPGBindingRequest(
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
                        onRequestCandidates(channel, sourceName, epgCandidates.count, epgCandidateQuery, true)
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
                onRequestCandidates(channel, sourceName, 0, "", false)
            }
        }
        .onChange(of: epgCandidateQuery) { _, query in
            Task {
                try? await Task.sleep(for: .milliseconds(250))
                guard query == epgCandidateQuery else { return }
                onRequestCandidates(channel, sourceName, 0, query, false)
            }
        }
    }
}
