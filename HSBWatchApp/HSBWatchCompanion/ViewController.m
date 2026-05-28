//
//  ViewController.m
//  HSBWatchCompanion
//

#import "ViewController.h"
#import <UIKit/UIKit.h>
#import <Network/Network.h>
#import <CoreMotion/CoreMotion.h>
#import "HomeConfigEditViewController.h"
#import "BrowserControlViewController.h"
#import "SettingsViewController.h"
#import "HSBTVOSConnectionManager.h"
#import "TVDetailViewController.h"
#import "HSBThemeManager.h"
#import "HSBTVOSConnectionManager.h"
#import "HSBWatchSessionManager.h"
#import "HSBLocalLLMManager.h"
#import "HSBWatchCompanion-Swift.h"

#define BONJOUR_SERVICE_TYPE "_thltv._tcp"

static NSString * L(NSString *en, NSString *zh) {
    NSString *language = [[NSLocale preferredLanguages] firstObject];
    if ([language hasPrefix:@"zh"]) {
        return zh ?: en;
    }
    return en;
}



@interface ViewController () <UITableViewDelegate, UITableViewDataSource, UIGestureRecognizerDelegate, UITextFieldDelegate>

@property (nonatomic, strong) nw_browser_t browser;
@property (nonatomic, strong) dispatch_queue_t browserQueue;
@property (nonatomic, assign) BOOL isConnectedToTV;

// UI Properties
@property (nonatomic, strong) UILabel *watchStatusLabel;
@property (nonatomic, strong) UILabel *tvStatusLabel;
@property (nonatomic, strong) UILabel *logLabel;
@property (nonatomic, strong) UITableView *tvTableView;
@property (nonatomic, strong) UIActivityIndicatorView *scanSpinner;
@property (nonatomic, strong) UISwitch *watchSyncSwitch;
@property (nonatomic, strong) UISwitch *tvScanSwitch;
@property (nonatomic, assign) BOOL watchSyncEnabled;
@property (nonatomic, assign) BOOL tvScanEnabled;

// Data Source
@property (nonatomic, strong) NSMutableArray<nw_endpoint_t> *discoveredEndpoints;
@property (nonatomic, strong) nw_endpoint_t currentEndpoint;

// Video Control UI
@property (nonatomic, strong) UIView *videoControlCard;
@property (nonatomic, strong) UISlider *videoSlider;
@property (nonatomic, strong) UILabel *currentTimeLabel;
@property (nonatomic, strong) UILabel *durationLabel;
@property (nonatomic, assign) BOOL isDraggingSlider;

// Browser Control UI
@property (nonatomic, strong) UIView *browserControlCard;
@property (nonatomic, strong) UIView *trackpadView;
@property (nonatomic, strong) UILabel *trackpadStatusLabel; // 当前操作状态提示
@property (nonatomic, assign) CFTimeInterval lastPanSendTime;  // 单指滑动节流
@property (nonatomic, assign) CFTimeInterval lastScrollSendTime; // 双指滚动节流
@property (nonatomic, assign) BOOL isDragging; // Drag visual state
@property (nonatomic, strong) UITextField *mainUrlTextField; // 主界面 URL 输入框

// Activity Stats UI
@property (nonatomic, strong) UIView *statsCard;
@property (nonatomic, strong) UILabel *statsLabel;
@property (nonatomic, strong) UILabel *stepsLabel; // 计步器展示

@property (nonatomic, strong) CMPedometer *pedometer;
@property (nonatomic, assign) NSInteger dailyActionCount;
@property (nonatomic, assign) NSInteger dailyTargetCount;

// Theme controls upgrade
@property (nonatomic, strong) UIButton *goBtn;
@property (nonatomic, strong) UIButton *openTrackpadBtn;
@property (nonatomic, strong) NSMutableArray<UIView *> *themeCards;

@property (nonatomic, strong) UIVisualEffectView *aiLoadingHUD;

@end

@implementation ViewController

- (void)viewDidLoad {
    self.themeCards = [NSMutableArray array];
    self.discoveredEndpoints = [NSMutableArray array];
    
    self.watchSyncEnabled = YES;
    if ([[NSUserDefaults standardUserDefaults] objectForKey:@"WatchSyncEnabled"]) {
        self.watchSyncEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"WatchSyncEnabled"];
    }
    
    self.tvScanEnabled = YES;
    if ([[NSUserDefaults standardUserDefaults] objectForKey:@"TVScanEnabled"]) {
        self.tvScanEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"TVScanEnabled"];
    }
    
    [super viewDidLoad];
    
    // Prevent the iPhone screen from sleeping and dropping the network connection
    [UIApplication sharedApplication].idleTimerDisabled = YES;
    
    [self loadDailyStats];
    [self setupUI];
    [self startBridge];
    [self startPedometer];
    
    [self setupAILoadingHUD];
    
    // 监听本地大模型异步后台载入（预热）状态的广播通知
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleLLMPrewarmingStarted:) name:@"HSBLocalLLM_PrewarmingStartedNotification" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleLLMPrewarmingFinished:) name:@"HSBLocalLLM_PrewarmingFinishedNotification" object:nil];
    
    // 🥇 开机即时检测：若当前已激活大模型，且底层内存尚未完成装载，则直接拉起 Loading，保证状态丝滑同步
    BOOL hasActiveModel = [HSBLocalLLMManager shared].activeModel != nil;
    BOOL isLoaded = [[HSBMLXLLMEngine shared] isModelLoadedInMemory];
    if (hasActiveModel && !isLoaded) {
        self.aiLoadingHUD.hidden = NO;
        self.aiLoadingHUD.alpha = 1.0;
    }
    
    // 注册 TVOSConnectionManager 通知
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleTVOSConnectionStateChanged:) name:HSBTVOSConnectionStateNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleTVOSStateUpdated:) name:HSBTVOSStateUpdatedNotification object:nil];
    
    [self applyThemeStyle];
}

