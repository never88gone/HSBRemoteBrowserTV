#import "HSBLLMModelCenterViewController.h"
#import "HSBLocalLLMManager.h"
#import "HSBThemeManager.h"
#import "HSBLLMTestViewController.h"

@interface HSBLLMModelCenterViewController ()
@property (nonatomic, strong) UITableView *tableView;
@end


@interface HSBLocalLLMModelCell : UITableViewCell
@property (nonatomic, strong) UIProgressView *progressView;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIButton *actionButton;
@property (nonatomic, strong) UIButton *testButton;
@end

@implementation HSBLocalLLMModelCell
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:reuseIdentifier];
    if (self) {
        self.progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
        self.progressView.translatesAutoresizingMaskIntoConstraints = NO;
        self.progressView.hidden = YES;
        [self.contentView addSubview:self.progressView];
        
        self.actionButton = [UIButton buttonWithType:UIButtonTypeSystem];
        self.actionButton.layer.cornerRadius = 8;
        
        self.testButton = [UIButton buttonWithType:UIButtonTypeSystem];
        self.testButton.layer.cornerRadius = 8;
        [self.testButton setTitle:@"测试" forState:UIControlStateNormal];
        
        [NSLayoutConstraint activateConstraints:@[
            [self.actionButton.heightAnchor constraintEqualToConstant:32],
            [self.actionButton.widthAnchor constraintEqualToConstant:60],
            [self.testButton.heightAnchor constraintEqualToConstant:32],
            [self.testButton.widthAnchor constraintEqualToConstant:60]
        ]];
        
        UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[self.actionButton, self.testButton]];
        stack.axis = UILayoutConstraintAxisHorizontal;
        stack.spacing = 10;
        stack.alignment = UIStackViewAlignmentCenter;
        stack.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:stack];
        
        [NSLayoutConstraint activateConstraints:@[
            [stack.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [stack.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-15],
            
            [self.progressView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:20],
            [self.progressView.trailingAnchor constraintEqualToAnchor:stack.leadingAnchor constant:-10],
            [self.progressView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-5]
        ]];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    // 计算右侧按钮所占用的宽度
    CGFloat rightMargin = 15; // 基础 margin
    if (!self.testButton.hidden) {
        rightMargin += 60 + 10 + 60; // 两个按钮 + 间距
    } else {
        rightMargin += 60; // 只有一个按钮
    }
    
    // 强制限制系统原生 label 的最大宽度，防止铺在按钮下方
    CGFloat maxLabelWidth = self.contentView.bounds.size.width - rightMargin - 20;
    
    CGRect textFrame = self.textLabel.frame;
    if (textFrame.size.width > maxLabelWidth) {
        textFrame.size.width = maxLabelWidth;
        self.textLabel.frame = textFrame;
    }
    
    CGRect detailFrame = self.detailTextLabel.frame;
    if (detailFrame.size.width > maxLabelWidth) {
        detailFrame.size.width = maxLabelWidth;
        self.detailTextLabel.frame = detailFrame;
    }
}
@end

@implementation HSBLLMModelCenterViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"AI 模型中心";
    
    UIBarButtonItem *apiItem = [[UIBarButtonItem alloc] initWithTitle:@"API配置"
                                                                style:UIBarButtonItemStylePlain
                                                               target:self
                                                               action:@selector(handleCustomAPIConfig)];
    
    UIBarButtonItem *addItem = [[UIBarButtonItem alloc] initWithTitle:@"添加模型"
                                                                style:UIBarButtonItemStylePlain
                                                               target:self
                                                               action:@selector(handleCustomModelAdding)];
    
    self.navigationItem.rightBarButtonItems = @[addItem, apiItem];
    
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.tableView registerClass:[HSBLocalLLMModelCell class] forCellReuseIdentifier:@"ModelCell"];
    [self.view addSubview:self.tableView];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleDownloadNotification:) name:@"HSBLocalLLMDownloadProgressNotification" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleDownloadNotification:) name:@"HSBLocalLLMDownloadFinishedNotification" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleDownloadNotification:) name:@"HSBLocalLLMDownloadFailedNotification" object:nil];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"UITestDemoDownloading"]) {
        if ([HSBLocalLLMManager shared].availableModels.count >= 3) {
            HSBLocalLLMModel *m0 = [HSBLocalLLMManager shared].availableModels[0];
            HSBLocalLLMModel *m1 = [HSBLocalLLMManager shared].availableModels[1];
            
            m0.status = HSBLocalLLMDownloadStatusFinished;
            [[HSBLocalLLMManager shared] activateModel:m0];
            
            m1.status = HSBLocalLLMDownloadStatusDownloading;
            m1.downloadProgress = 0.685;
            
            [self.tableView reloadData];
        }
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    if ([[NSUserDefaults standardUserDefaults] objectForKey:@"UITestTriggerDownloadIndex"]) {
        NSInteger downloadIdx = [[NSUserDefaults standardUserDefaults] integerForKey:@"UITestTriggerDownloadIndex"];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.6 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (downloadIdx < [HSBLocalLLMManager shared].availableModels.count) {
                UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
                btn.tag = downloadIdx;
                [self handleAction:btn];
            }
        });
    }
    
    if ([[NSUserDefaults standardUserDefaults] objectForKey:@"UITestVerifyModelActivationIndex"]) {
        NSInteger actIdx = [[NSUserDefaults standardUserDefaults] integerForKey:@"UITestVerifyModelActivationIndex"];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (actIdx < [HSBLocalLLMManager shared].availableModels.count) {
                HSBLocalLLMModel *m = [HSBLocalLLMManager shared].availableModels[actIdx];
                m.status = HSBLocalLLMDownloadStatusFinished;
                [[HSBLocalLLMManager shared] activateModel:m];
                [self.tableView reloadData];
            }
        });
    }
}

