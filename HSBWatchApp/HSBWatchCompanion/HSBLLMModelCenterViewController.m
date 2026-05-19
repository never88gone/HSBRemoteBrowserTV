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
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"下载失败"
                                                                           message:[NSString stringWithFormat:@"%@\n\n是否启用“离线模拟模式”直接生成模拟模型以供测试？", error.localizedDescription ?: @"未知网络错误"]
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
            [alert addAction:[UIAlertAction actionWithTitle:@"启用模拟模式" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                [self enableDemoModeForModel:model];
            }]];
            [self presentViewController:alert animated:YES completion:nil];
        });
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.tableView reloadData];
    });
}

- (void)enableDemoModeForModel:(HSBLocalLLMModel *)model {
    if (!model) return;
    NSString *docDir = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    NSString *modelcPath = [docDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.mlmodelc", model.modelId]];
    [[NSFileManager defaultManager] createDirectoryAtPath:modelcPath withIntermediateDirectories:YES attributes:nil error:nil];
    
    model.status = HSBLocalLLMDownloadStatusFinished;
    model.downloadProgress = 1.0;
    
    [self.tableView reloadData];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [HSBLocalLLMManager shared].availableModels.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    HSBLocalLLMModelCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ModelCell" forIndexPath:indexPath];
    HSBLocalLLMModel *model = [HSBLocalLLMManager shared].availableModels[indexPath.row];
    
    cell.textLabel.text = model.name;
    cell.detailTextLabel.text = model.modelDescription;
    
    // OLED 高奢暗黑换肤适配
    HSBThemePalette *palette = [HSBThemeManager shared].currentPalette;
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
    
    if (model.isActive) {
        [cell.actionButton setTitle:@"关闭" forState:UIControlStateNormal];
        cell.actionButton.tintColor = [UIColor systemRedColor];
        cell.actionButton.backgroundColor = [[UIColor systemRedColor] colorWithAlphaComponent:0.1];
    } else if (model.status == HSBLocalLLMDownloadStatusFinished) {
        [cell.actionButton setTitle:@"激活" forState:UIControlStateNormal];
    } else if (model.status == HSBLocalLLMDownloadStatusDownloading) {
        [cell.actionButton setTitle:@"暂停" forState:UIControlStateNormal];
    } else if (model.status == HSBLocalLLMDownloadStatusPaused) {
        [cell.actionButton setTitle:@"继续" forState:UIControlStateNormal];
    } else {
        [cell.actionButton setTitle:@"下载" forState:UIControlStateNormal];
    }
    
    // 只有激活了才显示测试按钮
    cell.testButton.hidden = !model.isActive;
    
    [cell.actionButton removeTarget:nil action:NULL forControlEvents:UIControlEventTouchUpInside];
    [cell.actionButton addTarget:self action:@selector(handleAction:) forControlEvents:UIControlEventTouchUpInside];
    cell.actionButton.tag = indexPath.row;
    
    [cell.testButton removeTarget:nil action:NULL forControlEvents:UIControlEventTouchUpInside];
    [cell.testButton addTarget:self action:@selector(handleTestAction:) forControlEvents:UIControlEventTouchUpInside];
    cell.testButton.tag = indexPath.row;
    
    cell.progressView.hidden = (model.status == HSBLocalLLMDownloadStatusNone || model.status == HSBLocalLLMDownloadStatusFinished);
    cell.progressView.progress = model.downloadProgress;
    
    return cell;
}

- (void)handleAction:(UIButton *)sender {
    NSInteger index = sender.tag;
    HSBLocalLLMModel *model = [HSBLocalLLMManager shared].availableModels[index];
    
    if (model.isActive) {
        [[HSBLocalLLMManager shared] deactivateModel:model];
    } else if (model.status == HSBLocalLLMDownloadStatusNone || model.status == HSBLocalLLMDownloadStatusPaused || model.status == HSBLocalLLMDownloadStatusFailed) {
        [[HSBLocalLLMManager shared] downloadModel:model progress:^(double p) {} completion:^(BOOL success, NSError * _Nullable error) {}];
    } else if (model.status == HSBLocalLLMDownloadStatusDownloading) {
        [[HSBLocalLLMManager shared] pauseDownloadModel:model];
    } else if (model.status == HSBLocalLLMDownloadStatusFinished) {
        [[HSBLocalLLMManager shared] activateModel:model];
    }
    [self.tableView reloadData];
}

- (void)handleTestAction:(UIButton *)sender {
    NSInteger index = sender.tag;
    HSBLocalLLMModel *model = [HSBLocalLLMManager shared].availableModels[index];
    
    // 如果用户点击了测试，但模型还没激活，为了体验流畅，我们可以自动帮他激活（或提示他激活）
    if (!model.isActive) {
        [[HSBLocalLLMManager shared] activateModel:model];
        [self.tableView reloadData];
    }
    
    HSBLLMTestViewController *testVC = [[HSBLLMTestViewController alloc] init];
    [self.navigationController pushViewController:testVC animated:YES];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 70;
}

@end
