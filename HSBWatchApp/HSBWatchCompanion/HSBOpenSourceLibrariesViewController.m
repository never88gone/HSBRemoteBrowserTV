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
    self.title = L(@"Open Source Libraries", @"第三方开源库");
    
    [self setupData];
    [self setupTableView];
}

- (void)setupData {
    NSMutableArray *items = [NSMutableArray array];
    
    {
        HSBOpenSourceItem *item = [[HSBOpenSourceItem alloc] init];
        item.name = @"itsytv-macos";
        item.author = @"Nick Ustinov";
        item.license = @"MIT";
        item.summary = L(@"Apple TV remote control with Companion Link protocol & system-level media interaction.",
                         @"Apple TV 原生遥控器通信协议与 Companion Link 系统级媒体按键交互参考实现。");
        item.url = @"https://github.com/nickustinov/itsytv-macos";
        item.licenseText = @"MIT License\n\nCopyright (c) 2024 Nick Ustinov\n\nPermission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the \"Software\"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:\n\nThe above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.";
        [items addObject:item];
    }
    {
        HSBOpenSourceItem *item = [[HSBOpenSourceItem alloc] init];
        item.name = @"mlx-swift";
        item.author = @"Apple Inc.";
        item.license = @"MIT";
        item.summary = L(@"Apple Silicon unified memory machine learning framework.",
                         @"面向 Apple Silicon 统一内存优化的高性能端侧机器学习与张量计算框架。");
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
                         @"基于 Apple MLX 的端侧大语言模型推理流水线与轻量权重加载器。");
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
                         @"Hugging Face 官方 Swift Hub 客户端，支持端侧模型分发校验与本地快照缓存。");
        item.url = @"https://github.com/huggingface/swift-huggingface";
        item.licenseText = @"Apache License\nVersion 2.0, January 2004\n\nLicensed under the Apache License, Version 2.0 (the \"License\"); you may not use this file except in compliance with the License.\nYou may obtain a copy of the License at\nhttp://www.apache.org/licenses/LICENSE-2.0";
        [items addObject:item];
    }
    {
        HSBOpenSourceItem *item = [[HSBOpenSourceItem alloc] init];
        item.name = @"EventSource";
        item.author = @"Mattt";
        item.license = @"MIT";
        item.summary = L(@"Server-Sent Events (SSE) streaming client library for Swift.",
                         @"适用于 Swift 的现代 Server-Sent Events (SSE) 高性能流式客户端。");
        item.url = @"https://github.com/mattt/EventSource";
        item.licenseText = @"MIT License\n\nCopyright (c) 2020-2024 Mattt (https://mattt.me)\n\nPermission is hereby granted, free of charge, to any person obtaining a copy of this software.";
        [items addObject:item];
    }
    {
        HSBOpenSourceItem *item = [[HSBOpenSourceItem alloc] init];
        item.name = @"swift-nio";
        item.author = @"Apple Inc.";
        item.license = @"Apache-2.0";
        item.summary = L(@"Cross-platform event-driven asynchronous network application framework.",
                         @"跨平台高性能事件驱动异步网络底层框架，支撑高吞吐连接。");
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
                         @"Apple CryptoKit 密码学开源实现，用于端到端数据传输加密加固。");
        item.url = @"https://github.com/apple/swift-crypto";
        item.licenseText = @"Apache License\nVersion 2.0, January 2004\n\nCopyright (c) Apple Inc. and the Swift project authors\nLicensed under Apache License v2.0.";
        [items addObject:item];
    }
    {
        HSBOpenSourceItem *item = [[HSBOpenSourceItem alloc] init];
        item.name = @"Network.framework";
        item.author = @"Apple Developer";
        item.license = @"Apple Platform";
        item.summary = L(@"Modern Bonjour, AWDL, and low-latency transport framework.",
                         @"苹果现代局域网 Bonjour 服务发现、AWDL 专线及低延迟传输底层框架。");
        item.url = @"https://developer.apple.com/documentation/network";
        item.licenseText = @"Provided by Apple Developer SDK as system standard networking component.";
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
