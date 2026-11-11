//
//  ModernOpenSourceLibrariesView.swift
//  HSBWatchCompanion
//
//  纯 SwiftUI 第三方开源组件清单及许可证声明详情页（支持折叠屏单列 & iPhone Duo 展开双列网格）。
//

import SwiftUI

public struct HSBOpenSourceLibraryItem: Identifiable, Hashable {
    public let id = UUID()
    public let name: String
    public let author: String
    public let license: String
    public let summary: String
    public let url: String
    public let licenseText: String
    
    public static var allLibraries: [HSBOpenSourceLibraryItem] {
        [
            HSBOpenSourceLibraryItem(
                name: "appletv-remote",
                author: "PostPollux & Community",
                license: "MIT",
                summary: hsbL(
                    "Apple TV Companion & MRP native protocol stack with SRP pairing & OPACK codec.",
                    "Apple TV 原生 Companion & MRP 协议栈，提供真实 SRP 密钥认证握手与 OPACK 二进制编解码。"
                ),
                url: "https://github.com/PostPollux/appletv-remote",
                licenseText: "MIT License\n\nCopyright (c) 2023 PostPollux\n\nPermission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the \"Software\"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software."
            ),
            HSBOpenSourceLibraryItem(
                name: "mlx-swift",
                author: "Apple Inc.",
                license: "MIT",
                summary: hsbL(
                    "Apple Silicon unified memory machine learning framework.",
                    "面向 Apple Silicon 统一内存架构深度优化的高性能端侧机器学习与张量计算框架。"
                ),
                url: "https://github.com/ml-explore/mlx-swift",
                licenseText: "MIT License\n\nCopyright © 2023-2024 Apple Inc.\n\nPermission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the \"Software\"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software."
            ),
            HSBOpenSourceLibraryItem(
                name: "mlx-swift-lm",
                author: "Apple Inc.",
                license: "MIT",
                summary: hsbL(
                    "On-device LLM inference pipeline and weight loader for MLX.",
                    "基于 Apple MLX 的端侧轻量大语言模型推理流水线与本地权重沙盒加载引擎。"
                ),
                url: "https://github.com/ml-explore/mlx-swift-lm",
                licenseText: "MIT License\n\nCopyright © 2023-2024 Apple Inc.\n\nPermission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the \"Software\"), to deal in the Software without restriction."
            ),
            HSBOpenSourceLibraryItem(
                name: "swift-huggingface",
                author: "Hugging Face",
                license: "Apache-2.0",
                summary: hsbL(
                    "Hugging Face Hub client for Swift, supporting model distribution & caching.",
                    "Hugging Face 官方 Swift Hub 客户端，支持端侧轻量开源大模型的分发校验与本地沙盒快照缓存。"
                ),
                url: "https://github.com/huggingface/swift-huggingface",
                licenseText: "Apache License\nVersion 2.0, January 2004\n\nLicensed under the Apache License, Version 2.0 (the \"License\"); you may not use this file except in compliance with the License.\nYou may obtain a copy of the License at\nhttp://www.apache.org/licenses/LICENSE-2.0"
            ),
            HSBOpenSourceLibraryItem(
                name: "swift-transformers",
                author: "Hugging Face",
                license: "Apache-2.0",
                summary: hsbL(
                    "State-of-the-art fast Tokenizers for Swift on-device model text processing.",
                    "用于 Swift 的跨架构高性能 Tokenizer 分词器，支撑端侧模型的极速离线文本编解码与 Prompt 解析。"
                ),
                url: "https://github.com/huggingface/swift-transformers",
                licenseText: "Apache License\nVersion 2.0, January 2004\n\nLicensed under the Apache License, Version 2.0 (the \"License\"); you may not use this file except in compliance with the License."
            ),
            HSBOpenSourceLibraryItem(
                name: "EventSource",
                author: "Mattt",
                license: "MIT",
                summary: hsbL(
                    "Server-Sent Events (SSE) streaming client library for Swift.",
                    "适用于 Swift 的现代 Server-Sent Events (SSE) 高性能流式客户端，支持智能大模型打字机流式输出。"
                ),
                url: "https://github.com/mattt/EventSource",
                licenseText: "MIT License\n\nCopyright (c) 2020-2024 Mattt (https://mattt.me)\n\nPermission is hereby granted, free of charge, to any person obtaining a copy of this software."
            ),
            HSBOpenSourceLibraryItem(
                name: "yyjson",
                author: "ibireme",
                license: "MIT",
                summary: hsbL(
                    "Super fast C JSON library for high-frequency payload parsing.",
                    "超高性能 C 语言 JSON 编解码器，提供纳秒级极速数据封包与解析能力。"
                ),
                url: "https://github.com/ibireme/yyjson",
                licenseText: "MIT License\n\nCopyright (c) 2020 YaoYuan <ibireme@gmail.com>\n\nPermission is hereby granted, free of charge, to any person obtaining a copy of this software."
            ),
            HSBOpenSourceLibraryItem(
                name: "swift-nio",
                author: "Apple Inc.",
                license: "Apache-2.0",
                summary: hsbL(
                    "Cross-platform event-driven asynchronous network application framework.",
                    "跨平台高性能事件驱动异步网络底层框架，支撑遥控器毫秒级低延迟高吞吐通信。"
                ),
                url: "https://github.com/apple/swift-nio",
                licenseText: "Apache License\nVersion 2.0, January 2004\n\nCopyright (c) Apple Inc. and the Swift project authors\nLicensed under Apache License v2.0."
            ),
            HSBOpenSourceLibraryItem(
                name: "swift-crypto",
                author: "Apple Inc.",
                license: "Apache-2.0",
                summary: hsbL(
                    "Open-source implementation of Apple CryptoKit cryptographic algorithms.",
                    "Apple CryptoKit 密码学开源实现，提供 ChaCha20-Poly1305、Curve25519 与端到端传输加密通道加固。"
                ),
                url: "https://github.com/apple/swift-crypto",
                licenseText: "Apache License\nVersion 2.0, January 2004\n\nCopyright (c) Apple Inc. and the Swift project authors\nLicensed under Apache License v2.0."
            )
        ]
    }
}

