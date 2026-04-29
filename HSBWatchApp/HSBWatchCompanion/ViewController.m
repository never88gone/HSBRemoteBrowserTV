//
//  ViewController.m
//  HSBWatchCompanion
//

#import "ViewController.h"
#import <UIKit/UIKit.h>
#import <WatchConnectivity/WatchConnectivity.h>
#import <Network/Network.h>
#import <CoreMotion/CoreMotion.h>
#import "HomeConfigEditViewController.h"
#import "BrowserControlViewController.h"
#import "SettingsViewController.h"
#import "TVDetailViewController.h"

#define BONJOUR_SERVICE_TYPE "_thltv._tcp"

static NSString * L(NSString *en, NSString *zh) {
    NSString *language = [[NSLocale preferredLanguages] firstObject];
    if ([language hasPrefix:@"zh"]) {
        return zh ?: en;
    }
    return en;
}



@interface ViewController () <WCSessionDelegate, UITableViewDelegate, UITableViewDataSource, UIGestureRecognizerDelegate, UITextFieldDelegate>

@property (nonatomic, strong) nw_browser_t browser;
@property (nonatomic, strong) nw_connection_t connection;
@property (nonatomic, strong) dispatch_queue_t queue;
@property (nonatomic, assign) BOOL isConnectedToTV;

// UI Properties
@property (nonatomic, strong) UILabel *watchStatusLabel;
@property (nonatomic, strong) UILabel *tvStatusLabel;
@property (nonatomic, strong) UILabel *logLabel;
@property (nonatomic, strong) UITableView *tvTableView;
@property (nonatomic, strong) UIActivityIndicatorView *scanSpinner;

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

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.discoveredEndpoints = [NSMutableArray array];
    
    // Prevent the iPhone screen from sleeping and dropping the network connection
    [UIApplication sharedApplication].idleTimerDisabled = YES;
    
    [self loadDailyStats];
    [self setupUI];
    [self startBridge];
    [self startPedometer];
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

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}

#pragma mark - UI Setup

- (void)setupUI {
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    self.navigationItem.title = L(@"ZE Watch", @"糖葫芦遥控器");
    
    // Settings Button
    UIBarButtonItem *settingsItem = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"gearshape.fill"] style:UIBarButtonItemStylePlain target:self action:@selector(openSettings)];
    settingsItem.tintColor = [UIColor secondaryLabelColor];
    self.navigationItem.rightBarButtonItem = settingsItem;
    
    // Subtitle
    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.text = L(@"Keep this app open while using your Watch.", @"在使用手表遥控时保持此应用在前台运行");
    subtitleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    subtitleLabel.textColor = [UIColor secondaryLabelColor];
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:subtitleLabel];
    
    self.watchStatusLabel = [self createLabel];
    self.tvStatusLabel = [self createLabel];
    self.logLabel = [self createLabel];
    self.statsLabel = [self createLabel];
    
    self.stepsLabel = [self createLabel];
    self.stepsLabel.text = L(@"Local Steps (Today): --", @"今日设备走动步数: 获取中...");
    self.stepsLabel.textColor = [UIColor systemOrangeColor];
    
    // Cards
    self.statsCard = [self createCard:L(@"🏆 DAILY ACTIVITY TARGET", @"🏆 今日体感训练打卡目标") valueLabel:self.statsLabel];
    [self.statsCard addSubview:self.stepsLabel];
    
    // Add constraints to stepsLabel inside statsCard
    self.stepsLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [self.stepsLabel.topAnchor constraintEqualToAnchor:self.statsLabel.bottomAnchor constant:4],
        [self.stepsLabel.leadingAnchor constraintEqualToAnchor:self.statsCard.leadingAnchor constant:16],
        [self.stepsLabel.trailingAnchor constraintEqualToAnchor:self.statsCard.trailingAnchor constant:-16],
        [self.stepsLabel.bottomAnchor constraintEqualToAnchor:self.statsCard.bottomAnchor constant:-16]
    ]];
    // Override the statsLabel bottom constraint in the card
    for (NSLayoutConstraint *c in self.statsCard.constraints) {
        if (c.firstItem == self.statsLabel && c.firstAttribute == NSLayoutAttributeBottom) {
            c.active = NO;
        }
    }
    
    // Set up goal hit box
    UITapGestureRecognizer *tapGoal = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(showSetGoalAlert)];
    [self.statsCard addGestureRecognizer:tapGoal];
    
    UIView *card1 = [self createCard:L(@" WATCH SYNC ENGINE", @" 穿戴设备运动同步引擎") valueLabel:self.watchStatusLabel];
    UIView *card2 = [self createCard:L(@"💻 EXTERNAL DISPLAY LINK", @"💻 外部扩展大屏直连") valueLabel:self.tvStatusLabel];
    UIView *card3 = [self createCard:L(@"LATEST DETECTED ACTION", @"最终判定体感动作") valueLabel:self.logLabel];
    
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
    [self updateStatsUI];
    
    // Stack View
    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[self.statsCard, card1, card2, card3, ]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 8;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:stack];
    
    // TV Selection Area
    UIView *tableContainer = [[UIView alloc] init];
    tableContainer.backgroundColor = [UIColor secondarySystemBackgroundColor];
    tableContainer.layer.cornerRadius = 16;
    tableContainer.translatesAutoresizingMaskIntoConstraints = NO;
    
    tableContainer.layer.shadowColor = [UIColor blackColor].CGColor;
    tableContainer.layer.shadowOpacity = 0.05;
    tableContainer.layer.shadowOffset = CGSizeMake(0, 4);
    tableContainer.layer.shadowRadius = 8;
    
    [self.view addSubview:tableContainer];
    
    UILabel *tableTitle = [[UILabel alloc] init];
    tableTitle.text = L(@"SELECT EXTERNAL DISPLAY (SSDP)", @"选择连接可用外部显示单元");
    tableTitle.font = [UIFont systemFontOfSize:12 weight:UIFontWeightBold];
    tableTitle.textColor = [UIColor secondaryLabelColor];
    tableTitle.translatesAutoresizingMaskIntoConstraints = NO;
    [tableContainer addSubview:tableTitle];
    
    self.scanSpinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
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
    emptyLabel.textColor = [UIColor tertiaryLabelColor];
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
    l.font = [UIFont systemFontOfSize:18 weight:UIFontWeightMedium];
    l.translatesAutoresizingMaskIntoConstraints = NO;
    l.numberOfLines = 0;
    return l;
}