- (void)handleCustomAPIConfig {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"自定义大模型 API 配置"
                                                                   message:@"兼容 OpenAI / DeepSeek / Ollama / LM Studio 协议。\n配置后可在局域网或云端直接调用大模型，无需占用手机下载庞大端侧权重。"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = @"API 端点 (例如: http://192.168.1.100:11434/v1)";
        textField.text = [HSBLocalLLMManager customAPIEndpoint];
        textField.clearButtonMode = UITextFieldViewModeWhileEditing;
    }];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = @"API Key (可选，局域网 Ollama 可留空)";
        textField.text = [HSBLocalLLMManager customAPIKey];
        textField.clearButtonMode = UITextFieldViewModeWhileEditing;
    }];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = @"模型名称 (例如: deepseek-chat 或 qwen2.5:7b)";
        textField.text = [HSBLocalLLMManager customAPIModel];
        textField.clearButtonMode = UITextFieldViewModeWhileEditing;
    }];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"保存并开启" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        NSString *endpoint = alert.textFields[0].text;
        NSString *apiKey = alert.textFields[1].text;
        NSString *model = alert.textFields[2].text;
        
        [HSBLocalLLMManager setCustomAPIEndpoint:endpoint];
        [HSBLocalLLMManager setCustomAPIKey:apiKey];
        [HSBLocalLLMManager setCustomAPIModel:model];
        [HSBLocalLLMManager setUseCustomAPI:YES];
        
        [self.tableView reloadData];
    }]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)handleCustomModelAdding {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"添加自定义端侧模型"
                                                                   message:@"请输入自定义显示名称及 HuggingFace 上的 MLX 格式模型仓库 ID。\n\n【⚠️重要提醒】：\n1. 必须是经过 mlx 转换的 4-bit/8-bit 量化端侧模型，例如：mlx-community/Qwen1.5-0.5B-Chat-4bit。\n2. 暂不支持未量化的原始 PyTorch/Safetensors 大模型。\n3. 请确保网络状况可顺畅访问 HuggingFace 镜像源。"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = @"请输入模型显示名称 (例如: Qwen1.5-0.5B)";
        textField.clearButtonMode = UITextFieldViewModeWhileEditing;
    }];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = @"请输入下载地址 (例如: mlx-community/Qwen1.5-0.5B-Chat-4bit)";
        textField.clearButtonMode = UITextFieldViewModeWhileEditing;
    }];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"添加模型" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        UITextField *nameField = alert.textFields.firstObject;
        UITextField *repoField = alert.textFields.lastObject;
        NSString *name = [nameField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        NSString *repoId = [repoField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        
        NSError *error = nil;
        BOOL success = [[HSBLocalLLMManager shared] addCustomModelWithName:name repoId:repoId error:&error];
        if (success) {
            UIAlertController *hud = [UIAlertController alertControllerWithTitle:@"添加成功"
                                                                         message:[NSString stringWithFormat:@"模型 %@ 已成功添加！您可以向下滑动到列表底部查看并下载该模型。", name]
                                                                  preferredStyle:UIAlertControllerStyleAlert];
            [hud addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:hud animated:YES completion:nil];
            [self.tableView reloadData];
        } else {
            UIAlertController *hud = [UIAlertController alertControllerWithTitle:@"添加失败"
                                                                         message:error.localizedDescription ?: @"输入格式不合法或模型已存在。"
                                                                  preferredStyle:UIAlertControllerStyleAlert];
            [hud addAction:[UIAlertAction actionWithTitle:@"重新输入" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                [self handleCustomModelAdding];
            }]];
            [hud addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
            [self presentViewController:hud animated:YES completion:nil];
        }
    }]];
    
    [self presentViewController:alert animated:YES completion:nil];
}