- (void)applyThemeStyle {
    [super applyThemeStyle];
    HSBThemePalette *palette = [HSBThemeManager shared].currentPalette;
    
    for (UIView *card in self.themeCards) {
        card.backgroundColor = palette.cardBgColor;
    }
    
    if (self.goBtn) {
        self.goBtn.tintColor = palette.primaryColor;
    }
    if (self.openTrackpadBtn) {
        self.openTrackpadBtn.backgroundColor = palette.primaryColor;
    }
    if (self.videoSlider) {
        self.videoSlider.minimumTrackTintColor = palette.primaryColor;
    }
    if (self.watchSyncSwitch) {
        self.watchSyncSwitch.onTintColor = palette.primaryColor;
    }
    if (self.tvScanSwitch) {
        self.tvScanSwitch.onTintColor = palette.primaryColor;
    }
    
    // 动态同步首页右上角设置齿轮按钮的颜色
    self.navigationItem.rightBarButtonItem.tintColor = palette.primaryColor;
    
    // 实时重绘主列表里的电视设备图标颜色
    if (self.tvTableView) {
        [self.tvTableView reloadData];
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}


#pragma mark - Pedometer & Activity Logic

- (void)startPedometer {
    if ([CMPedometer isStepCountingAvailable]) {
        self.pedometer = [[CMPedometer alloc] init];
        
        NSCalendar *calendar = [NSCalendar currentCalendar];
        NSDate *midnight = [calendar startOfDayForDate:[NSDate date]];
        
        __weak typeof(self) weakSelf = self;
        [self.pedometer startPedometerUpdatesFromDate:midnight withHandler:^(CMPedometerData * _Nullable pedometerData, NSError * _Nullable error) {
            if (!error && pedometerData) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (weakSelf.stepsLabel) {
                        weakSelf.stepsLabel.text = [NSString stringWithFormat:L(@"Local Steps (Today): %@", @"今日设备走动步数: %@"), pedometerData.numberOfSteps];
                    }
                });
            }
        }];
    }
}

- (NSString *)todayKey {
    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    df.dateFormat = @"yyyyMMdd";
    return [NSString stringWithFormat:@"ActivityCount_%@", [df stringFromDate:[NSDate date]]];
}

- (void)loadDailyStats {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    self.dailyActionCount = [defaults integerForKey:[self todayKey]];
    self.dailyTargetCount = [defaults integerForKey:@"ActivityTargetCount"];
    if (self.dailyTargetCount == 0) {
        self.dailyTargetCount = 100; // Default goal
    }
}

- (void)incrementActivityScore {
    self.dailyActionCount++;
    [[NSUserDefaults standardUserDefaults] setInteger:self.dailyActionCount forKey:[self todayKey]];
    [self updateStatsUI];
}

- (void)updateStatsUI {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.statsLabel.text = [NSString stringWithFormat:L(@"Today's Progress: %ld / %ld", @"今日达成: %ld / %ld 的目标频次"), (long)self.dailyActionCount, (long)self.dailyTargetCount];
        // Green if goal reached
        if (self.dailyActionCount >= self.dailyTargetCount) {
            self.statsLabel.textColor = [UIColor systemGreenColor];
        } else {
            self.statsLabel.textColor = [UIColor labelColor];
        }
    });
}

- (void)showSetGoalAlert {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:L(@"Define Goal", @"设置每日目标") message:L(@"Set your daily target gestures", @"请输入您设定的每日训练动作目标次数") preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.keyboardType = UIKeyboardTypeNumberPad;
        textField.text = [NSString stringWithFormat:@"%ld", (long)self.dailyTargetCount];
    }];
    [alert addAction:[UIAlertAction actionWithTitle:L(@"Save", @"保存") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        NSString *text = alert.textFields.firstObject.text;
        if (text && text.integerValue > 0) {
            self.dailyTargetCount = text.integerValue;
            [[NSUserDefaults standardUserDefaults] setInteger:self.dailyTargetCount forKey:@"ActivityTargetCount"];
            [self updateStatsUI];
        }
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:L(@"Cancel", @"取消") style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}



#pragma mark - UI Setup

- (void)setupUI {
    self.navigationItem.title = L(@"ZE Watch", @"糖葫芦遥控器");
    
    // Settings Button
    UIBarButtonItem *settingsItem = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"gearshape.fill"] style:UIBarButtonItemStylePlain target:self action:@selector(openSettings)];
    settingsItem.tintColor = [UIColor whiteColor];
    self.navigationItem.rightBarButtonItem = settingsItem;
    
    // Subtitle
    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.text = L(@"Keep this app open while using your Watch.", @"在使用手表遥控时保持此应用在前台运行");
    subtitleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    subtitleLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.6];
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:subtitleLabel];
    
    self.watchStatusLabel = [self createLabel];
    self.tvStatusLabel = [self createLabel];
    self.logLabel = [self createLabel];
    self.statsLabel = [self createLabel];
    
    self.watchSyncSwitch = [[UISwitch alloc] init];
    self.watchSyncSwitch.translatesAutoresizingMaskIntoConstraints = NO;
    [self.watchSyncSwitch setOn:self.watchSyncEnabled animated:NO];
    [self.watchSyncSwitch addTarget:self action:@selector(watchSyncSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    
    self.tvScanSwitch = [[UISwitch alloc] init];
    self.tvScanSwitch.translatesAutoresizingMaskIntoConstraints = NO;
    [self.tvScanSwitch setOn:self.tvScanEnabled animated:NO];
    [self.tvScanSwitch addTarget:self action:@selector(tvScanSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    
    UIView *card1 = [self createCard:L(@" WATCH SYNC ENGINE", @" 穿戴设备运动同步引擎") valueLabel:self.watchStatusLabel switchView:self.watchSyncSwitch];
    UIView *card2 = [self createCard:L(@"💻 EXTERNAL DISPLAY LINK", @"💻 外部扩展大屏直连") valueLabel:self.tvStatusLabel switchView:self.tvScanSwitch];
    UIView *card3 = [self createCard:L(@"LATEST DETECTED ACTION", @"最终判定体感动作") valueLabel:self.logLabel switchView:nil];
    
    // Video Control Card
    self.videoControlCard = [self createVideoControlCard];
    self.videoControlCard.hidden = YES; // Default hidden until we receive progress
    
    // Browser Control Card
    self.browserControlCard = [self createBrowserControlCard];
    
    // Status Defaults
    self.watchStatusLabel.text = L(@"🟡 Connecting...", @"🟡 获取 Apple Watch 状态中...");
    self.tvStatusLabel.text = L(@"⚪️ Link Inactive", @"⚪️ 未连接外置显示器");
    self.logLabel.text = L(@"Waiting for gestures...", @"等待进行体感动作...");
    self.logLabel.textColor = [UIColor tertiaryLabelColor];
    
    // Stack View
    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[card1, card2, card3]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 8;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:stack];
    
    // TV Selection Area
    UIView *tableContainer = [[UIView alloc] init];
    tableContainer.backgroundColor = [UIColor secondarySystemBackgroundColor];
    tableContainer.layer.cornerRadius = 16;
    tableContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [self.themeCards addObject:tableContainer];
    
    tableContainer.layer.shadowColor = [UIColor blackColor].CGColor;
    tableContainer.layer.shadowOpacity = 0.05;
    tableContainer.layer.shadowOffset = CGSizeMake(0, 4);
    tableContainer.layer.shadowRadius = 8;
    
    [self.view addSubview:tableContainer];
    
    UILabel *tableTitle = [[UILabel alloc] init];
    tableTitle.text = L(@"SELECT EXTERNAL DISPLAY (SSDP)", @"选择连接可用外部显示单元");
    tableTitle.font = [UIFont systemFontOfSize:12 weight:UIFontWeightBold];
    tableTitle.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.6];
    tableTitle.translatesAutoresizingMaskIntoConstraints = NO;
    [tableContainer addSubview:tableTitle];
    
    self.scanSpinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.scanSpinner.color = [UIColor whiteColor];
    self.scanSpinner.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scanSpinner startAnimating];
    [tableContainer addSubview:self.scanSpinner];
    
    self.tvTableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tvTableView.delegate = self;
    self.tvTableView.dataSource = self;
    self.tvTableView.backgroundColor = [UIColor clearColor];
    self.tvTableView.rowHeight = 50;
    self.tvTableView.layer.masksToBounds = YES;
    self.tvTableView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.tvTableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"TVCell"];
    
    UILabel *emptyLabel = [[UILabel alloc] init];
    emptyLabel.text = L(@"No nearby screens found.\nLocal tracking active.", @"局域网未发现可用投影显示单元\n手表本地体感记录仍在进行中");
    emptyLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    emptyLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.4];
    emptyLabel.textAlignment = NSTextAlignmentCenter;
    emptyLabel.numberOfLines = 0;
    self.tvTableView.backgroundView = emptyLabel;
    emptyLabel.hidden = YES;
    
    [tableContainer addSubview:self.tvTableView];
    
    [NSLayoutConstraint activateConstraints:@[
        [subtitleLabel.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:10],
        [subtitleLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:24],
        [subtitleLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-24],
        
        [stack.topAnchor constraintEqualToAnchor:subtitleLabel.bottomAnchor constant:15],
        [stack.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:24],
        [stack.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-24],
        
        [tableContainer.topAnchor constraintEqualToAnchor:stack.bottomAnchor constant:15],
        [tableContainer.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:24],
        [tableContainer.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-24],
        [tableContainer.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-20],
        
        [tableTitle.topAnchor constraintEqualToAnchor:tableContainer.topAnchor constant:16],
        [tableTitle.leadingAnchor constraintEqualToAnchor:tableContainer.leadingAnchor constant:20],
        
        [self.scanSpinner.centerYAnchor constraintEqualToAnchor:tableTitle.centerYAnchor],
        [self.scanSpinner.leadingAnchor constraintEqualToAnchor:tableTitle.trailingAnchor constant:8],
        
        [self.tvTableView.topAnchor constraintEqualToAnchor:tableTitle.bottomAnchor constant:10],
        [self.tvTableView.leadingAnchor constraintEqualToAnchor:tableContainer.leadingAnchor],
        [self.tvTableView.trailingAnchor constraintEqualToAnchor:tableContainer.trailingAnchor],
        [self.tvTableView.bottomAnchor constraintEqualToAnchor:tableContainer.bottomAnchor constant:-10]
    ]];
}