- (UIView *)createCard:(NSString *)title valueLabel:(UILabel *)valueLabel {
    UIView *view = [[UIView alloc] init];
    view.backgroundColor = [UIColor secondarySystemBackgroundColor];
    view.layer.cornerRadius = 16;
    view.translatesAutoresizingMaskIntoConstraints = NO;
    
    view.layer.shadowColor = [UIColor blackColor].CGColor;
    view.layer.shadowOpacity = 0.05;
    view.layer.shadowOffset = CGSizeMake(0, 4);
    view.layer.shadowRadius = 8;
    
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = [title uppercaseString];
    titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightBold];
    titleLabel.textColor = [UIColor secondaryLabelColor];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    
    [view addSubview:titleLabel];
    [view addSubview:valueLabel];
    
    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.topAnchor constraintEqualToAnchor:view.topAnchor constant:8],
        [titleLabel.leadingAnchor constraintEqualToAnchor:view.leadingAnchor constant:20],
        [titleLabel.trailingAnchor constraintEqualToAnchor:view.trailingAnchor constant:-20],
        
        [valueLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:4],
        [valueLabel.leadingAnchor constraintEqualToAnchor:view.leadingAnchor constant:20],
        [valueLabel.trailingAnchor constraintEqualToAnchor:view.trailingAnchor constant:-20],
        [valueLabel.bottomAnchor constraintEqualToAnchor:view.bottomAnchor constant:-8]
    ]];
    
    return view;
}

