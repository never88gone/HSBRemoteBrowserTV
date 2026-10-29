//
//  ModernIPTVSourceManagerSheet.swift
//  HSBWatchCompanion
//

import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct ModernIPTVSourceManagerSheet: View {
    let isConnected: Bool
    @Binding var isPresented: Bool
    @Binding var selectedSource: String
    let sourceNames: [String]
    let sourceEPGCandidates: [String: String]
    @Binding var importSourceName: String
    @Binding var playlistURLText: String
    @Binding var epgURLText: String
    @Binding var importStatus: String?
    @Binding var pendingImportRequestID: String?
    @Binding var pendingPlaylistImportPreview: IPTVPlaylistImportPreview?
    @Binding var pendingSourceRefreshConfirmation: PendingSourceRefreshConfirmation?
    @Binding var isPlaylistFileImporterPresented: Bool
    @Binding var isEPGFileImporterPresented: Bool
    let onRequestSources: (() -> Void)?
    let onSubmitPlaylistURL: () -> Void
    let onSubmitEPGURL: () -> Void
    let onImportEPGCandidate: (String) -> Void
    let onRefreshSource: (String) -> Void
    let onDeleteSource: ((String) -> Void)?
    let onConfirmSourceRefresh: ((String, Bool) -> Void)?
    let onConfirmPlaylistImport: ((String, Bool, Bool) -> Void)?

    // EPG Binding 导航参数
    let epgBindingMessage: String?
    let epgBindingRows: [IPTVRemoteEPGBindingRow]
    let epgBindingTotal: Int
    @Binding var epgBindingQuery: String
    let onRequestBindings: (String, Int, String, Bool) -> Void
    let onSubmitBinding: (IPTVEPGBindingRequest) -> Void
    let onRequestCandidates: (IPTVRemoteEPGBindingRow, String, Int, String, Bool) -> Void
    let epgCandidates: [IPTVRemoteEPGCandidate]
    let epgCandidateTotal: Int
    @Binding var epgCandidateQuery: String
    @Binding var epgCandidateChannel: IPTVRemoteEPGBindingRow?

    @State private var sourcePendingDeletion: String?
    @State private var isDeleteConfirmationPresented = false
    @State private var includeEPGInPlaylistImport = false

    private let haptic = UIImpactFeedbackGenerator(style: .medium)
    private let lightHaptic = UIImpactFeedbackGenerator(style: .light)

    var body: some View {
        NavigationStack {
            Form {
                Section("导入自定义频道源") {
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
                    Button("检查并预览频道") { onSubmitPlaylistURL() }
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
                                isPresented = false
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
                                    onImportEPGCandidate(name)
                                } label: {
                                    Image(systemName: "calendar.badge.plus")
                                }
                                .accessibilityLabel("导入 \(name) 声明的节目单")
                            }
                            NavigationLink {
                                ModernIPTVEPGBindingListView(
                                    sourceName: name,
                                    epgBindingMessage: epgBindingMessage,
                                    epgBindingRows: epgBindingRows,
                                    epgBindingTotal: epgBindingTotal,
                                    epgBindingQuery: $epgBindingQuery,
                                    selectedSource: $selectedSource,
                                    onRequestBindings: onRequestBindings,
                                    onSubmitBinding: onSubmitBinding,
                                    onRequestCandidates: onRequestCandidates,
                                    epgCandidates: epgCandidates,
                                    epgCandidateTotal: epgCandidateTotal,
                                    epgCandidateQuery: $epgCandidateQuery,
                                    epgCandidateChannel: $epgCandidateChannel
                                )
                            } label: {
                                Image(systemName: "arrow.left.arrow.right")
                            }
                            .accessibilityLabel("管理 \(name) 的节目单匹配")
                            Button { onRefreshSource(name) } label: {
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
                ModernIPTVPlaylistImportPreviewView(
                    preview: preview,
                    isConnected: isConnected,
                    includeEPGInPlaylistImport: $includeEPGInPlaylistImport,
                    onConfirm: { reqID, includeEPG in
                        pendingImportRequestID = reqID
                        importStatus = "正在电视上保存频道源…"
                        onConfirmPlaylistImport?(reqID, true, includeEPG)
                        pendingPlaylistImportPreview = nil
                    },
                    onCancel: { reqID in
                        pendingImportRequestID = reqID
                        importStatus = "正在取消导入…"
                        onConfirmPlaylistImport?(reqID, false, false)
                        pendingPlaylistImportPreview = nil
                    }
                )
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { isPresented = false }
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

    private func submitEPGURL() {
        onSubmitEPGURL()
    }
}

struct ModernIPTVPlaylistImportPreviewView: View {
    let preview: IPTVPlaylistImportPreview
    let isConnected: Bool
    @Binding var includeEPGInPlaylistImport: Bool
    let onConfirm: (String, Bool) -> Void
    let onCancel: (String) -> Void

    var body: some View {
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
                    onConfirm(preview.requestID, includeEPGInPlaylistImport)
                }
                .disabled(!isConnected || preview.channelCount == 0)
                Button("取消导入", role: .destructive) {
                    onCancel(preview.requestID)
                }
                .disabled(!isConnected)
            }
        }
        .navigationTitle("确认导入")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { includeEPGInPlaylistImport = preview.epgWasExplicit }
    }
}

func isHTTPURL(_ rawValue: String) -> Bool {
    guard let components = URLComponents(string: rawValue.trimmingCharacters(in: .whitespacesAndNewlines)),
          ["http", "https"].contains(components.scheme?.lowercased() ?? ""),
          components.host != nil else { return false }
    return true
}

func epgHostSummary(_ rawValue: String) -> String {
    guard let host = URLComponents(string: rawValue)?.host else { return "发现 XMLTV 节目单地址" }
    return "已发现 XMLTV 节目单（\(host)）"
}

var playlistContentTypes: [UTType] {
    [UTType(filenameExtension: "m3u") ?? .plainText,
     UTType(filenameExtension: "m3u8") ?? .plainText]
}

var epgContentTypes: [UTType] {
    [UTType(filenameExtension: "xml") ?? .xml,
     UTType(filenameExtension: "xmltv") ?? .xml,
     UTType(filenameExtension: "gz") ?? .gzip]
}
