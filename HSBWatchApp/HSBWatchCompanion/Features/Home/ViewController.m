//
//  ViewController.m
//  HSBWatchCompanion
//
#import "ViewController.h"
#import <UIKit/UIKit.h>
#import "HomeConfigEditViewController.h"
#import "SettingsViewController.h"
#import "TVDetailViewController.h"
#import "HSBThemeManager.h"
#import "HSBTVOSConnectionManager.h"
#import "HSBWatchSessionManager.h"
#import "HSBLocalLLMManager.h"
#import "HSBActivityTracker.h"
#import "HSBHomeVideoControlCard.h"
#import "HSBHomeBrowserControlCard.h"
#import "HSBHomeActivityStatsCard.h"
#import "HSBHomeDeviceListManager.h"
#import "HSBWatchCompanion-Swift.h"

static inline NSString * L(NSString *en, NSString *zh) {
    NSString *language = [[NSLocale preferredLanguages] firstObject];
    if ([language hasPrefix:@"zh"]) {
        return zh ?: en;
    }
    return en;
}

@interface ViewController () <HSBActivityTrackerDelegate, HSBHomeDeviceListManagerDelegate, HSBQRCodeScannerDelegate>

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

// Components
@property (nonatomic, strong) HSBHomeVideoControlCard *videoControlCard;
@property (nonatomic, strong) HSBHomeBrowserControlCard *browserControlCard;
@property (nonatomic, strong) HSBHomeDeviceListManager *deviceListManager;
@property (nonatomic, strong) HSBActivityTracker *activityTracker;

// Activity Stats UI
@property (nonatomic, strong) HSBHomeActivityStatsCard *statsCard;

@property (nonatomic, strong) NSMutableArray<UIView *> *themeCards;
@property (nonatomic, strong) UIVisualEffectView *aiLoadingHUD;

@end

@implementation ViewController

- (void)viewDidLoad {
    self.themeCards = [NSMutableArray array];
    self.watchSyncEnabled = YES;
    self.tvScanEnabled = YES;
    [super viewDidLoad];
    [UIApplication sharedApplication].idleTimerDisabled = YES;
    [self setupUI];
    [self setupActivityTracker];
    [self setupAILoadingHUD];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleLLMPrewarmingStarted:) name:@"HSBLocalLLM_PrewarmingStartedNotification" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleLLMPrewarmingFinished:) name:@"HSBLocalLLM_PrewarmingFinishedNotification" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleTVOSConnectionStateChanged:) name:HSBTVOSConnectionStateNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleWatchReachabilityChanged:) name:HSBWatchSessionReachabilityDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleWatchActionReceived:) name:HSBWatchActionReceivedNotification object:nil];
    [self applyThemeStyle];
    
    if (@available(iOS 14.0, *)) {
        self.navigationItem.backButtonDisplayMode = UINavigationItemBackButtonDisplayModeMinimal;
    }
    self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"" style:UIBarButtonItemStylePlain target:nil action:nil];
    [self.deviceListManager startScanning];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:NO animated:animated];
    [self updateWatchSessionState];
    [self applyThemeStyle];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    static dispatch_once_t launchAnimToken;
    dispatch_once(&launchAnimToken, ^{
        NSArray *args = [NSProcessInfo processInfo].arguments;
        BOOL isTestEnv = [args containsObject:@"--run-appletv-tests"] ||
                         [args containsObject:@"--test-connect-device"] ||
                         [args containsObject:@"--test-connect-mac"] ||
                         [args containsObject:@"--test-pin-alert"] ||
                         [args containsObject:@"--guide-pin"] ||
                         [args containsObject:@"--guide-browser"] ||
                         [args containsObject:@"--guide-system"] ||
                         [args containsObject:@"--test-mac-media"] ||
                         [args containsObject:@"--test-open-components"] ||
                         [args containsObject:@"--test-open-settings"] ||
                         [args containsObject:@"--test-open-about"] ||
                         [[NSUserDefaults standardUserDefaults] boolForKey:@"UITestOpenModernRemote"];
        if (!isTestEnv) {
            [HSBModernRemoteBridge showLaunchEntranceAnimationOn:self completion:^{
                NSLog(@"[LaunchAnim] showLaunchEntranceAnimation completed");
            }];
        }
    });
}

- (void)setupActivityTracker {
    self.activityTracker = [HSBActivityTracker sharedTracker];
    self.activityTracker.delegate = self;
    [self.activityTracker startTracking];
}