- (UIView *)createBrowserControlCard {
    UIView *view = [[UIView alloc] init];
    view.backgroundColor = [UIColor secondarySystemBackgroundColor];
    view.layer.cornerRadius = 16;
    view.translatesAutoresizingMaskIntoConstraints = NO;
    
    view.layer.shadowColor = [UIColor blackColor].CGColor;
    view.layer.shadowOpacity = 0.05;
    view.layer.shadowOffset = CGSizeMake(0, 4);
    view.layer.shadowRadius = 8;
    
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = L(@"BROWSER CONTROLS", @"网页浏览器控制");
    titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightBold];
    titleLabel.textColor = [UIColor secondaryLabelColor];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [view addSubview:titleLabel];
    
    // URL Input Bar
    UIView *urlBarContainer = [[UIView alloc] init];
    urlBarContainer.backgroundColor = [UIColor tertiarySystemBackgroundColor];
    urlBarContainer.layer.cornerRadius = 10;
    urlBarContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [view addSubview:urlBarContainer];
    
    UIImageView *urlIcon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"globe" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightMedium]]];
    urlIcon.tintColor = [UIColor secondaryLabelColor];
    urlIcon.translatesAutoresizingMaskIntoConstraints = NO;
    [urlBarContainer addSubview:urlIcon];
    
    self.mainUrlTextField = [[UITextField alloc] init];
    self.mainUrlTextField.placeholder = L(@"Enter URL...", @"输入网址跳转...");
    self.mainUrlTextField.font = [UIFont systemFontOfSize:14 weight:UIFontWeightRegular];
    self.mainUrlTextField.textColor = [UIColor labelColor];
    self.mainUrlTextField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.mainUrlTextField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.mainUrlTextField.spellCheckingType = UITextSpellCheckingTypeNo;
    self.mainUrlTextField.keyboardType = UIKeyboardTypeURL;
    self.mainUrlTextField.returnKeyType = UIReturnKeyGo;
    self.mainUrlTextField.clearButtonMode = UITextFieldViewModeWhileEditing;
    self.mainUrlTextField.delegate = self;
    self.mainUrlTextField.translatesAutoresizingMaskIntoConstraints = NO;
    [urlBarContainer addSubview:self.mainUrlTextField];
    
    UIButton *goBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [goBtn setImage:[UIImage systemImageNamed:@"arrow.right.circle.fill" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:24 weight:UIImageSymbolWeightMedium]] forState:UIControlStateNormal];
    goBtn.tintColor = [UIColor systemBlueColor];
    [goBtn addTarget:self action:@selector(mainUrlGoAction) forControlEvents:UIControlEventTouchUpInside];
    goBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [urlBarContainer addSubview:goBtn];
    
    UIButton *openTrackpadBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [openTrackpadBtn setTitle:L(@"Open Fullscreen Trackpad", @"打开全屏触控板界面") forState:UIControlStateNormal];
    openTrackpadBtn.titleLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightSemibold];
    openTrackpadBtn.backgroundColor = [UIColor systemBlueColor];
    [openTrackpadBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    openTrackpadBtn.layer.cornerRadius = 12;
    [openTrackpadBtn addTarget:self action:@selector(openFullscreenTrackpad) forControlEvents:UIControlEventTouchUpInside];
    openTrackpadBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [view addSubview:openTrackpadBtn];
    
    // Config editor button
    UIButton *editBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [editBtn setTitle:L(@"Edit Home Config", @"编辑主页配置") forState:UIControlStateNormal];
    editBtn.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    editBtn.backgroundColor = [UIColor quaternarySystemFillColor];
    [editBtn setTitleColor:[UIColor labelColor] forState:UIControlStateNormal];
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
        [self.mainUrlTextField.trailingAnchor constraintEqualToAnchor:goBtn.leadingAnchor constant:-6],
        [self.mainUrlTextField.centerYAnchor constraintEqualToAnchor:urlBarContainer.centerYAnchor],
        
        [goBtn.trailingAnchor constraintEqualToAnchor:urlBarContainer.trailingAnchor constant:-8],
        [goBtn.centerYAnchor constraintEqualToAnchor:urlBarContainer.centerYAnchor],
        [goBtn.widthAnchor constraintEqualToConstant:28],
        [goBtn.heightAnchor constraintEqualToConstant:28],
        
        [openTrackpadBtn.topAnchor constraintEqualToAnchor:urlBarContainer.bottomAnchor constant:12],
        [openTrackpadBtn.leadingAnchor constraintEqualToAnchor:view.leadingAnchor constant:20],
        [openTrackpadBtn.trailingAnchor constraintEqualToAnchor:view.trailingAnchor constant:-20],
        [openTrackpadBtn.heightAnchor constraintEqualToConstant:54],
        
        [editBtn.topAnchor constraintEqualToAnchor:openTrackpadBtn.bottomAnchor constant:10],
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
        return weakSelf.connection && weakSelf.isConnectedToTV;
    };
    [self presentViewController:vc animated:YES completion:nil];
}