- (void)applyThemeStyle {
    [super applyThemeStyle];
    HSBThemePalette *palette = [HSBThemeManager shared].currentPalette;
    self.tableView.backgroundColor = palette.backgroundColor;
    self.tableView.separatorColor = [[UIColor whiteColor] colorWithAlphaComponent:0.1];
    [self.tableView reloadData];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)handleDownloadNotification:(NSNotification *)note {
    if ([note.name isEqualToString:@"HSBLocalLLMDownloadFailedNotification"]) {
        NSError *error = note.userInfo[@"error"];
        HSBLocalLLMModel *model = note.object;
        dispatch_async(dispatch_get_main_queue(), ^{
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"模型下载未完成"
                                                                           message:[NSString stringWithFormat:@"%@\n\n提示：端侧大模型体积较大，受国际网络带宽与镜像源影响可能超时。您可以点击“重试”，或直接使用“自定义 API 模式”免下载调用顶级大模型。", error.localizedDescription ?: @"未知网络错误"]
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"重试下载" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                if (model) {
                    [[HSBLocalLLMManager shared] downloadModel:model progress:^(double p) {} completion:^(BOOL success, NSError * _Nullable err) {}];
                    [self.tableView reloadData];
                }
            }]];
            [alert addAction:[UIAlertAction actionWithTitle:@"配置 API (免下载)" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                [self handleCustomAPIConfig];
            }]];
            [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
            [self presentViewController:alert animated:YES completion:nil];
        });
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.tableView reloadData];
    });
}

- (void)translationSwitchChanged:(UISwitch *)sender {
    [HSBLocalLLMManager setUseAppleTranslation:sender.on];
    [self.tableView reloadData];
}

