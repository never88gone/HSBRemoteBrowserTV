//
//  HSBOpenSourceLibrariesViewController.m
//  HSBWatchCompanion
//

#import "HSBOpenSourceLibrariesViewController.h"
#import "HSBThemeManager.h"
#import <SafariServices/SafariServices.h>

static inline NSString * L(NSString *en, NSString *zh) {
    NSString *language = [[NSLocale preferredLanguages] firstObject];
    if ([language hasPrefix:@"zh"]) {
        return zh ?: en;
    }
    return en;
}

@interface HSBOpenSourceItem : NSObject
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *author;
@property (nonatomic, copy) NSString *license;
@property (nonatomic, copy) NSString *summary;
@property (nonatomic, copy) NSString *url;
@property (nonatomic, copy) NSString *licenseText;
@end

@implementation HSBOpenSourceItem
@end

@interface HSBOpenSourceLibrariesViewController () <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray<HSBOpenSourceItem *> *libraries;
@end

@implementation HSBOpenSourceLibrariesViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = L(@"Third-Party Components", @"第三方组件");
    
    [self setupData];
    [self setupTableView];
}

- (void)setupData {
    NSMutableArray *items = [NSMutableArray array];
    
    {
        HSBOpenSourceItem *item = [[HSBOpenSourceItem alloc] init];
        item.name = @"appletv-remote";
        item.author = @"PostPollux & Community";
        item.license = @"MIT";
        item.summary = L(@"Apple TV Companion & MRP native protocol stack with SRP pairing & OPACK codec.",
                         @"Apple TV 原生 Companion & MRP 协议栈，提供真实 SRP 密钥认证握手与 OPACK 二进制编解码。");
        item.url = @"https://github.com/PostPollux/appletv-remote";
        item.licenseText = @"MIT License\n\nCopyright (c) 2023 PostPollux\n\nPermission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the \"Software\"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software.";
        [items addObject:item];
    }
    {
        HSBOpenSourceItem *item = [[HSBOpenSourceItem alloc] init];
        item.name = @"mlx-swift";
        item.author = @"Apple Inc.";
        item.license = @"MIT";
        item.summary = L(@"Apple Silicon unified memory machine learning framework.",
                         @"面向 Apple Silicon 统一内存架构深度优化的高性能端侧机器学习与张量计算框架。");
        item.url = @"https://github.com/ml-explore/mlx-swift";
        item.licenseText = @"MIT License\n\nCopyright © 2023-2024 Apple Inc.\n\nPermission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the \"Software\"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software.";
        [items addObject:item];
    }
    {
        HSBOpenSourceItem *item = [[HSBOpenSourceItem alloc] init];
        item.name = @"mlx-swift-lm";
        item.author = @"Apple Inc.";
        item.license = @"MIT";
        item.summary = L(@"On-device LLM inference pipeline and weight loader for MLX.",
                         @"基于 Apple MLX 的端侧轻量大语言模型推理流水线与本地权重沙盒加载引擎。");
        item.url = @"https://github.com/ml-explore/mlx-swift-lm";
        item.licenseText = @"MIT License\n\nCopyright © 2023-2024 Apple Inc.\n\nPermission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the \"Software\"), to deal in the Software without restriction.";
        [items addObject:item];
    }
    {
        HSBOpenSourceItem *item = [[HSBOpenSourceItem alloc] init];
        item.name = @"swift-huggingface";
        item.author = @"Hugging Face";
        item.license = @"Apache-2.0";
        item.summary = L(@"Hugging Face Hub client for Swift, supporting model distribution & caching.",
                         @"Hugging Face 官方 Swift Hub 客户端，支持端侧轻量开源大模型的分发校验与本地沙盒快照缓存。");
        item.url = @"https://github.com/huggingface/swift-huggingface";
        item.licenseText = @"Apache License\nVersion 2.0, January 2004\n\nLicensed under the Apache License, Version 2.0 (the \"License\"); you may not use this file except in compliance with the License.\nYou may obtain a copy of the License at\nhttp://www.apache.org/licenses/LICENSE-2.0";
        [items addObject:item];
    }
    {
        HSBOpenSourceItem *item = [[HSBOpenSourceItem alloc] init];
        item.name = @"swift-transformers";
        item.author = @"Hugging Face";
        item.license = @"Apache-2.0";
        item.summary = L(@"State-of-the-art fast Tokenizers for Swift on-device model text processing.",
                         @"用于 Swift 的跨架构高性能 Tokenizer 分词器，支撑端侧模型的极速离线文本编解码与 Prompt 解析。");
        item.url = @"https://github.com/huggingface/swift-transformers";
        item.licenseText = @"Apache License\nVersion 2.0, January 2004\n\nLicensed under the Apache License, Version 2.0 (the \"License\"); you may not use this file except in compliance with the License.";
        [items addObject:item];
    }
    {
        HSBOpenSourceItem *item = [[HSBOpenSourceItem alloc] init];
        item.name = @"EventSource";
        item.author = @"Mattt";
        item.license = @"MIT";
        item.summary = L(@"Server-Sent Events (SSE) streaming client library for Swift.",
                         @"适用于 Swift 的现代 Server-Sent Events (SSE) 高性能流式客户端，支持智能大模型打字机流式输出。");
        item.url = @"https://github.com/mattt/EventSource";
        item.licenseText = @"MIT License\n\nCopyright (c) 2020-2024 Mattt (https://mattt.me)\n\nPermission is hereby granted, free of charge, to any person obtaining a copy of this software.";
        [items addObject:item];
    }
    {
        HSBOpenSourceItem *item = [[HSBOpenSourceItem alloc] init];
        item.name = @"yyjson";
        item.author = @"ibireme";
        item.license = @"MIT";
        item.summary = L(@"Super fast C JSON library for high-frequency payload parsing.",
                         @"超高性能 C 语言 JSON 编解码器，提供纳秒级极速数据封包与解析能力。");
        item.url = @"https://github.com/ibireme/yyjson";
        item.licenseText = @"MIT License\n\nCopyright (c) 2020 YaoYuan <ibireme@gmail.com>\n\nPermission is hereby granted, free of charge, to any person obtaining a copy of this software.";
        [items addObject:item];
    }
    {
        HSBOpenSourceItem *item = [[HSBOpenSourceItem alloc] init];
        item.name = @"swift-nio";
        item.author = @"Apple Inc.";
        item.license = @"Apache-2.0";
        item.summary = L(@"Cross-platform event-driven asynchronous network application framework.",
                         @"跨平台高性能事件驱动异步网络底层框架，支撑遥控器毫秒级低延迟高吞吐通信。");
        item.url = @"https://github.com/apple/swift-nio";
        item.licenseText = @"Apache License\nVersion 2.0, January 2004\n\nCopyright (c) Apple Inc. and the Swift project authors\nLicensed under Apache License v2.0.";
        [items addObject:item];
    }
    {
        HSBOpenSourceItem *item = [[HSBOpenSourceItem alloc] init];
        item.name = @"swift-crypto";
        item.author = @"Apple Inc.";
        item.license = @"Apache-2.0";
        item.summary = L(@"Open-source implementation of Apple CryptoKit cryptographic algorithms.",
                         @"Apple CryptoKit 密码学开源实现，提供 ChaCha20-Poly1305、Curve25519 与端到端传输加密通道加固。");
        item.url = @"https://github.com/apple/swift-crypto";
        item.licenseText = @"Apache License\nVersion 2.0, January 2004\n\nCopyright (c) Apple Inc. and the Swift project authors\nLicensed under Apache License v2.0.";
        [items addObject:item];
    }
    
    self.libraries = [items copy];
}