- (void)sendDirectPayload:(NSDictionary *)payload msg:(NSString *)msg {
    NSData *data = [NSJSONSerialization dataWithJSONObject:payload options:0 error:nil];
    if (data && data.length > 0) {
        dispatch_data_t dispatchData = dispatch_data_create(data.bytes, data.length, dispatch_get_main_queue(), ^{ [data self]; });
        nw_connection_send(self.connection, dispatchData, NW_CONNECTION_DEFAULT_MESSAGE_CONTEXT, true, ^(nw_error_t error) {
            if (!error && msg) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self updateUI:^{
                        self.logLabel.text = msg;
                        self.logLabel.textColor = [UIColor systemBlueColor];
                    }];
                });
            }
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
    
    if (!self.connection || !self.isConnectedToTV) {
        [self showTVNotConnectedError];
        return;
    }
    
    UIImpactFeedbackGenerator *hap = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [hap impactOccurred];
    
    [self.mainUrlTextField resignFirstResponder];
    [self sendDirectPayload:@{@"action": @"open_url", @"url": urlString} msg:[NSString stringWithFormat:L(@"🌐 Navigated to: %@", @"🌐 已跳转至: %@"), urlString]];
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
    if (!self.connection || !self.isConnectedToTV) {
        [self updateUI:^{
            self.logLabel.text = L(@"⚠️ Cannot Sync: TV Not Connected", @"⚠️ 无法同步: 电视未连接");
            self.logLabel.textColor = [UIColor systemOrangeColor];
        }];
        return;
    }
    
    NSMutableDictionary *payload = [NSMutableDictionary dictionary];
    payload[@"action"] = @"update_home_json";
    payload[@"payload"] = jsonString;
    
    NSData *data = [NSJSONSerialization dataWithJSONObject:payload options:0 error:nil];
    if (data && data.length > 0) {
        dispatch_data_t dispatchData = dispatch_data_create(data.bytes, data.length, dispatch_get_main_queue(), ^{ [data self]; });
        nw_connection_send(self.connection, dispatchData, NW_CONNECTION_DEFAULT_MESSAGE_CONTEXT, true, ^(nw_error_t error) {
            if (!error) {
                [self updateUI:^{
                    self.logLabel.text = L(@"✅ Synced JSON Configuration to TV", @"✅ 已将最新的 JSON 配置推送到电视");
                    self.logLabel.textColor = [UIColor systemGreenColor];
                    self.logLabel.alpha = 0.3;
                    [UIView animateWithDuration:0.3 animations:^{
                        self.logLabel.alpha = 1.0;
                    }];
                }];
            }
        });
    }
}


- (UIView *)createVideoControlCard {
    UIView *view = [[UIView alloc] init];
    view.backgroundColor = [UIColor secondarySystemBackgroundColor];
    view.layer.cornerRadius = 16;
    view.translatesAutoresizingMaskIntoConstraints = NO;
    
    view.layer.shadowColor = [UIColor blackColor].CGColor;
    view.layer.shadowOpacity = 0.05;
    view.layer.shadowOffset = CGSizeMake(0, 4);
    view.layer.shadowRadius = 8;
    
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = L(@"VIDEO PLAYBACK", @"电视播放进度");
    titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightBold];
    titleLabel.textColor = [UIColor secondaryLabelColor];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [view addSubview:titleLabel];
    
    self.currentTimeLabel = [[UILabel alloc] init];
    self.currentTimeLabel.text = @"00:00";
    self.currentTimeLabel.font = [UIFont monospacedDigitSystemFontOfSize:14 weight:UIFontWeightMedium];
    self.currentTimeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [view addSubview:self.currentTimeLabel];
    
    self.durationLabel = [[UILabel alloc] init];
    self.durationLabel.text = @"00:00";
    self.durationLabel.font = [UIFont monospacedDigitSystemFontOfSize:14 weight:UIFontWeightMedium];
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
    [self sendActionToTV:@"seek" withValue:@(seekTime)];
}