- (UILabel *)createLabel {
    UILabel *l = [[UILabel alloc] init];
    l.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    l.textColor = [UIColor whiteColor];
    l.translatesAutoresizingMaskIntoConstraints = NO;
    l.numberOfLines = 0;
    return l;
}

- (UIView *)createCard:(NSString *)title valueLabel:(UILabel *)valueLabel {
    return [self createCard:title valueLabel:valueLabel switchView:nil];
}

- (UIView *)createCard:(NSString *)title valueLabel:(UILabel *)valueLabel switchView:(UISwitch *)switchView {
    UIView *view = [[UIView alloc] init];
    view.backgroundColor = [UIColor secondarySystemBackgroundColor];
    view.layer.cornerRadius = 16;
    view.translatesAutoresizingMaskIntoConstraints = NO;
    [self.themeCards addObject:view];
    
    view.layer.shadowColor = [UIColor blackColor].CGColor;
    view.layer.shadowOpacity = 0.05;
    view.layer.shadowOffset = CGSizeMake(0, 4);
    view.layer.shadowRadius = 8;
    
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = [title uppercaseString];
    titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightBold];
    titleLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.6];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    
    [view addSubview:titleLabel];
    [view addSubview:valueLabel];
    
    if (switchView) {
        [view addSubview:switchView];
        [NSLayoutConstraint activateConstraints:@[
            [titleLabel.topAnchor constraintEqualToAnchor:view.topAnchor constant:8],
            [titleLabel.leadingAnchor constraintEqualToAnchor:view.leadingAnchor constant:20],
            
            [switchView.centerYAnchor constraintEqualToAnchor:view.centerYAnchor],
            [switchView.trailingAnchor constraintEqualToAnchor:view.trailingAnchor constant:-20],
            [titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:switchView.leadingAnchor constant:-8],
            
            [valueLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:4],
            [valueLabel.leadingAnchor constraintEqualToAnchor:view.leadingAnchor constant:20],
            [valueLabel.trailingAnchor constraintLessThanOrEqualToAnchor:switchView.leadingAnchor constant:-8],
            [valueLabel.bottomAnchor constraintEqualToAnchor:view.bottomAnchor constant:-8]
        ]];
    } else {
        [NSLayoutConstraint activateConstraints:@[
            [titleLabel.topAnchor constraintEqualToAnchor:view.topAnchor constant:8],
            [titleLabel.leadingAnchor constraintEqualToAnchor:view.leadingAnchor constant:20],
            [titleLabel.trailingAnchor constraintEqualToAnchor:view.trailingAnchor constant:-20],
            
            [valueLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:4],
            [valueLabel.leadingAnchor constraintEqualToAnchor:view.leadingAnchor constant:20],
            [valueLabel.trailingAnchor constraintEqualToAnchor:view.trailingAnchor constant:-20],
            [valueLabel.bottomAnchor constraintEqualToAnchor:view.bottomAnchor constant:-8]
        ]];
    }
    
    return view;
}