#pragma mark - UI Setup

- (void)setupUI {
    self.navigationItem.title = L(@"ZE Watch", @"糖葫芦遥控器");
    
    UIBarButtonItem *settingsItem = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"gearshape.fill"] style:UIBarButtonItemStylePlain target:self action:@selector(openSettings)];
    settingsItem.tintColor = [UIColor whiteColor];
    
    UIBarButtonItem *remoteItem = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"appletvremote.gen4.fill"] style:UIBarButtonItemStylePlain target:self action:@selector(openModernRemoteController)];
    remoteItem.tintColor = [HSBThemeManager shared].currentPalette.primaryColor;
    
    UIBarButtonItem *scanItem = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"qrcode.viewfinder"] style:UIBarButtonItemStylePlain target:self action:@selector(openQRCodeScanner)];
    scanItem.tintColor = [UIColor systemOrangeColor];
    
    self.navigationItem.rightBarButtonItems = @[settingsItem, remoteItem, scanItem];
    
    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.text = L(@"Keep this app open while using your Watch.", @"在使用手表遥控时保持此应用在前台运行");
    subtitleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    subtitleLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.6];
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:subtitleLabel];
    
    self.watchStatusLabel = [self createLabel];
    self.tvStatusLabel = [self createLabel];
    self.logLabel = [self createLabel];
    
    self.watchSyncSwitch = [[UISwitch alloc] init];
    self.watchSyncSwitch.translatesAutoresizingMaskIntoConstraints = NO;
    [self.watchSyncSwitch setOn:self.watchSyncEnabled animated:NO];
    [self.watchSyncSwitch addTarget:self action:@selector(watchSyncSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    
    self.tvScanSwitch = [[UISwitch alloc] init];
    self.tvScanSwitch.translatesAutoresizingMaskIntoConstraints = NO;
    [self.tvScanSwitch setOn:self.tvScanEnabled animated:NO];
    [self.tvScanSwitch addTarget:self action:@selector(tvScanSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    
    UIView *card1 = [self createCard:L(@" WATCH SYNC ENGINE", @" 穿戴设备运动同步引擎") valueLabel:self.watchStatusLabel switchView:self.watchSyncSwitch];
    UIView *card2 = [self createCard:L(@" APPLE TV HARDWARE LINK", @" Apple TV 硬件设备直连") valueLabel:self.tvStatusLabel switchView:self.tvScanSwitch];
    UITapGestureRecognizer *tvCardTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTVCardTapped)];
    [card2 addGestureRecognizer:tvCardTap];
    card2.userInteractionEnabled = YES;
    
    UIView *card3 = [self createCard:L(@"LATEST DETECTED ACTION", @"最终判定体感动作") valueLabel:self.logLabel switchView:nil];
    
    __weak typeof(self) weakSelf = self;
    self.videoControlCard = [[HSBHomeVideoControlCard alloc] init];
    self.videoControlCard.hidden = YES;
    self.videoControlCard.onSeekRequested = ^(NSTimeInterval seekTime) {
        [weakSelf sendSeekToTV:seekTime];
    };
    [self.themeCards addObject:self.videoControlCard];
    
    self.browserControlCard = [[HSBHomeBrowserControlCard alloc] init];
    self.browserControlCard.onOpenURLRequested = ^(NSString * _Nonnull url) {
        [weakSelf sendOpenURLToTV:url];
    };
    self.browserControlCard.onOpenRemoteRequested = ^{
        [weakSelf openModernRemoteController];
    };
    self.browserControlCard.onEditHomeConfigRequested = ^{
        HomeConfigEditViewController *vc = [[HomeConfigEditViewController alloc] init];
        [weakSelf.navigationController pushViewController:vc animated:YES];
    };
    [self.themeCards addObject:self.browserControlCard];
    
    self.watchStatusLabel.text = L(@"🟡 Connecting...", @"🟡 获取 Apple Watch 状态中...");
    self.tvStatusLabel.text = L(@"⚪️ Hardware Idle", @"⚪️ 未连接 Apple TV 硬件");
    self.logLabel.text = L(@"Waiting for gestures...", @"等待进行体感动作...");
    self.logLabel.textColor = [UIColor tertiaryLabelColor];
    
    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[card1, card2, card3]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 6;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:stack];
    
    UIView *tableContainer = [[UIView alloc] init];
    tableContainer.backgroundColor = [UIColor secondarySystemBackgroundColor];
    tableContainer.layer.cornerRadius = 16;
    tableContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [self.themeCards addObject:tableContainer];
    [self.view addSubview:tableContainer];
    
    UILabel *tableTitle = [[UILabel alloc] init];
    tableTitle.text = L(@"APPLE TV HARDWARE UNITS", @"Apple TV 硬件终端");
    tableTitle.font = [UIFont systemFontOfSize:12 weight:UIFontWeightBold];
    tableTitle.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.6];
    tableTitle.translatesAutoresizingMaskIntoConstraints = NO;
    [tableContainer addSubview:tableTitle];
    
    self.scanSpinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.scanSpinner.color = [HSBThemeManager shared].currentPalette.primaryColor;
    self.scanSpinner.hidesWhenStopped = YES;
    self.scanSpinner.translatesAutoresizingMaskIntoConstraints = NO;
    [tableContainer addSubview:self.scanSpinner];
    
    self.tvTableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tvTableView.backgroundColor = [UIColor clearColor];
    self.tvTableView.separatorColor = [[UIColor whiteColor] colorWithAlphaComponent:0.08];
    self.tvTableView.rowHeight = 60;
    self.tvTableView.translatesAutoresizingMaskIntoConstraints = NO;
    [tableContainer addSubview:self.tvTableView];
    
    self.deviceListManager = [[HSBHomeDeviceListManager alloc] initWithTableView:self.tvTableView
                                                                        spinner:self.scanSpinner
                                                       presentingViewController:self];
    self.deviceListManager.delegate = self;
    
    self.statsCard = [[HSBHomeActivityStatsCard alloc] init];
    self.statsCard.onAdjustGoalRequested = ^{
        [weakSelf.activityTracker showSetGoalAlertFrom:weakSelf];
    };
    [self.themeCards addObject:self.statsCard];
    [self.view addSubview:self.statsCard];
    [self.view addSubview:self.videoControlCard];
    [self.view addSubview:self.browserControlCard];
    
    [NSLayoutConstraint activateConstraints:@[
        [subtitleLabel.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:4],
        [subtitleLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [subtitleLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        
        [stack.topAnchor constraintEqualToAnchor:subtitleLabel.bottomAnchor constant:10],
        [stack.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [stack.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        
        [tableContainer.topAnchor constraintEqualToAnchor:stack.bottomAnchor constant:12],
        [tableContainer.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [tableContainer.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        [tableContainer.heightAnchor constraintEqualToConstant:190],
        
        [tableTitle.topAnchor constraintEqualToAnchor:tableContainer.topAnchor constant:16],
        [tableTitle.leadingAnchor constraintEqualToAnchor:tableContainer.leadingAnchor constant:20],
        [tableTitle.trailingAnchor constraintLessThanOrEqualToAnchor:self.scanSpinner.leadingAnchor constant:-8],
        
        [self.scanSpinner.centerYAnchor constraintEqualToAnchor:tableTitle.centerYAnchor],
        [self.scanSpinner.trailingAnchor constraintEqualToAnchor:tableContainer.trailingAnchor constant:-20],
        
        [self.tvTableView.topAnchor constraintEqualToAnchor:tableTitle.bottomAnchor constant:8],
        [self.tvTableView.leadingAnchor constraintEqualToAnchor:tableContainer.leadingAnchor],
        [self.tvTableView.trailingAnchor constraintEqualToAnchor:tableContainer.trailingAnchor],
        [self.tvTableView.bottomAnchor constraintEqualToAnchor:tableContainer.bottomAnchor constant:-8],
        
        [self.statsCard.topAnchor constraintEqualToAnchor:tableContainer.bottomAnchor constant:12],
        [self.statsCard.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [self.statsCard.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        [self.videoControlCard.topAnchor constraintEqualToAnchor:self.statsCard.bottomAnchor constant:12],
        [self.videoControlCard.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [self.videoControlCard.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        [self.browserControlCard.topAnchor constraintEqualToAnchor:self.videoControlCard.bottomAnchor constant:12],
        [self.browserControlCard.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [self.browserControlCard.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        [self.browserControlCard.bottomAnchor constraintLessThanOrEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-20]
    ]];
}

- (UILabel *)createLabel {
    UILabel *l = [[UILabel alloc] init];
    l.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    l.textColor = [UIColor whiteColor];
    l.numberOfLines = 0;
    l.translatesAutoresizingMaskIntoConstraints = NO;
    return l;
}

- (UIView *)createCard:(NSString *)title valueLabel:(UILabel *)valueLabel switchView:(UISwitch *)switchView {
    UIView *view = [[UIView alloc] init];
    view.backgroundColor = [UIColor secondarySystemBackgroundColor];
    view.layer.cornerRadius = 14;
    view.translatesAutoresizingMaskIntoConstraints = NO;
    [self.themeCards addObject:view];
    
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = title;
    titleLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightBold];
    titleLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.5];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [view addSubview:titleLabel];
    [view addSubview:valueLabel];
    
    if (switchView) {
        [view addSubview:switchView];
        [NSLayoutConstraint activateConstraints:@[
            [titleLabel.topAnchor constraintEqualToAnchor:view.topAnchor constant:10],
            [titleLabel.leadingAnchor constraintEqualToAnchor:view.leadingAnchor constant:18],
            [titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:switchView.leadingAnchor constant:-12],
            [switchView.centerYAnchor constraintEqualToAnchor:view.centerYAnchor],
            [switchView.trailingAnchor constraintEqualToAnchor:view.trailingAnchor constant:-18],
            [switchView.widthAnchor constraintEqualToConstant:51],
            [valueLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:4],
            [valueLabel.leadingAnchor constraintEqualToAnchor:view.leadingAnchor constant:18],
            [valueLabel.trailingAnchor constraintLessThanOrEqualToAnchor:switchView.leadingAnchor constant:-12],
            [valueLabel.bottomAnchor constraintEqualToAnchor:view.bottomAnchor constant:-10]
        ]];
    } else {
        [NSLayoutConstraint activateConstraints:@[
            [titleLabel.topAnchor constraintEqualToAnchor:view.topAnchor constant:10],
            [titleLabel.leadingAnchor constraintEqualToAnchor:view.leadingAnchor constant:18],
            [titleLabel.trailingAnchor constraintEqualToAnchor:view.trailingAnchor constant:-18],
            [valueLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:4],
            [valueLabel.leadingAnchor constraintEqualToAnchor:view.leadingAnchor constant:18],
            [valueLabel.trailingAnchor constraintEqualToAnchor:view.trailingAnchor constant:-18],
            [valueLabel.bottomAnchor constraintEqualToAnchor:view.bottomAnchor constant:-10]
        ]];
    }
    return view;
}

#pragma mark - Activity Tracker Delegate

- (void)activityTrackerDidUpdateSteps:(NSNumber *)steps {
    [self.statsCard updateSteps:steps];
}

- (void)activityTrackerDidUpdateProgress:(NSInteger)current target:(NSInteger)target isGoalReached:(BOOL)isGoalReached {
    [self.statsCard updateProgress:current target:target isGoalReached:isGoalReached];
}

#pragma mark - Device List Manager Delegate

- (void)deviceListManager:(HSBHomeDeviceListManager *)manager didChangeStatusText:(NSString *)text color:(UIColor *)color {
    self.tvStatusLabel.text = text;
    self.tvStatusLabel.textColor = color;
}

- (void)deviceListManager:(HSBHomeDeviceListManager *)manager didUpdateDeviceCount:(NSUInteger)count {
    // 自动刷新
}

- (void)deviceListManager:(HSBHomeDeviceListManager *)manager didConnectSuccessToDevice:(HSBDiscoveredAppleTV *)device {
    [self pushToModernRemoteWithDevice:device];
}

- (void)deviceListManagerDidRequestQRCodeScanner:(HSBHomeDeviceListManager *)manager {
    [self openQRCodeScanner];
}

- (void)handleTVCardTapped {
    [self.deviceListManager reopenPINAlertIfNeeded];
}

#pragma mark - Navigation & Actions

- (void)openSettings {
    SettingsViewController *settingsVC = [[SettingsViewController alloc] init];
    [self.navigationController pushViewController:settingsVC animated:YES];
}

- (void)openModernRemoteController {
    [self pushToModernRemoteWithDevice:nil];
}

- (void)openQRCodeScanner {
    HSBQRCodeScannerViewController *scannerVC = [[HSBQRCodeScannerViewController alloc] init];
    scannerVC.delegate = self;
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:scannerVC];
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)pushToModernRemoteWithDevice:(HSBDiscoveredAppleTV *)device {
    if (device) {
        [HSBModernRemoteBridge setCurrentTargetDevice:device];
    }
    UIViewController *modernVC = [HSBModernRemoteBridge createModernRemoteViewController];
    modernVC.hidesBottomBarWhenPushed = YES;
    [self.navigationController pushViewController:modernVC animated:YES];
}

#pragma mark - TV Actions

- (void)sendSeekToTV:(NSTimeInterval)seekTime {
    if (![HSBTVOSConnectionManager sharedManager].isConnected) return;
    NSMutableDictionary *payload = [NSMutableDictionary dictionary];
    payload[HSBRemotePayloadKeyAction] = HSBRemoteSimulateActionSeekAbsolute;
    payload[HSBRemotePayloadKeyValue] = @(seekTime);
    [[HSBTVOSConnectionManager sharedManager] sendPayload:payload];
}

- (void)sendOpenURLToTV:(NSString *)urlString {
    if (![HSBTVOSConnectionManager sharedManager].isConnected) return;
    NSMutableDictionary *payload = [NSMutableDictionary dictionary];
    payload[HSBRemotePayloadKeyAction] = HSBRemoteSimulateActionOpenUrl;
    payload[HSBRemotePayloadKeyValue] = urlString;
    [[HSBTVOSConnectionManager sharedManager] sendPayload:payload];
}

#pragma mark - Watch Session & Switches

- (void)watchSyncSwitchChanged:(UISwitch *)sender {
    self.watchSyncEnabled = sender.isOn;
    [self updateWatchSessionState];
}

- (void)tvScanSwitchChanged:(UISwitch *)sender {
    self.tvScanEnabled = sender.isOn;
    if (sender.isOn) {
        [self.deviceListManager startScanning];
    } else {
        [self.deviceListManager stopScanning];
    }
}

- (void)updateWatchSessionState {
    if (!self.watchSyncEnabled) {
        self.watchStatusLabel.text = L(@"🔴 Gesture Sync Disabled (Power Save)", @"🔴 手势同步已关闭 (省电模式)");
        self.watchStatusLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.4];
        return;
    }
    __weak typeof(self) weakSelf = self;
    [[HSBWatchSessionManager sharedManager] updateWatchSessionStateWithHandler:^(NSString *statusText) {
        dispatch_async(dispatch_get_main_queue(), ^{
            weakSelf.watchStatusLabel.textColor = [UIColor whiteColor];
            weakSelf.watchStatusLabel.text = statusText;
        });
    }];
}

#pragma mark - Notifications

- (void)handleTVOSConnectionStateChanged:(NSNotification *)note {
    BOOL isConn = [HSBTVOSConnectionManager sharedManager].isConnected;
    dispatch_async(dispatch_get_main_queue(), ^{
        self.videoControlCard.hidden = !isConn;
    });
}

- (void)handleWatchReachabilityChanged:(NSNotification *)note {
    [self updateWatchSessionState];
}

- (void)handleWatchActionReceived:(NSNotification *)note {
    NSString *action = note.userInfo[@"action"];
    if (action.length > 0) {
        [self.activityTracker incrementActionScore];
        self.logLabel.text = [NSString stringWithFormat:L(@"Action: %@", @"捕获体感: %@"), action];
    }
}

- (void)handleLLMPrewarmingStarted:(NSNotification *)note {
    [self.aiLoadingHUD setHidden:NO];
}

- (void)handleLLMPrewarmingFinished:(NSNotification *)note {
    [self.aiLoadingHUD setHidden:YES];
}

- (void)setupAILoadingHUD {
    // LLM prewarming HUD placeholder
}

- (void)applyThemeStyle {
    [super applyThemeStyle];
    HSBThemePalette *p = [HSBThemeManager shared].currentPalette;
    self.view.backgroundColor = p.backgroundColor;
    self.watchSyncSwitch.onTintColor = p.primaryColor;
    self.tvScanSwitch.onTintColor = p.primaryColor;
    [self.videoControlCard applyThemePrimaryColor:p.primaryColor];
    [self.browserControlCard applyThemePrimaryColor:p.primaryColor];
    self.scanSpinner.color = p.primaryColor;
    [self.tvTableView reloadData];
}

#pragma mark - HSBQRCodeScannerDelegate

- (void)qrCodeScanner:(HSBQRCodeScannerViewController *)scanner didScanPairingURL:(NSURL *)url {
    [scanner dismissViewControllerAnimated:YES completion:^{
        [[HSBTVOSConnectionManager sharedManager] connectToPairingURL:url];
    }];
}

- (void)qrCodeScannerDidCancel:(HSBQRCodeScannerViewController *)scanner {
    [scanner dismissViewControllerAnimated:YES completion:nil];
}

@end