public struct ModernOpenSourceLibrariesView: View {
    private let libraries = HSBOpenSourceLibraryItem.allLibraries
    @State private var selectedItem: HSBOpenSourceLibraryItem?
    @State private var safariURL: URL?
    
    public init() {}
    
    public var body: some View {
        GeometryReader { geometry in
            let isWideDuo = geometry.size.width >= 550
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    headerBanner
                    
                    let columns = isWideDuo
                        ? [GridItem(.flexible(), spacing: DuoMetrics.columnGap), GridItem(.flexible(), spacing: DuoMetrics.columnGap)]
                        : [GridItem(.flexible())]
                    
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(libraries) { item in
                            libraryCard(item)
                        }
                    }
                }
                .padding(.leading, isWideDuo ? DuoMetrics.outerPadding : 16)
                .padding(.trailing, isWideDuo ? DuoMetrics.trailingPadding : 16)
                .padding(.vertical, 16)
            }
            .background(DuoPalette.canvasBg.ignoresSafeArea())
        }
        .navigationTitle(hsbL("Third-Party Components", "第三方组件"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedItem) { item in
            licenseSheet(for: item)
        }
        .sheet(item: $safariURL) { url in
            ModernSafariView(url: url)
                .ignoresSafeArea()
        }
    }
    
    private var headerBanner: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(
                String(
                    format: hsbL("INTEGRATED COMPONENTS (%d ITEMS)", "已深度集成的开源引擎与核心组件 (共 %d 项)"),
                    libraries.count
                )
            )
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(DuoPalette.hawthornRed)
            
            Text(hsbL(
                "Strictly adheres to open-source licenses for secure communications & on-device AI.",
                "遵循开源软件许可协议，为大屏通信、端侧大模型与加密通道提供底层支撑。"
            ))
            .font(.system(size: 13))
            .foregroundColor(DuoPalette.textSecondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .duoCard(cornerRadius: DuoMetrics.innerCardRadius)
    }
    
    private func libraryCard(_ item: HSBOpenSourceLibraryItem) -> some View {
        Button {
            selectedItem = item
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center, spacing: 8) {
                    Text(item.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(DuoPalette.textPrimary)
                        .lineLimit(1)
                    
                    Text(item.license)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(DuoPalette.hawthornRed)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(DuoPalette.hawthornRed.opacity(0.16)))
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(DuoPalette.textMuted)
                }
                
                Text(item.summary)
                    .font(.system(size: 13))
                    .foregroundColor(DuoPalette.textSecondary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
                
                Text("By \(item.author)")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundColor(DuoPalette.textMuted)
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .duoCard(cornerRadius: DuoMetrics.innerCardRadius)
        }
        .buttonStyle(.plain)
    }
    
    private func licenseSheet(for item: HSBOpenSourceLibraryItem) -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(item.name)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(DuoPalette.textPrimary)
                            Spacer()
                            Text(item.license)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(DuoPalette.hawthornRed)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(DuoPalette.hawthornRed.opacity(0.16)))
                        }
                        Text("\(hsbL("Author", "贡献者")): \(item.author)")
                            .font(.system(size: 13))
                            .foregroundColor(DuoPalette.textSecondary)
                    }
                    .padding(16)
                    .duoCard(cornerRadius: DuoMetrics.innerCardRadius)
                    
                    Text(item.licenseText)
                        .font(.system(size: 12.5, design: .monospaced))
                        .foregroundColor(DuoPalette.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .duoCard(cornerRadius: DuoMetrics.innerCardRadius, fill: DuoPalette.cardElevated)
                    
                    if let targetURL = URL(string: item.url) {
                        Button {
                            selectedItem = nil
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                safariURL = targetURL
                            }
                        } label: {
                            HStack {
                                Image(systemName: "safari")
                                Text(hsbL("Visit Project Page (GitHub)", "前往 GitHub 项目主页"))
                            }
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(DuoPalette.brandBlue))
                        }
                    }
                }
                .padding(18)
            }
            .background(DuoPalette.canvasBg.ignoresSafeArea())
            .navigationTitle(hsbL("License Details", "许可证声明详情"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(hsbL("Done", "完成")) {
                        selectedItem = nil
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

#if DEBUG
#Preview("第三方开源组件 · 折叠窄屏") {
    DuoPreviewContainer("第三方组件", expandedDuo: false) {
        ModernOpenSourceLibrariesView()
    }
}

#Preview("第三方开源组件 · iPhone Duo 双栏展开") {
    DuoPreviewContainer("第三方组件", expandedDuo: true) {
        ModernOpenSourceLibrariesView()
    }
}
#endif