- (void)sendActionToTV:(NSString *)action withValue:(NSNumber *)value {
    if (!self.connection || !self.isConnectedToTV) {
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
    
    NSData *data = [NSJSONSerialization dataWithJSONObject:payload options:0 error:nil];
    if (data && data.length > 0) {
        dispatch_data_t dispatchData = dispatch_data_create(data.bytes, data.length, dispatch_get_main_queue(), ^{ [data self]; });
        nw_connection_send(self.connection, dispatchData, NW_CONNECTION_DEFAULT_MESSAGE_CONTEXT, true, ^(nw_error_t error) {
            if (!error) {
                [self updateUI:^{
                    self.logLabel.text = [NSString stringWithFormat:L(@"✅ Sent '%@' to TV", @"✅ 已将动作 '%@' 投送至电视"), action];
                    self.logLabel.textColor = [UIColor labelColor];
                    self.logLabel.alpha = 0.3;
                    [UIView animateWithDuration:0.3 animations:^{
                        self.logLabel.alpha = 1.0;
                    }];
                }];
            }
        });
    }
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
    
    nw_endpoint_t ep = self.discoveredEndpoints[indexPath.row];
    const char *name = nw_endpoint_get_bonjour_service_name(ep);
    NSString *nameStr = name ? [NSString stringWithUTF8String:name] : L(@"Unknown TV", @"未命名电视");
    NSRange range = [nameStr rangeOfString:@" ("];
    if (range.location != NSNotFound) {
        nameStr = [nameStr substringToIndex:range.location];
    }
    cell.textLabel.text = nameStr;
    cell.textLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    cell.textLabel.textColor = [UIColor labelColor];
    cell.imageView.image = [UIImage systemImageNamed:@"tv.fill"];
    cell.imageView.tintColor = [UIColor systemIndigoColor];
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (self.discoveredEndpoints.count == 0) return;
    
    nw_endpoint_t selectedEndpoint = self.discoveredEndpoints[indexPath.row];
    
    [self updateUI:^{
        self.tvStatusLabel.text = L(@"🟡 Connecting to selected TV...", @"🟡 正在连接选中的电视...");
    }];
    
    [self connectToTV:selectedEndpoint];
    
    TVDetailViewController *vc = [[TVDetailViewController alloc] init];
    __weak typeof(self) weakSelf = self;
    vc.sendPayloadBlock = ^(NSDictionary *payload) {
        NSError *error = nil;
        NSData *data = [NSJSONSerialization dataWithJSONObject:payload options:0 error:&error];
        if (data && weakSelf.connection) {
            nw_connection_send(weakSelf.connection, dispatch_data_create(data.bytes, data.length, dispatch_get_main_queue(), ^{}), NW_CONNECTION_DEFAULT_MESSAGE_CONTEXT, true, ^(nw_error_t  _Nullable error) { });
        }
    };
    vc.sendActionBlock = ^(NSString *action) {
        [weakSelf sendActionToTV:action];
    };
    vc.checkConnectionBlock = ^BOOL{
        return weakSelf.isConnectedToTV;
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

- (void)startBridge {
    self.queue = dispatch_queue_create("com.bridge.bonjour.queue", DISPATCH_QUEUE_SERIAL);

    if ([WCSession isSupported]) {
        WCSession.defaultSession.delegate = self;
        [WCSession.defaultSession activateSession];
        NSLog(@"[BonjourBridge] WCSession Activated...");
    } else {
        [self updateUI:^{
            self.watchStatusLabel.text = L(@"🔴 WCSession Not Supported", @"🔴 当前设备不支持 WCSession");
        }];
    }
    
    [self startBrowsing];
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
    
    nw_browser_set_queue(self.browser, self.queue);
    nw_browser_start(self.browser);
    
    // Add Timeout for Empty State
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (weakSelf.discoveredEndpoints.count == 0) {
            [weakSelf.scanSpinner stopAnimating];
            weakSelf.tvTableView.backgroundView.hidden = NO;
        }
    });
}

- (void)connectToTV:(nw_endpoint_t)endpoint {
    self.currentEndpoint = endpoint;
    
    if (self.connection) {
        nw_connection_cancel(self.connection);
        self.connection = nil;
    }
    
    nw_parameters_t parameters = [self createTCPParameters];
    self.connection = nw_connection_create(endpoint, parameters);
    
    __weak typeof(self) weakSelf = self;
    nw_connection_set_state_changed_handler(self.connection, ^(nw_connection_state_t state, nw_error_t error) {
        switch (state) {
            case nw_connection_state_ready: {
                NSLog(@"[BonjourBridge] Connected to External Display!");
                weakSelf.isConnectedToTV = YES;
                [weakSelf updateUI:^{
                    weakSelf.tvStatusLabel.text = L(@"🟢 Connected to Display", @"🟢 外部显示单元连接成功");
                }];
                [weakSelf startReceivingFromTV];
                break;
            }
            case nw_connection_state_failed: {
                NSLog(@"[BonjourBridge] Connection failed: %@. Reconnecting in 2s...", error);
                weakSelf.isConnectedToTV = NO;
                weakSelf.connection = nil;
                [weakSelf updateUI:^{
                    weakSelf.tvStatusLabel.text = L(@"🔴 Error. Reconnecting...", @"🔴 连接断开，正在尝试重连...");
                }];
                // Auto-reconnect after 2 seconds
                if (weakSelf.currentEndpoint) {
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), weakSelf.queue, ^{
                        [weakSelf connectToTV:weakSelf.currentEndpoint];
                    });
                }
                break;
            }
            case nw_connection_state_cancelled: {
                NSLog(@"[BonjourBridge] Connection cancelled.");
                weakSelf.isConnectedToTV = NO;
                [weakSelf updateUI:^{
                    if (![weakSelf.tvStatusLabel.text containsString:@"Failed"] && ![weakSelf.tvStatusLabel.text containsString:@"断开"]) {
                        weakSelf.tvStatusLabel.text = L(@"⚪️ Disconnected", @"⚪️ 当前无连接");
                    }
                }];
                break;
            }
            default:
                break;
        }
    });
    
    nw_connection_set_queue(self.connection, self.queue);
    nw_connection_start(self.connection);
}