- (void)setupTableView {
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleInsetGrouped];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.backgroundColor = [HSBThemeManager shared].currentPalette.backgroundColor;
    self.tableView.separatorColor = [[UIColor whiteColor] colorWithAlphaComponent:0.08];
    
    // 顶部组件概览提示区
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width, 72)];
    UILabel *badge = [[UILabel alloc] initWithFrame:CGRectMake(20, 16, [UIScreen mainScreen].bounds.size.width - 40, 18)];
    badge.text = [NSString stringWithFormat:L(@"INTEGRATED COMPONENTS (%lu ITEMS)", @"已深度集成的开源引擎与核心组件 (共 %lu 项)"), (unsigned long)self.libraries.count];
    badge.font = [UIFont systemFontOfSize:12 weight:UIFontWeightBold];
    badge.textColor = [HSBThemeManager tanghuluBrandColor];
    [header addSubview:badge];
    
    UILabel *sub = [[UILabel alloc] initWithFrame:CGRectMake(20, 38, [UIScreen mainScreen].bounds.size.width - 40, 20)];
    sub.text = L(@"Strictly adheres to open-source licenses for secure communications & on-device AI.",
                 @"遵循开源软件许可协议，为大屏通信、端侧大模型与加密通道提供底层支撑。");
    sub.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
    sub.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.55];
    [header addSubview:sub];
    
    self.tableView.tableHeaderView = header;
    [self.view addSubview:self.tableView];
}