- (UIView *)createBrowserControlCard {
    UIView *view = [[UIView alloc] init];
    view.backgroundColor = [UIColor secondarySystemBackgroundColor];
    view.layer.cornerRadius = 16;
    view.translatesAutoresizingMaskIntoConstraints = NO;
    [self.themeCards addObject:view];
    
    view.layer.shadowColor = [UIColor blackColor].CGColor;
    view.layer.shadowOpacity = 0.05;
    view.layer.shadowOffset = CGSizeMake(0, 4);
    view.layer.shadowRadius = 8;
    
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = L(@"BROWSER CONTROLS", @"网页浏览器控制");
    titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightBold];
    titleLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.6];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [view addSubview:titleLabel];
    
    // URL Input Bar
    UIView *urlBarContainer = [[UIView alloc] init];
    urlBarContainer.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.08];
    urlBarContainer.layer.cornerRadius = 10;
    urlBarContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [view addSubview:urlBarContainer];
    
    UIImageView *urlIcon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"globe" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightMedium]]];
    urlIcon.tintColor = [[UIColor whiteColor] colorWithAlphaComponent:0.5];
    urlIcon.translatesAutoresizingMaskIntoConstraints = NO;
    [urlBarContainer addSubview:urlIcon];
    
    self.mainUrlTextField = [[UITextField alloc] init];
    self.mainUrlTextField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:L(@"Enter URL...", @"输入网址跳转...") attributes:@{NSForegroundColorAttributeName: [[UIColor whiteColor] colorWithAlphaComponent:0.3]}];
    self.mainUrlTextField.font = [UIFont systemFontOfSize:14 weight:UIFontWeightRegular];
    self.mainUrlTextField.textColor = [UIColor whiteColor];
    self.mainUrlTextField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.mainUrlTextField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.mainUrlTextField.spellCheckingType = UITextSpellCheckingTypeNo;
    self.mainUrlTextField.keyboardType = UIKeyboardTypeURL;
    self.mainUrlTextField.returnKeyType = UIReturnKeyGo;
    self.mainUrlTextField.clearButtonMode = UITextFieldViewModeWhileEditing;
    self.mainUrlTextField.delegate = self;
    self.mainUrlTextField.translatesAutoresizingMaskIntoConstraints = NO;
    [urlBarContainer addSubview:self.mainUrlTextField];
    
    self.goBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.goBtn setImage:[UIImage systemImageNamed:@"arrow.right.circle.fill" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:24 weight:UIImageSymbolWeightMedium]] forState:UIControlStateNormal];
    self.goBtn.tintColor = [HSBThemeManager shared].themeColor;
    [self.goBtn addTarget:self action:@selector(mainUrlGoAction) forControlEvents:UIControlEventTouchUpInside];
    self.goBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [urlBarContainer addSubview:self.goBtn];
    
    self.openTrackpadBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.openTrackpadBtn setTitle:L(@"Open Fullscreen Trackpad", @"打开全屏触控板界面") forState:UIControlStateNormal];
    self.openTrackpadBtn.titleLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightSemibold];
    self.openTrackpadBtn.backgroundColor = [HSBThemeManager shared].themeColor;
    [self.openTrackpadBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.openTrackpadBtn.layer.cornerRadius = 12;
    [self.openTrackpadBtn addTarget:self action:@selector(openFullscreenTrackpad) forControlEvents:UIControlEventTouchUpInside];
    self.openTrackpadBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [view addSubview:self.openTrackpadBtn];
    
    // Config editor button
    UIButton *editBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [editBtn setTitle:L(@"Edit Home Config", @"编辑主页配置") forState:UIControlStateNormal];
    editBtn.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    editBtn.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.06];
    [editBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    editBtn.tintColor = [UIColor whiteColor];
    editBtn.layer.cornerRadius = 12;
    [editBtn addTarget:self action:@selector(browserActionEditHome) forControlEvents:UIControlEventTouchUpInside];
    editBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [view addSubview:editBtn];
    
    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.topAnchor constraintEqualToAnchor:view.topAnchor constant:16],
        [titleLabel.leadingAnchor constraintEqualToAnchor:view.leadingAnchor constant:20],
        [titleLabel.trailingAnchor constraintEqualToAnchor:view.trailingAnchor constant:-20],
        
        // URL Bar
        [urlBarContainer.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:12],
        [urlBarContainer.leadingAnchor constraintEqualToAnchor:view.leadingAnchor constant:20],
        [urlBarContainer.trailingAnchor constraintEqualToAnchor:view.trailingAnchor constant:-20],
        [urlBarContainer.heightAnchor constraintEqualToConstant:42],
        
        [urlIcon.leadingAnchor constraintEqualToAnchor:urlBarContainer.leadingAnchor constant:12],
        [urlIcon.centerYAnchor constraintEqualToAnchor:urlBarContainer.centerYAnchor],
        [urlIcon.widthAnchor constraintEqualToConstant:18],
        [urlIcon.heightAnchor constraintEqualToConstant:18],
        
        [self.mainUrlTextField.leadingAnchor constraintEqualToAnchor:urlIcon.trailingAnchor constant:8],
        [self.mainUrlTextField.trailingAnchor constraintEqualToAnchor:self.goBtn.leadingAnchor constant:-6],
        [self.mainUrlTextField.centerYAnchor constraintEqualToAnchor:urlBarContainer.centerYAnchor],
        
        [self.goBtn.trailingAnchor constraintEqualToAnchor:urlBarContainer.trailingAnchor constant:-8],
        [self.goBtn.centerYAnchor constraintEqualToAnchor:urlBarContainer.centerYAnchor],
        [self.goBtn.widthAnchor constraintEqualToConstant:28],
        [self.goBtn.heightAnchor constraintEqualToConstant:28],
        
        [self.openTrackpadBtn.topAnchor constraintEqualToAnchor:urlBarContainer.bottomAnchor constant:12],
        [self.openTrackpadBtn.leadingAnchor constraintEqualToAnchor:view.leadingAnchor constant:20],
        [self.openTrackpadBtn.trailingAnchor constraintEqualToAnchor:view.trailingAnchor constant:-20],
        [self.openTrackpadBtn.heightAnchor constraintEqualToConstant:54],
        
        [editBtn.topAnchor constraintEqualToAnchor:self.openTrackpadBtn.bottomAnchor constant:10],
        [editBtn.leadingAnchor constraintEqualToAnchor:view.leadingAnchor constant:20],
        [editBtn.trailingAnchor constraintEqualToAnchor:view.trailingAnchor constant:-20],
        [editBtn.heightAnchor constraintEqualToConstant:44],
        [editBtn.bottomAnchor constraintEqualToAnchor:view.bottomAnchor constant:-20]
    ]];
    
    return view;
}