- (void)customAPISwitchChanged:(UISwitch *)sender {
    [HSBLocalLLMManager setUseCustomAPI:sender.on];
    [self.tableView reloadData];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) {
        return 3;
    }
    return [HSBLocalLLMManager shared].availableModels.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) {
        return @"AI 引擎与翻译配置";
    }
    return [HSBLocalLLMManager useAppleTranslation] ? @"电视控制 JS 脚本生成专用模型 (端侧)" : @"通用端侧大模型 (翻译与JS生成共用)";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    HSBThemePalette *palette = [HSBThemeManager shared].currentPalette;
    
    if (indexPath.section == 0) {
        if (indexPath.row == 0) {
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"StatusCell"];
            if (!cell) {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"StatusCell"];
            }
            cell.textLabel.text = @"当前运行 AI 引擎";
            cell.detailTextLabel.text = [HSBLocalLLMManager shared].currentEngineDisplayName;
            cell.detailTextLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
            cell.detailTextLabel.textColor = palette.primaryColor;
            cell.imageView.image = [UIImage systemImageNamed:@"bolt.shield.fill"];
            cell.imageView.tintColor = [UIColor systemGreenColor];
            cell.backgroundColor = palette.cardBgColor;
            cell.textLabel.textColor = [UIColor whiteColor];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            cell.accessoryView = nil;
            return cell;
        } else if (indexPath.row == 1) {
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"APISettingCell"];
            if (!cell) {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"APISettingCell"];
            }
            cell.imageView.image = nil;
            cell.textLabel.text = @"自定义大模型 API 模式";
            BOOL isCustomAPI = [HSBLocalLLMManager useCustomAPI];
            if (isCustomAPI) {
                cell.detailTextLabel.text = [NSString stringWithFormat:@"已开启 (%@: %@) - 点击可修改配置", [HSBLocalLLMManager customAPIModel], [HSBLocalLLMManager customAPIEndpoint]];
                cell.detailTextLabel.textColor = palette.primaryColor;
            } else {
                cell.detailTextLabel.text = @"开启后直连局域网或云端 API (Ollama/LMStudio/DeepSeek)，免下载几百兆文件。点击配置。";
                cell.detailTextLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.6];
            }
            cell.detailTextLabel.numberOfLines = 0;
            cell.detailTextLabel.font = [UIFont systemFontOfSize:11];
            cell.backgroundColor = palette.cardBgColor;
            cell.textLabel.textColor = [UIColor whiteColor];
            
            UISwitch *sw = [[UISwitch alloc] init];
            sw.on = isCustomAPI;
            sw.onTintColor = palette.primaryColor;
            [sw addTarget:self action:@selector(customAPISwitchChanged:) forControlEvents:UIControlEventValueChanged];
            cell.accessoryView = sw;
            cell.selectionStyle = UITableViewCellSelectionStyleDefault;
            return cell;
        } else if (indexPath.row == 2) {
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"SettingCell"];
            if (!cell) {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"SettingCell"];
            }
            cell.imageView.image = nil;
            cell.textLabel.text = @"使用 Apple 原生翻译框架";
            cell.detailTextLabel.text = @"开启后，翻译将调用 iOS 原生 Translation API，本地大模型仅用于 JS 脚本生成。";
            cell.detailTextLabel.numberOfLines = 0;
            cell.detailTextLabel.font = [UIFont systemFontOfSize:11];
            
            cell.backgroundColor = palette.cardBgColor;
            cell.textLabel.textColor = [UIColor whiteColor];
            cell.detailTextLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.6];
            
            UISwitch *sw = [[UISwitch alloc] init];
            sw.on = [HSBLocalLLMManager useAppleTranslation];
            sw.onTintColor = palette.primaryColor;
            [sw addTarget:self action:@selector(translationSwitchChanged:) forControlEvents:UIControlEventValueChanged];
            cell.accessoryView = sw;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            return cell;
        }
    }
    
    HSBLocalLLMModelCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ModelCell" forIndexPath:indexPath];
    HSBLocalLLMModel *model = [HSBLocalLLMManager shared].availableModels[indexPath.row];
    
    cell.textLabel.text = model.name;
    if (model.status == HSBLocalLLMDownloadStatusDownloading) {
        cell.detailTextLabel.text = [NSString stringWithFormat:@"正在高速拉取端侧权重: %.1f%%", model.downloadProgress * 100];
        cell.detailTextLabel.textColor = palette.primaryColor;
    } else if (model.status == HSBLocalLLMDownloadStatusFailed) {
        cell.detailTextLabel.text = @"下载连接异常，可点击“重试”或左滑清除缓存";
        cell.detailTextLabel.textColor = [UIColor systemOrangeColor];
    } else {
        cell.detailTextLabel.text = model.modelDescription;
        cell.detailTextLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.6];
    }
    
    // OLED 高奢暗黑换肤适配
    cell.backgroundColor = palette.cardBgColor;
    cell.textLabel.textColor = [UIColor whiteColor];
    cell.detailTextLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.6];
    cell.actionButton.tintColor = palette.primaryColor;
    cell.actionButton.backgroundColor = [palette.primaryColor colorWithAlphaComponent:0.1];
    
    cell.testButton.tintColor = palette.secondaryColor ?: [UIColor systemPurpleColor];
    cell.testButton.backgroundColor = [(palette.secondaryColor ?: [UIColor systemPurpleColor]) colorWithAlphaComponent:0.1];
    
    cell.progressView.progressTintColor = palette.primaryColor;
    cell.progressView.trackTintColor = [[UIColor whiteColor] colorWithAlphaComponent:0.1];
    
    UIView *bgView = [[UIView alloc] init];
    bgView.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.05];
    cell.selectedBackgroundView = bgView;
    
    BOOL isCurrentlyActive = [HSBLocalLLMManager useAppleTranslation] ? model.isJSActive : model.isActive;
    
    if (isCurrentlyActive) {
        [cell.actionButton setTitle:@"关闭" forState:UIControlStateNormal];
        cell.actionButton.tintColor = [UIColor systemRedColor];
        cell.actionButton.backgroundColor = [[UIColor systemRedColor] colorWithAlphaComponent:0.1];
    } else if (model.status == HSBLocalLLMDownloadStatusFinished) {
        [cell.actionButton setTitle:@"激活" forState:UIControlStateNormal];
    } else if (model.status == HSBLocalLLMDownloadStatusDownloading) {
        [cell.actionButton setTitle:@"暂停" forState:UIControlStateNormal];
    } else if (model.status == HSBLocalLLMDownloadStatusPaused) {
        [cell.actionButton setTitle:@"继续" forState:UIControlStateNormal];
    } else if (model.status == HSBLocalLLMDownloadStatusFailed) {
        [cell.actionButton setTitle:@"重试" forState:UIControlStateNormal];
        cell.actionButton.tintColor = [UIColor systemOrangeColor];
        cell.actionButton.backgroundColor = [[UIColor systemOrangeColor] colorWithAlphaComponent:0.15];
    } else {
        [cell.actionButton setTitle:@"下载" forState:UIControlStateNormal];
    }
    
    // 只有激活了才显示测试按钮
    cell.testButton.hidden = !isCurrentlyActive;
    
    [cell.actionButton removeTarget:nil action:NULL forControlEvents:UIControlEventTouchUpInside];
    [cell.actionButton addTarget:self action:@selector(handleAction:) forControlEvents:UIControlEventTouchUpInside];
    cell.actionButton.tag = indexPath.row;
    
    [cell.testButton removeTarget:nil action:NULL forControlEvents:UIControlEventTouchUpInside];
    [cell.testButton addTarget:self action:@selector(handleTestAction:) forControlEvents:UIControlEventTouchUpInside];
    cell.testButton.tag = indexPath.row;
    
    cell.progressView.hidden = (model.status == HSBLocalLLMDownloadStatusNone || model.status == HSBLocalLLMDownloadStatusFinished || model.status == HSBLocalLLMDownloadStatusFailed);
    cell.progressView.progress = model.downloadProgress;
    
    return cell;
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) return nil;
    
    HSBLocalLLMModel *model = [HSBLocalLLMManager shared].availableModels[indexPath.row];
    
    UIContextualAction *deleteAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive title:@"清除缓存" handler:^(UIContextualAction * _Nonnull action, __kindof UIView * _Nonnull sourceView, void (^ _Nonnull completionHandler)(BOOL)) {
        BOOL ok = [[HSBLocalLLMManager shared] deleteModelCacheForModel:model];
        [self.tableView reloadData];
        completionHandler(ok);
    }];
    deleteAction.backgroundColor = [UIColor systemRedColor];
    deleteAction.image = [UIImage systemImageNamed:@"trash.fill"];
    
    return [UISwipeActionsConfiguration configurationWithActions:@[deleteAction]];
}