- (void)sendActionToTV:(NSString *)action {
    [self sendActionToTV:action withValue:nil];
}

- (void)startReceivingFromTV {
    if (!self.connection) return;
    
    __weak typeof(self) weakSelf = self;
    nw_connection_receive(self.connection, 1, 65536, ^(dispatch_data_t content, nw_content_context_t context, bool is_complete, nw_error_t error) {
        if (content) {
            const void *buffer = NULL;
            size_t size = 0;
            dispatch_data_t contiguousContent = dispatch_data_create_map(content, &buffer, &size);
            if (buffer && size > 0) {
                NSData *data = [NSData dataWithBytes:buffer length:size];
                NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                if (json && [json isKindOfClass:[NSDictionary class]]) {
                    NSString *action = json[@"action"];
                    if ([action isEqualToString:@"sync_progress"]) {
                        NSNumber *currentTime = json[@"currentTime"];
                        NSNumber *duration = json[@"duration"];
                        NSNumber *hiddenObj = json[@"hidden"];
                        BOOL isHidden = hiddenObj ? [hiddenObj boolValue] : NO;
                        
                        if (currentTime && duration) {
                            [weakSelf updateUI:^{
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
                }
            }
        }
        
        if (!is_complete && !error) {
            [weakSelf startReceivingFromTV];
        }
    });
}


#pragma mark - WCSessionDelegate

- (void)session:(WCSession *)session activationDidCompleteWithState:(WCSessionActivationState)activationState error:(NSError *)error {
    if (error) {
        [self updateUI:^{
            self.watchStatusLabel.text = [NSString stringWithFormat:L(@"🔴 Activation Error: %@", @"🔴 通道激活失败: %@"), error.localizedDescription];
        }];
    } else {
        [self updateUI:^{
            if (activationState == WCSessionActivationStateActivated) {
                self.watchStatusLabel.text = L(@"🟢 Listening to Watch Gestures", @"🟢 正在监听苹果手表手势");
            } else {
                self.watchStatusLabel.text = L(@"🟡 Session Inactive", @"🟡 通道未激活");
            }
        }];
    }
}

- (void)sessionDidBecomeInactive:(WCSession *)session {
    [self updateUI:^{
        self.watchStatusLabel.text = L(@"🟡 Session Inactive", @"🟡 通道未激活");
    }];
}

- (void)sessionDidDeactivate:(WCSession *)session {
    [self updateUI:^{
        self.watchStatusLabel.text = L(@"⚪️ Session Deactivated", @"⚪️ 通道已断开");
    }];
    [WCSession.defaultSession activateSession];
}

// Receive Message from Watch (Foreground)
- (void)session:(WCSession *)session didReceiveMessage:(NSDictionary<NSString *,id> *)message {
    NSString *action = message[@"action"];
    if (action) {
        [self incrementActivityScore];
        [self updateUI:^{
            self.logLabel.text = [NSString stringWithFormat:L(@"📥 Detected Task: '%@'", @"📥 捕捉体感动作任务: '%@'"), action];
            self.logLabel.textColor = [UIColor systemBlueColor];
        }];
        [self sendActionToTV:action];
    }
}

// Receive UserInfo from Watch (Background / Fallback)
- (void)session:(WCSession *)session didReceiveUserInfo:(NSDictionary<NSString *,id> *)userInfo {
    NSString *action = userInfo[@"action"];
    if (action) {
        [self incrementActivityScore];
        [self updateUI:^{
            self.logLabel.text = [NSString stringWithFormat:L(@"📥 Detected Task: '%@' (BG)", @"📥 捕捉体感动作(后台唤醒): '%@'"), action];
            self.logLabel.textColor = [UIColor systemIndigoColor];
        }];
        [self sendActionToTV:action];
    }
}

@end