- (void)openFullscreenTrackpad {
    BrowserControlViewController *vc = [[BrowserControlViewController alloc] init];
    __weak typeof(self) weakSelf = self;
    vc.sendPayloadBlock = ^(NSDictionary *payload) {
        [weakSelf sendDirectPayload:payload msg:nil];
    };
    vc.sendActionBlock = ^(NSString *action) {
        // Here we intercept the action to send formatted dictionary over tcp
        NSMutableDictionary *p = [NSMutableDictionary dictionary];
        p[@"action"] = action;
        [weakSelf sendDirectPayload:p msg:nil];
    };
    vc.checkConnectionBlock = ^BOOL {
        return [HSBTVOSConnectionManager sharedManager].isConnected;
    };
    [self presentViewController:vc animated:YES completion:nil];
}


- (void)sendDirectPayload:(NSDictionary *)payload msg:(NSString *)msg {
    [[HSBTVOSConnectionManager sharedManager] sendPayload:payload];
    if (msg) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self updateUI:^{
                self.logLabel.text = msg;
                self.logLabel.textColor = [UIColor systemBlueColor];
            }];
        });
    }
}

- (void)showTVNotConnectedError {
    [self updateUI:^{
        self.logLabel.text = L(@"⚠️ Cannot send: TV Not Connected", @"⚠️ 无法发送: 电视未连接");
        self.logLabel.textColor = [UIColor systemOrangeColor];
    }];
}

#pragma mark - UI Actions

- (void)openSettings {
    SettingsViewController *settingsVC = [[SettingsViewController alloc] initWithStyle:UITableViewStyleGrouped];
    __weak typeof(self) weakSelf = self;
    settingsVC.sendPayloadBlock = ^(NSDictionary *payload) {
        [weakSelf sendDirectPayload:payload msg:nil];
    };
    [self.navigationController pushViewController:settingsVC animated:YES];
}

#pragma mark - URL Go Action (Main UI)

- (void)mainUrlGoAction {
    NSString *urlString = [self.mainUrlTextField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (urlString.length == 0) return;
    
    // 自动补全协议头
    if (![urlString.lowercaseString hasPrefix:@"http://"] && ![urlString.lowercaseString hasPrefix:@"https://"]) {
        urlString = [NSString stringWithFormat:@"https://%@", urlString];
    }
    
    if (![HSBTVOSConnectionManager sharedManager].isConnected) {
        [self showTVNotConnectedError];
        return;
    }
    
    UIImpactFeedbackGenerator *hap = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [hap impactOccurred];
    
    [self.mainUrlTextField resignFirstResponder];
    [self sendDirectPayload:@{@"action": (id)HSBRemoteSimulateActionOpenUrl, @"url": urlString} msg:[NSString stringWithFormat:L(@"🌐 Navigated to: %@", @"🌐 已跳转至: %@"), urlString]];
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if (textField == self.mainUrlTextField) {
        [self mainUrlGoAction];
    }
    return YES;
}

- (void)browserActionEditHome {
    UIImpactFeedbackGenerator *hap = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [hap impactOccurred];

    NSString *savedJson = [[NSUserDefaults standardUserDefaults] stringForKey:@"WatchCompanionHomeJSON"];
    if (!savedJson) {
        NSString *filePath = [[NSBundle mainBundle] pathForResource:@"homedefaultInner" ofType:@"json"];
        if (filePath) {
            savedJson = [NSString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:nil];
        } else {
            // fallback
            savedJson = @"[\n  {\n    \"titleKey\": \"Recommended\",\n    \"items\": [\n      { \"webTitle\": \"Bilibili\", \"webUrl\": \"https://www.bilibili.com/\" },\n      { \"webTitle\": \"Youku\", \"webUrl\": \"https://www.youku.com/\" }\n    ]\n  }\n]";
        }
    }

    HomeConfigEditViewController *vc = [[HomeConfigEditViewController alloc] init];
    vc.initialJson = savedJson;
    
    __weak typeof(self) weakSelf = self;
    vc.onSaveAndSync = ^(NSString *jsonString) {
        [[NSUserDefaults standardUserDefaults] setObject:jsonString forKey:@"WatchCompanionHomeJSON"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        [weakSelf sendJSONToTV:jsonString];
    };
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)sendJSONToTV:(NSString *)jsonString {
    if (![HSBTVOSConnectionManager sharedManager].isConnected) {
        [self updateUI:^{
            self.logLabel.text = L(@"⚠️ Cannot Sync: TV Not Connected", @"⚠️ 无法同步: 电视未连接");
            self.logLabel.textColor = [UIColor systemOrangeColor];
        }];
        return;
    }
    
    NSMutableDictionary *payload = [NSMutableDictionary dictionary];
    payload[@"action"] = HSBRemoteSimulateActionUpdateHomeJson;
    payload[@"payload"] = jsonString;
    
    [[HSBTVOSConnectionManager sharedManager] sendPayload:payload];
    
    [self updateUI:^{
        self.logLabel.text = L(@"✅ Synced JSON Configuration to TV", @"✅ 已将最新的 JSON 配置推送到电视");
        self.logLabel.textColor = [UIColor systemGreenColor];
        self.logLabel.alpha = 0.3;
        [UIView animateWithDuration:0.3 animations:^{
            self.logLabel.alpha = 1.0;
        }];
    }];
}


- (UIView *)createVideoControlCard {
    UIView *view = [[UIView alloc] init];
    view.backgroundColor = [UIColor secondarySystemBackgroundColor];
    view.layer.cornerRadius = 16;
    view.translatesAutoresizingMaskIntoConstraints = NO;
    [self.themeCards addObject:view];
    
    view.layer.shadowColor = [UIColor blackColor].CGColor;
    view.layer.shadowOpacity = 0.05;
    view.layer.shadowOffset = CGSizeMake(0, 4);
    view.layer.shadowRadius = 8;
    
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = L(@"VIDEO PLAYBACK", @"电视播放进度");
    titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightBold];
    titleLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.6];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [view addSubview:titleLabel];
    
    self.currentTimeLabel = [[UILabel alloc] init];
    self.currentTimeLabel.text = @"00:00";
    self.currentTimeLabel.font = [UIFont monospacedDigitSystemFontOfSize:14 weight:UIFontWeightMedium];
    self.currentTimeLabel.textColor = [UIColor whiteColor];
    self.currentTimeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [view addSubview:self.currentTimeLabel];
    
    self.durationLabel = [[UILabel alloc] init];
    self.durationLabel.text = @"00:00";
    self.durationLabel.font = [UIFont monospacedDigitSystemFontOfSize:14 weight:UIFontWeightMedium];
    self.durationLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.6];
    self.durationLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [view addSubview:self.durationLabel];
    
    self.videoSlider = [[UISlider alloc] init];
    self.videoSlider.translatesAutoresizingMaskIntoConstraints = NO;
    [self.videoSlider addTarget:self action:@selector(sliderTouchDown:) forControlEvents:UIControlEventTouchDown];
    [self.videoSlider addTarget:self action:@selector(sliderTouchUp:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside];
    [self.videoSlider addTarget:self action:@selector(sliderValueChanged:) forControlEvents:UIControlEventValueChanged];
    [view addSubview:self.videoSlider];
    
    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.topAnchor constraintEqualToAnchor:view.topAnchor constant:16],
        [titleLabel.leadingAnchor constraintEqualToAnchor:view.leadingAnchor constant:20],
        [titleLabel.trailingAnchor constraintEqualToAnchor:view.trailingAnchor constant:-20],
        
        [self.currentTimeLabel.leadingAnchor constraintEqualToAnchor:view.leadingAnchor constant:20],
        [self.currentTimeLabel.centerYAnchor constraintEqualToAnchor:self.videoSlider.centerYAnchor],
        
        [self.videoSlider.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:12],
        [self.videoSlider.leadingAnchor constraintEqualToAnchor:self.currentTimeLabel.trailingAnchor constant:10],
        [self.videoSlider.trailingAnchor constraintEqualToAnchor:self.durationLabel.leadingAnchor constant:-10],
        [self.videoSlider.bottomAnchor constraintEqualToAnchor:view.bottomAnchor constant:-20],
        
        [self.durationLabel.trailingAnchor constraintEqualToAnchor:view.trailingAnchor constant:-20],
        [self.durationLabel.centerYAnchor constraintEqualToAnchor:self.videoSlider.centerYAnchor],
    ]];
    
    return view;
}