- (void)applyThemeStyle {
    [super applyThemeStyle];
    HSBThemePalette *palette = [HSBThemeManager shared].currentPalette;
    self.tableView.backgroundColor = palette.backgroundColor;
    [self.tableView reloadData];
}

#pragma mark - TableView DataSource & Delegate

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.libraries.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellId = @"HSBOpenSourceCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellId];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    
    HSBOpenSourceItem *item = self.libraries[indexPath.row];
    HSBThemePalette *palette = [HSBThemeManager shared].currentPalette;
    
    cell.backgroundColor = palette.cardBgColor;
    
    // 标题与作者
    NSString *mainTitle = [NSString stringWithFormat:@"%@  [%@]", item.name, item.license];
    NSMutableAttributedString *attrStr = [[NSMutableAttributedString alloc] initWithString:mainTitle attributes:@{
        NSForegroundColorAttributeName: [UIColor whiteColor],
        NSFontAttributeName: [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold]
    }];
    NSRange badgeRange = [mainTitle rangeOfString:[NSString stringWithFormat:@"[%@]", item.license]];
    if (badgeRange.location != NSNotFound) {
        [attrStr addAttributes:@{
            NSForegroundColorAttributeName: palette.primaryColor,
            NSFontAttributeName: [UIFont systemFontOfSize:12 weight:UIFontWeightMedium]
        } range:badgeRange];
    }
    cell.textLabel.attributedText = attrStr;
    
    // 副标题
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ · %@", item.author, item.summary];
    cell.detailTextLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.65];
    cell.detailTextLabel.numberOfLines = 2;
    cell.detailTextLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightRegular];
    
    UIView *selBg = [[UIView alloc] init];
    selBg.backgroundColor = [palette.primaryColor colorWithAlphaComponent:0.15];
    cell.selectedBackgroundView = selBg;
    
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 74.0;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    HSBOpenSourceItem *item = self.libraries[indexPath.row];
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:item.name
                                                                   message:[NSString stringWithFormat:@"作者：%@\n协议：%@\n\n%@", item.author, item.license, item.summary]
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    
    [alert addAction:[UIAlertAction actionWithTitle:L(@"View License Text", @"查看完整许可条款") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self showLicenseText:item];
    }]];
    
    if (item.url.length > 0) {
        [alert addAction:[UIAlertAction actionWithTitle:L(@"Visit Project Page", @"访问项目主页") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            NSURL *targetUrl = [NSURL URLWithString:item.url];
            if (targetUrl) {
                SFSafariViewController *safari = [[SFSafariViewController alloc] initWithURL:targetUrl];
                [self presentViewController:safari animated:YES completion:nil];
            }
        }]];
    }
    
    [alert addAction:[UIAlertAction actionWithTitle:L(@"Close", @"关闭") style:UIAlertActionStyleCancel handler:nil]];
    
    if (alert.popoverPresentationController) {
        alert.popoverPresentationController.sourceView = tableView;
        alert.popoverPresentationController.sourceRect = [tableView rectForRowAtIndexPath:indexPath];
    }
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showLicenseText:(HSBOpenSourceItem *)item {
    HSBBaseViewController *vc = [[HSBBaseViewController alloc] init];
    vc.title = [NSString stringWithFormat:@"%@ License", item.name];
    
    UITextView *tv = [[UITextView alloc] initWithFrame:vc.view.bounds];
    tv.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    tv.editable = NO;
    tv.backgroundColor = [HSBThemeManager shared].currentPalette.backgroundColor;
    tv.textColor = [UIColor whiteColor];
    tv.font = [UIFont fontWithName:@"Menlo" size:13] ?: [UIFont systemFontOfSize:13];
    tv.textContainerInset = UIEdgeInsetsMake(20, 20, 20, 20);
    tv.text = item.licenseText;
    
    [vc.view addSubview:tv];
    [self.navigationController pushViewController:vc animated:YES];
}

@end
