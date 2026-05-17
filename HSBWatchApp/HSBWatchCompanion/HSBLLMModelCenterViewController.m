#import "HSBLLMModelCenterViewController.h"
#import "HSBLocalLLMManager.h"
#import "HSBThemeManager.h"

@interface HSBLLMModelCenterViewController ()
@property (nonatomic, strong) UITableView *tableView;
@end


@interface HSBLocalLLMModelCell : UITableViewCell
@property (nonatomic, strong) UIProgressView *progressView;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIButton *actionButton;
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
        self.actionButton.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:self.actionButton];
        
        [NSLayoutConstraint activateConstraints:@[
            [self.actionButton.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [self.actionButton.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-15],
            [self.actionButton.widthAnchor constraintEqualToConstant:80],
            
            [self.progressView.leadingAnchor constraintEqualToAnchor:self.textLabel.leadingAnchor],
            [self.progressView.trailingAnchor constraintEqualToAnchor:self.actionButton.leadingAnchor constant:-10],
            [self.progressView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-5]
        ]];
    }
    return self;
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
    cell.progressView.progressTintColor = palette.primaryColor;
    cell.progressView.trackTintColor = [[UIColor whiteColor] colorWithAlphaComponent:0.1];
    
    UIView *bgView = [[UIView alloc] init];
    bgView.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.05];
    cell.selectedBackgroundView = bgView;
    
    if (model.isActive) {
        [cell.actionButton setTitle:@"运行中" forState:UIControlStateNormal];
        cell.actionButton.enabled = NO;
    } else if (model.status == HSBLocalLLMDownloadStatusFinished) {
        [cell.actionButton setTitle:@"激活" forState:UIControlStateNormal];
        cell.actionButton.enabled = YES;
    } else if (model.status == HSBLocalLLMDownloadStatusDownloading) {
        [cell.actionButton setTitle:@"暂停" forState:UIControlStateNormal];
        cell.actionButton.enabled = YES;
    } else if (model.status == HSBLocalLLMDownloadStatusPaused) {
        [cell.actionButton setTitle:@"继续" forState:UIControlStateNormal];
        cell.actionButton.enabled = YES;
    } else {
        [cell.actionButton setTitle:@"下载" forState:UIControlStateNormal];
        cell.actionButton.enabled = YES;
    }
    
    [cell.actionButton removeTarget:nil action:NULL forControlEvents:UIControlEventTouchUpInside];
    [cell.actionButton addTarget:self action:@selector(handleAction:) forControlEvents:UIControlEventTouchUpInside];
    cell.actionButton.tag = indexPath.row;
    
    cell.progressView.hidden = (model.status == HSBLocalLLMDownloadStatusNone || model.status == HSBLocalLLMDownloadStatusFinished);
    cell.progressView.progress = model.downloadProgress;
    
    return cell;
}

- (void)handleAction:(UIButton *)sender {
    NSInteger index = sender.tag;
    HSBLocalLLMModel *model = [HSBLocalLLMManager shared].availableModels[index];
    
    if (model.status == HSBLocalLLMDownloadStatusNone || model.status == HSBLocalLLMDownloadStatusPaused || model.status == HSBLocalLLMDownloadStatusFailed) {
        [[HSBLocalLLMManager shared] downloadModel:model progress:^(double p) {} completion:^(BOOL success, NSError * _Nullable error) {}];
    } else if (model.status == HSBLocalLLMDownloadStatusDownloading) {
        [[HSBLocalLLMManager shared] pauseDownloadModel:model];
    } else if (model.status == HSBLocalLLMDownloadStatusFinished) {
        [[HSBLocalLLMManager shared] activateModel:model];
    }
    [self.tableView reloadData];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 70;
}

@end