- (NSString *)formatTime:(NSTimeInterval)time {
    NSInteger minutes = (NSInteger)time / 60;
    NSInteger seconds = (NSInteger)time % 60;
    return [NSString stringWithFormat:@"%02ld:%02ld", (long)minutes, (long)seconds];
}

- (void)sliderTouchDown:(UISlider *)slider {
    self.isDraggingSlider = YES;
}

- (void)sliderTouchUp:(UISlider *)slider {
    self.isDraggingSlider = NO;
    // 成功触觉反馈
    UINotificationFeedbackGenerator *hap = [[UINotificationFeedbackGenerator alloc] init];
    [hap notificationOccurred:UINotificationFeedbackTypeSuccess];
    [self sendSeekToTV:slider.value];
}

- (void)sliderValueChanged:(UISlider *)slider {
    self.currentTimeLabel.text = [self formatTime:slider.value];
}

- (void)sendSeekToTV:(float)seekTime {
    [self sendActionToTV:HSBRemoteSimulateActionSeekAbsolute withValue:@(seekTime)];
}
- (void)sendActionToTV:(NSString *)action {
    [self sendActionToTV:action withValue:nil];
}

- (void)sendActionToTV:(NSString *)action withValue:(NSNumber *)value {
    if (![HSBTVOSConnectionManager sharedManager].isConnected) {
        NSLog(@"[BonjourBridge] TV not connected yet. Dropping action.");
        // 错误触觉反馈
        UINotificationFeedbackGenerator *hap = [[UINotificationFeedbackGenerator alloc] init];
        [hap notificationOccurred:UINotificationFeedbackTypeError];
        [self updateUI:^{
            self.logLabel.text = [NSString stringWithFormat:L(@"⚠️ Dropped '%@' (TV Offline)", @"⚠️ 丢弃动作 '%@' (电视未连接)"), action];
            self.logLabel.textColor = [UIColor systemOrangeColor];
        }];
        return;
    }
    
    NSMutableDictionary *payload = [NSMutableDictionary dictionary];
    payload[@"action"] = action;
    if (value) {
        payload[@"value"] = value;
    }
    
    [[HSBTVOSConnectionManager sharedManager] sendPayload:payload];
    
    [self updateUI:^{
        self.logLabel.text = [NSString stringWithFormat:L(@"✅ Sent '%@' to TV", @"✅ 已将动作 '%@' 投送至电视"), action];
        self.logLabel.textColor = [UIColor labelColor];
        self.logLabel.alpha = 0.3;
        [UIView animateWithDuration:0.3 animations:^{
            self.logLabel.alpha = 1.0;
        }];
    }];
}

- (void)updateUI:(void (^)(void))block {
    dispatch_async(dispatch_get_main_queue(), block);
}