- (void)handleAction:(UIButton *)sender {
    NSInteger index = sender.tag;
    HSBLocalLLMModel *model = [HSBLocalLLMManager shared].availableModels[index];
    
    BOOL useApple = [HSBLocalLLMManager useAppleTranslation];
    BOOL isCurrentlyActive = useApple ? model.isJSActive : model.isActive;
    
    if (isCurrentlyActive) {
        if (useApple) {
            [[HSBLocalLLMManager shared] deactivateJSModel:model];
        } else {
            [[HSBLocalLLMManager shared] deactivateModel:model];
        }
    } else if (model.status == HSBLocalLLMDownloadStatusNone || model.status == HSBLocalLLMDownloadStatusPaused || model.status == HSBLocalLLMDownloadStatusFailed) {
        [[HSBLocalLLMManager shared] downloadModel:model progress:^(double p) {} completion:^(BOOL success, NSError * _Nullable error) {}];
    } else if (model.status == HSBLocalLLMDownloadStatusDownloading) {
        [[HSBLocalLLMManager shared] pauseDownloadModel:model];
    } else if (model.status == HSBLocalLLMDownloadStatusFinished) {
        if (useApple) {
            [[HSBLocalLLMManager shared] activateJSModel:model];
        } else {
            [[HSBLocalLLMManager shared] activateModel:model];
        }
    }
    [self.tableView reloadData];
}

- (void)handleTestAction:(UIButton *)sender {
    NSInteger index = sender.tag;
    HSBLocalLLMModel *model = [HSBLocalLLMManager shared].availableModels[index];
    
    BOOL useApple = [HSBLocalLLMManager useAppleTranslation];
    BOOL isCurrentlyActive = useApple ? model.isJSActive : model.isActive;
    
    if (!isCurrentlyActive) {
        if (useApple) {
            [[HSBLocalLLMManager shared] activateJSModel:model];
        } else {
            [[HSBLocalLLMManager shared] activateModel:model];
        }
        [self.tableView reloadData];
    }
    
    HSBLLMTestViewController *testVC = [[HSBLLMTestViewController alloc] init];
    [self.navigationController pushViewController:testVC animated:YES];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 70;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == 0 && indexPath.row == 1) {
        [self handleCustomAPIConfig];
    }
}


@end