#pragma mark - UITableView DataSource & Delegate

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.discoveredEndpoints.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"TVCell" forIndexPath:indexPath];
    cell.backgroundColor = [UIColor clearColor];
    
    HSBThemePalette *palette = [HSBThemeManager shared].currentPalette;
    
    UIView *selectedBg = [[UIView alloc] init];
    selectedBg.backgroundColor = [palette.primaryColor colorWithAlphaComponent:0.15];
    cell.selectedBackgroundView = selectedBg;
    
    nw_endpoint_t ep = self.discoveredEndpoints[indexPath.row];
    const char *name = nw_endpoint_get_bonjour_service_name(ep);
    NSString *nameStr = name ? [NSString stringWithUTF8String:name] : L(@"Unknown TV", @"未命名电视");
    NSRange range = [nameStr rangeOfString:@" ("];
    if (range.location != NSNotFound) {
        nameStr = [nameStr substringToIndex:range.location];
    }
    cell.textLabel.text = nameStr;
    cell.textLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    cell.textLabel.textColor = [UIColor whiteColor];
    cell.imageView.image = [UIImage systemImageNamed:@"tv.fill"];
    cell.imageView.tintColor = palette.primaryColor;
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (self.discoveredEndpoints.count == 0) return;
    
    __weak typeof(self) weakSelf = self;
    
    nw_endpoint_t selectedEndpoint = self.discoveredEndpoints[indexPath.row];
    
    [self updateUI:^{
        self.tvStatusLabel.text = L(@"🟡 Connecting to selected TV...", @"🟡 正在连接选中的电视...");
    }];
    
    const char *name = nw_endpoint_get_bonjour_service_name(selectedEndpoint);
    NSString *nameStr = name ? [NSString stringWithUTF8String:name] : @"";
    
    [[HSBTVOSConnectionManager sharedManager] connectToEndpoint:selectedEndpoint deviceName:nameStr];
    
    TVDetailViewController *vc = [[TVDetailViewController alloc] init];
    vc.deviceName = nameStr;
    
    vc.sendPayloadBlock = ^(NSDictionary *payload) {
        [[HSBTVOSConnectionManager sharedManager] sendPayload:payload];
    };
    vc.sendActionBlock = ^(NSString *action) {
        [[HSBTVOSConnectionManager sharedManager] sendAction:action];
    };
    vc.checkConnectionBlock = ^BOOL{
        return [HSBTVOSConnectionManager sharedManager].isConnected;
    };
    
    vc.editHomeBlock = ^{
        HomeConfigEditViewController *editVC = [[HomeConfigEditViewController alloc] init];
        NSString *savedJson = [[NSUserDefaults standardUserDefaults] objectForKey:@"WatchCompanionHomeJSON"];
        if (!savedJson) {
            NSString *filePath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject]
                                  stringByAppendingPathComponent:@"home_config.json"];
            savedJson = [NSString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:nil];
        }
        editVC.initialJson = savedJson ?: @"[]";
        editVC.onSaveAndSync = ^(NSString *jsonString) {
            [[NSUserDefaults standardUserDefaults] setObject:jsonString forKey:@"WatchCompanionHomeJSON"];
            [[NSUserDefaults standardUserDefaults] synchronize];
            [weakSelf sendJSONToTV:jsonString];
        };
        [weakSelf.navigationController pushViewController:editVC animated:YES];
    };
    
    [self.navigationController pushViewController:vc animated:YES];
}

#pragma mark - Bridge Lifecycle

- (void)updateWatchSessionState {
    if (!self.watchSyncEnabled) {
        [self updateUI:^{
            self.watchStatusLabel.text = L(@"🔴 Gesture Sync Disabled (Power Save)", @"🔴 手势同步已关闭 (省电模式)");
            self.watchStatusLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.4];
        }];
        return;
    }
    
    __weak typeof(self) weakSelf = self;
    [[HSBWatchSessionManager sharedManager] updateWatchSessionStateWithHandler:^(NSString * _Nonnull statusText) {
        [weakSelf updateUI:^{
            weakSelf.watchStatusLabel.textColor = [UIColor whiteColor];
            weakSelf.watchStatusLabel.text = statusText;
        }];
    }];
}

- (void)startBridge {
    if (self.watchSyncEnabled) {
        [[HSBWatchSessionManager sharedManager] startSession];
        [self updateWatchSessionState];
    } else {
        [self updateWatchSessionState];
    }
    
    if (self.tvScanEnabled) {
        [self startBrowsing];
    } else {
        [self updateUI:^{
            self.tvStatusLabel.text = L(@"🔴 TV Discovery Disabled (Power Save)", @"🔴 电视通道已关闭 (省电模式)");
            self.tvStatusLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.4];
        }];
        [self.scanSpinner stopAnimating];
        self.scanSpinner.hidden = YES;
    }
}

- (void)handleTVOSConnectionStateChanged:(NSNotification *)note {
    NSDictionary *userInfo = note.userInfo;
    NSString *message = userInfo[@"message"];
    nw_connection_state_t state = [userInfo[@"state"] intValue];
    
    __weak typeof(self) weakSelf = self;
    [self updateUI:^{
        weakSelf.tvStatusLabel.text = message;
        if (state == nw_connection_state_ready) {
            weakSelf.isConnectedToTV = YES;
        } else {
            weakSelf.isConnectedToTV = NO;
        }
    }];
}

- (void)handleTVOSStateUpdated:(NSNotification *)note {
    NSDictionary *userInfo = note.userInfo;
    NSNumber *currentTime = userInfo[@"currentTime"];
    NSNumber *duration = userInfo[@"duration"];
    NSNumber *hiddenObj = userInfo[@"hidden"];
    BOOL isHidden = hiddenObj ? [hiddenObj boolValue] : NO;
    
    __weak typeof(self) weakSelf = self;
    if (currentTime && duration) {
        [self updateUI:^{
            weakSelf.videoControlCard.hidden = isHidden;
            if (!weakSelf.isDraggingSlider && !isHidden) {
                weakSelf.videoSlider.maximumValue = duration.floatValue;
                weakSelf.videoSlider.value = currentTime.floatValue;
                weakSelf.currentTimeLabel.text = [weakSelf formatTime:currentTime.floatValue];
                weakSelf.durationLabel.text = [weakSelf formatTime:duration.floatValue];
            }
        }];
    }
}

#pragma mark - Bonjour / Network

- (nw_parameters_t)createTCPParameters {
    nw_parameters_t parameters = nw_parameters_create_secure_tcp(NW_PARAMETERS_DISABLE_PROTOCOL, NW_PARAMETERS_DEFAULT_CONFIGURATION);
    nw_parameters_set_include_peer_to_peer(parameters, true);
    return parameters;
}

- (void)startBrowsing {
    if (self.browser) {
        nw_browser_cancel(self.browser);
    }
    
    [self.discoveredEndpoints removeAllObjects];
    [self updateUI:^{
        [self.tvTableView reloadData];
    }];
    
    // Use generic parameters for browsing to ensure we catch all network interfaces (Wi-Fi, Ethernet, AWDL)
    nw_parameters_t browseParameters = nw_parameters_create();
    nw_parameters_set_include_peer_to_peer(browseParameters, true);
    
    nw_browse_descriptor_t descriptor = nw_browse_descriptor_create_bonjour_service(BONJOUR_SERVICE_TYPE, NULL);
    
    self.browser = nw_browser_create(descriptor, browseParameters);
    
    __weak typeof(self) weakSelf = self;
    
    nw_browser_set_state_changed_handler(self.browser, ^(nw_browser_state_t state, nw_error_t error) {
        if (state == nw_browser_state_ready) {
            NSLog(@"[BonjourBridge] Browser ready, scanning...");
        } else if (state == nw_browser_state_failed) {
            NSLog(@"[BonjourBridge] Browser failed: %@", error);
        }
    });
    
    nw_browser_set_browse_results_changed_handler(self.browser, ^(nw_browse_result_t old_result, nw_browse_result_t new_result, bool batch_complete) {
        if (new_result) {
            nw_endpoint_t endpoint = nw_browse_result_copy_endpoint(new_result);
            if (endpoint) {
                const char *newName = nw_endpoint_get_bonjour_service_name(endpoint);
                BOOL exists = NO;
                for (nw_endpoint_t ep in weakSelf.discoveredEndpoints) {
                    const char *existingName = nw_endpoint_get_bonjour_service_name(ep);
                    if (newName && existingName && strcmp(newName, existingName) == 0) {
                        exists = YES;
                        break;
                    }
                }
                if (!exists) {
                    [weakSelf.discoveredEndpoints addObject:endpoint];
                    [weakSelf updateUI:^{
                        [weakSelf.tvTableView reloadData];
                    }];
                }
            }
        }
    });
    
    if (!self.browserQueue) {
        self.browserQueue = dispatch_queue_create("com.tv.browse.queue", DISPATCH_QUEUE_SERIAL);
    }
    nw_browser_set_queue(self.browser, self.browserQueue);
    nw_browser_start(self.browser);
    
    // Add Timeout for Empty State
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (weakSelf.discoveredEndpoints.count == 0) {
            [weakSelf.scanSpinner stopAnimating];
            weakSelf.tvTableView.backgroundView.hidden = NO;
        }
    });
}

- (void)watchSyncSwitchChanged:(UISwitch *)sender {
    UIImpactFeedbackGenerator *hap = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [hap impactOccurred];
    
    self.watchSyncEnabled = sender.isOn;
    [[NSUserDefaults standardUserDefaults] setBool:self.watchSyncEnabled forKey:@"WatchSyncEnabled"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    if (self.watchSyncEnabled) {
        [[HSBWatchSessionManager sharedManager] startSession];
    }
    [self updateWatchSessionState];
}

- (void)tvScanSwitchChanged:(UISwitch *)sender {
    UIImpactFeedbackGenerator *hap = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [hap impactOccurred];
    
    self.tvScanEnabled = sender.isOn;
    [[NSUserDefaults standardUserDefaults] setBool:self.tvScanEnabled forKey:@"TVScanEnabled"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    if (self.tvScanEnabled) {
        [self startBrowsing];
        [self.scanSpinner startAnimating];
        self.scanSpinner.hidden = NO;
        [self updateUI:^{
            self.tvStatusLabel.text = L(@"🟡 Connecting...", @"🟡 获取显示状态中...");
            self.tvStatusLabel.textColor = [UIColor whiteColor];
        }];
    } else {
        if (self.browser) {
            nw_browser_cancel(self.browser);
            self.browser = nil;
        }
        [self.discoveredEndpoints removeAllObjects];
        [self.tvTableView reloadData];
        
        [self.scanSpinner stopAnimating];
        self.scanSpinner.hidden = YES;
        
        [[HSBTVOSConnectionManager sharedManager] disconnect];
        self.isConnectedToTV = NO;
        self.videoControlCard.hidden = YES;
        
        [self updateUI:^{
            self.tvStatusLabel.text = L(@"🔴 TV Discovery Disabled (Power Save)", @"🔴 电视通道已关闭 (省电模式)");
            self.tvStatusLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.4];
        }];
    }
}

- (void)setupAILoadingHUD {
    self.aiLoadingHUD = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleDark]];
    self.aiLoadingHUD.translatesAutoresizingMaskIntoConstraints = NO;
    self.aiLoadingHUD.layer.cornerRadius = 16;
    self.aiLoadingHUD.clipsToBounds = YES;
    self.aiLoadingHUD.layer.borderWidth = 1;
    self.aiLoadingHUD.layer.borderColor = [[UIColor systemPurpleColor] colorWithAlphaComponent:0.2].CGColor;
    self.aiLoadingHUD.hidden = YES;
    [self.view addSubview:self.aiLoadingHUD];
    
    UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    spinner.color = [UIColor systemPurpleColor];
    spinner.translatesAutoresizingMaskIntoConstraints = NO;
    [spinner startAnimating];
    [self.aiLoadingHUD.contentView addSubview:spinner];
    
    UILabel *loadingLabel = [[UILabel alloc] init];
    loadingLabel.text = L(@"AI Engine Warming Up...", @"本地大模型载入中...");
    loadingLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    loadingLabel.textColor = [UIColor whiteColor];
    loadingLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.aiLoadingHUD.contentView addSubview:loadingLabel];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.aiLoadingHUD.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.aiLoadingHUD.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [self.aiLoadingHUD.widthAnchor constraintEqualToConstant:180],
        [self.aiLoadingHUD.heightAnchor constraintEqualToConstant:100],
        
        [spinner.centerXAnchor constraintEqualToAnchor:self.aiLoadingHUD.contentView.centerXAnchor],
        [spinner.topAnchor constraintEqualToAnchor:self.aiLoadingHUD.contentView.topAnchor constant:22],
        
        [loadingLabel.centerXAnchor constraintEqualToAnchor:self.aiLoadingHUD.contentView.centerXAnchor],
        [loadingLabel.bottomAnchor constraintEqualToAnchor:self.aiLoadingHUD.contentView.bottomAnchor constant:-20]
    ]];
}

- (void)handleLLMPrewarmingStarted:(NSNotification *)note {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.aiLoadingHUD.hidden = NO;
        self.aiLoadingHUD.alpha = 0.0;
        [UIView animateWithDuration:0.3 animations:^{
            self.aiLoadingHUD.alpha = 1.0;
        }];
    });
}

- (void)handleLLMPrewarmingFinished:(NSNotification *)note {
    dispatch_async(dispatch_get_main_queue(), ^{
        [UIView animateWithDuration:0.3 animations:^{
            self.aiLoadingHUD.alpha = 0.0;
        } completion:^(BOOL finished) {
            self.aiLoadingHUD.hidden = YES;
        }];
    });
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
