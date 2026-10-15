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
#import "HSBOpenSourceLibrariesViewController.h"
#import "HSBLLMModelCenterViewController.h"
#import "HSBLLMTestViewController.h"
#import "HSBAboutViewController.h"
#import "HSBWatchCompanion-Swift.h"

#define BONJOUR_SERVICE_TYPE "_thltv._tcp"

static NSString * L(NSString *en, NSString *zh) {
    NSString *language = [[NSLocale preferredLanguages] firstObject];
    if ([language hasPrefix:@"zh"]) {
        return zh ?: en;
    }
    return en;
}



@interface ViewController () <UITableViewDelegate, UITableViewDataSource, UIGestureRecognizerDelegate, UITextFieldDelegate, HSBQRCodeScannerDelegate>

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
@property (nonatomic, strong) NSMutableArray<HSBDiscoveredAppleTV *> *discoveredDevices;
@property (nonatomic, strong) NSMutableArray<nw_endpoint_t> *discoveredEndpoints;
@property (nonatomic, strong) nw_endpoint_t currentEndpoint;
@property (nonatomic, strong) NSString *connectingDeviceHost;

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
@property (nonatomic, weak) UIAlertController *currentLoadingAlert; // 当前连接等待弹窗弱引用

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
    self.discoveredDevices = [NSMutableArray array];
    
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
    
    // 监听本地大模型异步后台载入（预热）状态的广播通知（非阻断式静默流转）
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleLLMPrewarmingStarted:) name:@"HSBLocalLLM_PrewarmingStartedNotification" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleLLMPrewarmingFinished:) name:@"HSBLocalLLM_PrewarmingFinishedNotification" object:nil];

    
    // 注册 TVOSConnectionManager 通知与 WatchSession 通知
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleTVOSConnectionStateChanged:) name:HSBTVOSConnectionStateNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleWatchReachabilityChanged:) name:HSBWatchSessionReachabilityDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleWatchActionReceived:) name:HSBWatchActionReceivedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleAppleTVNativePINRequired:) name:@"HSBAppleTVNativePINRequiredNotification" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleAppleTVNativePINSubmitting:) name:@"HSBAppleTVNativePINSubmittingNotification" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleAppleTVNativePINCancelled:) name:@"HSBAppleTVNativePINCancelledNotification" object:nil];
    [self applyThemeStyle];
    
    // 配置返回按钮仅展示纯图标箭头，隐藏冗余页面标题文字
    if (@available(iOS 14.0, *)) {
        self.navigationItem.backButtonDisplayMode = UINavigationItemBackButtonDisplayModeMinimal;
    }
    self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"" style:UIBarButtonItemStylePlain target:nil action:nil];
    
    NSArray *args = [NSProcessInfo processInfo].arguments;
    BOOL shouldOpenModernRemote = [[NSUserDefaults standardUserDefaults] boolForKey:@"UITestOpenModernRemote"] ||
                                  [args containsObject:@"--open-remote"] ||
                                  [args containsObject:@"--guide-browser"] ||
                                  [args containsObject:@"--guide-system"] ||
                                  [args containsObject:@"--guide-pin"];
    if (shouldOpenModernRemote) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self pushToModernRemoteWithDevice:nil];
            if ([args containsObject:@"--guide-browser"]) {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [[NSNotificationCenter defaultCenter] postNotificationName:@"HSBShowGuideModalNotification" object:nil userInfo:@{@"type": @"browser"}];
                });
            } else if ([args containsObject:@"--guide-system"]) {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [[NSNotificationCenter defaultCenter] postNotificationName:@"HSBShowGuideModalNotification" object:nil userInfo:@{@"type": @"system"}];
                });
            }
        });
    } else if ([[NSUserDefaults standardUserDefaults] boolForKey:@"UITestOpenSettings"] ||
               [args containsObject:@"--test-open-settings"]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self openSettings];
        });
    } else if ([[NSUserDefaults standardUserDefaults] boolForKey:@"UITestOpenOpenSource"] ||
               [[NSUserDefaults standardUserDefaults] boolForKey:@"UITestOpenComponents"] ||
               [args containsObject:@"--test-open-components"]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            HSBOpenSourceLibrariesViewController *vc = [[HSBOpenSourceLibrariesViewController alloc] init];
            [self.navigationController pushViewController:vc animated:NO];
        });
    } else if ([[NSUserDefaults standardUserDefaults] boolForKey:@"UITestOpenModelCenter"]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            HSBLLMModelCenterViewController *vc = [[HSBLLMModelCenterViewController alloc] init];
            [self.navigationController pushViewController:vc animated:NO];
        });
    } else if ([[NSUserDefaults standardUserDefaults] boolForKey:@"UITestOpenAIAssistant"]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            HSBLLMTestViewController *vc = [[HSBLLMTestViewController alloc] init];
            [self.navigationController pushViewController:vc animated:NO];
        });
    } else if ([[NSUserDefaults standardUserDefaults] boolForKey:@"UITestOpenAbout"] ||
               [args containsObject:@"--test-open-about"]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            HSBAboutViewController *vc = [[HSBAboutViewController alloc] init];
            [self.navigationController pushViewController:vc animated:NO];
        });
    } else if ([[NSUserDefaults standardUserDefaults] boolForKey:@"UITestRunAppleTVVerification"] ||
               [args containsObject:@"--run-appletv-tests"]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [HSBAppleTVDiscoveryVerificationTest runAllTestsWithCompletion:^(BOOL allPassed, NSString * _Nonnull report) {
                NSLog(@"[AppleTVVerificationTest]\n%@", report);
                if (allPassed) {
                    NSLog(@"[AppleTVVerificationTest] ALL_TESTS_PASSED");
                }
            }];
        });
    } else if ([[NSUserDefaults standardUserDefaults] boolForKey:@"UITestOpenBrowserControl"]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            BrowserControlViewController *vc = [[BrowserControlViewController alloc] init];
            [self.navigationController pushViewController:vc animated:NO];
        });
    } else if ([[NSUserDefaults standardUserDefaults] boolForKey:@"UITestOpenTVDetail"]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            TVDetailViewController *vc = [[TVDetailViewController alloc] init];
            vc.deviceName = @"糖葫芦浏览器";
            [self.navigationController pushViewController:vc animated:NO];
        });
    } else if ([args containsObject:@"--test-connect-device"]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (self.discoveredDevices.count > 0) {
                [self tableView:self.tvTableView didSelectRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
            }
        });
    } else if ([args containsObject:@"--test-connect-mac"]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            for (NSInteger i = 0; i < self.discoveredDevices.count; i++) {
                HSBDiscoveredAppleTV *dev = self.discoveredDevices[i];
                if (dev.isMacDevice) {
                    [self tableView:self.tvTableView didSelectRowAtIndexPath:[NSIndexPath indexPathForRow:i inSection:0]];
                    break;
                }
            }
        });
    } else if ([args containsObject:@"--test-mac-media"]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            HSBDiscoveredAppleTV *macDev = [[HSBDiscoveredAppleTV alloc] initWithId:@"MacBookPro18,1"
                                                                               name:@"MacBook Pro (办公桌)"
                                                                               host:@"MacBook-Pro.local"
                                                                               port:49152
                                                                          modelName:@"MacBookPro18,1"
                                                                    isNativeAppleTV:NO
                                                                       isBrowserApp:NO
                                                                        rawEndpoint:nil];
            [self pushToModernRemoteWithDevice:macDev];
        });
    }
}

- (void)applyThemeStyle {
    [super applyThemeStyle];
    HSBThemePalette *palette = [HSBThemeManager shared].currentPalette;
    
    for (UIView *card in self.themeCards) {
        card.backgroundColor = palette.cardBgColor;
        card.layer.borderColor = [palette.primaryColor colorWithAlphaComponent:0.15].CGColor;
        card.layer.borderWidth = 1.0;
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
    
    // 动态同步首页右上角按钮的颜色
    for (UIBarButtonItem *item in self.navigationItem.rightBarButtonItems) {
        if (item.action == @selector(openModernRemoteController)) {
            item.tintColor = palette.primaryColor;
        }
    }
    
    // 实时重绘主列表里的电视设备图标颜色
    if (self.tvTableView) {
        [self.tvTableView reloadData];
    }
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
            [HSBModernRemoteBridge showLaunchEntranceAnimationOn:self];
        }
    });
#if DEBUG
    if (getenv("AUTO_OPEN_REMOTE") || [[NSUserDefaults standardUserDefaults] boolForKey:@"UITestOpenRemote"]) {
        static dispatch_once_t autoOpenToken;
        dispatch_once(&autoOpenToken, ^{
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self openModernRemoteController];
            });
        });
    }
#endif
    
    NSArray *args = [NSProcessInfo processInfo].arguments;
    if ([args containsObject:@"--test-pin-alert"]) {
        static dispatch_once_t pinToken;
        dispatch_once(&pinToken, ^{
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:@"HSBAppleTVNativePINRequiredNotification"
                                                                    object:nil
                                                                  userInfo:@{@"name": @"客厅 Apple TV 4K"}];
            });
        });
    } else if ([args containsObject:@"--guide-browser"] || [args containsObject:@"--guide-pin"]) {
        static dispatch_once_t guideToken;
        dispatch_once(&guideToken, ^{
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self openModernRemoteController];
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.6 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [[NSNotificationCenter defaultCenter] postNotificationName:@"HSBShowGuideModalNotification"
                                                                        object:nil
                                                                      userInfo:@{@"type": @"browser"}];
                });
            });
        });
    } else if ([args containsObject:@"--guide-system"]) {
        static dispatch_once_t guideSysToken;
        dispatch_once(&guideSysToken, ^{
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self openModernRemoteController];
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.6 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [[NSNotificationCenter defaultCenter] postNotificationName:@"HSBShowGuideModalNotification"
                                                                        object:nil
                                                                      userInfo:@{@"type": @"system"}];
                });
            });
        });
    }
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
    
    // Settings & Modern Remote Buttons
    UIBarButtonItem *settingsItem = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"gearshape.fill"] style:UIBarButtonItemStylePlain target:self action:@selector(openSettings)];
    settingsItem.tintColor = [UIColor whiteColor];
    
    UIBarButtonItem *remoteItem = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"appletvremote.gen4.fill"] style:UIBarButtonItemStylePlain target:self action:@selector(openModernRemoteController)];
    remoteItem.tintColor = [HSBThemeManager shared].currentPalette.primaryColor;
    
    UIBarButtonItem *scanItem = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"qrcode.viewfinder"] style:UIBarButtonItemStylePlain target:self action:@selector(openQRCodeScanner)];
    scanItem.tintColor = [UIColor systemOrangeColor];
    
    self.navigationItem.rightBarButtonItems = @[settingsItem, remoteItem, scanItem];
    
    // Subtitle
    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.text = L(@"Keep this app open while using your Watch.", @"在使用手表遥控时保持此应用在前台运行");
    subtitleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
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
    UIView *card2 = [self createCard:L(@" APPLE TV HARDWARE LINK", @" Apple TV 硬件设备直连") valueLabel:self.tvStatusLabel switchView:self.tvScanSwitch];
    UIView *card3 = [self createCard:L(@"LATEST DETECTED ACTION", @"最终判定体感动作") valueLabel:self.logLabel switchView:nil];
    
    // Video Control Card
    self.videoControlCard = [self createVideoControlCard];
    self.videoControlCard.hidden = YES;
    
    // Browser Control Card
    self.browserControlCard = [self createBrowserControlCard];
    
    // Status Defaults
    self.watchStatusLabel.text = L(@"🟡 Connecting...", @"🟡 获取 Apple Watch 状态中...");
    self.tvStatusLabel.text = L(@"⚪️ Hardware Idle", @"⚪️ 未连接 Apple TV 硬件");
    self.logLabel.text = L(@"Waiting for gestures...", @"等待进行体感动作...");
    self.logLabel.textColor = [UIColor tertiaryLabelColor];
    
    // Stack View
    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[card1, card2, card3]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 6;
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
    tableTitle.text = L(@"APPLE TV HARDWARE UNITS", @"Apple TV 硬件终端");
    tableTitle.font = [UIFont systemFontOfSize:12 weight:UIFontWeightBold];
    tableTitle.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.6];
    tableTitle.translatesAutoresizingMaskIntoConstraints = NO;
    [tableContainer addSubview:tableTitle];
    
    self.scanSpinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.scanSpinner.color = [UIColor whiteColor];
    self.scanSpinner.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scanSpinner startAnimating];
    [tableContainer addSubview:self.scanSpinner];
    
    // 配对指引与帮助按钮
    UIButton *helpBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [helpBtn setImage:[UIImage systemImageNamed:@"questionmark.circle.fill" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:16 weight:UIImageSymbolWeightMedium]] forState:UIControlStateNormal];
    helpBtn.tintColor = [HSBThemeManager tanghuluBrandColor];
    [helpBtn addTarget:self action:@selector(showPairingGuideAlert) forControlEvents:UIControlEventTouchUpInside];
    helpBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [tableContainer addSubview:helpBtn];
    
    self.tvTableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tvTableView.delegate = self;
    self.tvTableView.dataSource = self;
    self.tvTableView.backgroundColor = [UIColor clearColor];
    self.tvTableView.rowHeight = 58;
    self.tvTableView.layer.masksToBounds = YES;
    self.tvTableView.translatesAutoresizingMaskIntoConstraints = NO;
    
    UILabel *emptyLabel = [[UILabel alloc] init];
    emptyLabel.text = L(@"Scanning for nearby Apple TV devices...\nTip: Tap the remote icon in the top right for instant offline control.", @"正在扫描局域网 Apple TV 硬件设备...\n提示：您可随时点击右上角遥控器图标离线使用全部功能。");
    emptyLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    emptyLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.45];
    emptyLabel.textAlignment = NSTextAlignmentCenter;
    emptyLabel.numberOfLines = 0;
    self.tvTableView.backgroundView = emptyLabel;
    emptyLabel.hidden = NO;
    
    [tableContainer addSubview:self.tvTableView];
    
    [NSLayoutConstraint activateConstraints:@[
        [subtitleLabel.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:8],
        [subtitleLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [subtitleLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        
        // 状态卡片 Stack（紧接 Subtitle 下方，布局清爽大方）
        [stack.topAnchor constraintEqualToAnchor:subtitleLabel.bottomAnchor constant:12],
        [stack.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [stack.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        
        // 大屏列表区域
        [tableContainer.topAnchor constraintEqualToAnchor:stack.bottomAnchor constant:10],
        [tableContainer.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [tableContainer.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        [tableContainer.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-14],
        
        [tableTitle.topAnchor constraintEqualToAnchor:tableContainer.topAnchor constant:14],
        [tableTitle.leadingAnchor constraintEqualToAnchor:tableContainer.leadingAnchor constant:16],
        
        [self.scanSpinner.centerYAnchor constraintEqualToAnchor:tableTitle.centerYAnchor],
        [self.scanSpinner.leadingAnchor constraintEqualToAnchor:tableTitle.trailingAnchor constant:8],
        
        [helpBtn.centerYAnchor constraintEqualToAnchor:tableTitle.centerYAnchor],
        [helpBtn.trailingAnchor constraintEqualToAnchor:tableContainer.trailingAnchor constant:-16],
        [helpBtn.widthAnchor constraintEqualToConstant:28],
        [helpBtn.heightAnchor constraintEqualToConstant:28],
        
        [self.tvTableView.topAnchor constraintEqualToAnchor:tableTitle.bottomAnchor constant:8],
        [self.tvTableView.leadingAnchor constraintEqualToAnchor:tableContainer.leadingAnchor],
        [self.tvTableView.trailingAnchor constraintEqualToAnchor:tableContainer.trailingAnchor],
        [self.tvTableView.bottomAnchor constraintEqualToAnchor:tableContainer.bottomAnchor constant:-8]
    ]];
}

- (void)openQRCodeScanner {
    HSBQRCodeScannerViewController *scanner = [[HSBQRCodeScannerViewController alloc] init];
    scanner.delegate = self;
    scanner.modalPresentationStyle = UIModalPresentationFullScreen;
    [self presentViewController:scanner animated:YES completion:nil];
}

- (void)qrCodeScanner:(HSBQRCodeScannerViewController *)scanner didScanPairingURL:(NSURL *)url {
    NSLog(@"[ViewController] Scanned pairing URL: %@", url);
    [[HSBTVOSConnectionManager sharedManager] connectToPairingURL:url];
    
    UIAlertController *loadingAlert = [UIAlertController alertControllerWithTitle:L(@"正在安全配对", @"正在安全配对")
                                                                          message:L(@"正在与 Apple TV 协商双向加密凭证...", @"正在与 Apple TV 协商双向加密凭证...")
                                                                   preferredStyle:UIAlertControllerStyleAlert];
    [self presentViewController:loadingAlert animated:YES completion:nil];
    
    __weak typeof(self) weakSelf = self;
    __block id observerToken = [[NSNotificationCenter defaultCenter] addObserverForName:HSBTVOSConnectionStateNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * _Nonnull note) {
        if ([HSBTVOSConnectionManager sharedManager].isConnected) {
            if (observerToken) {
                [[NSNotificationCenter defaultCenter] removeObserver:observerToken];
                observerToken = nil;
            }
            [loadingAlert dismissViewControllerAnimated:YES completion:^{
                [weakSelf pushToModernRemoteWithDevice:nil];
            }];
        }
    }];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(6.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (observerToken) {
            [[NSNotificationCenter defaultCenter] removeObserver:observerToken];
            observerToken = nil;
        }
        if ([weakSelf presentedViewController] == loadingAlert) {
            [loadingAlert dismissViewControllerAnimated:YES completion:nil];
        }
    });
}

- (void)qrCodeScannerDidCancel:(HSBQRCodeScannerViewController *)scanner {
    NSLog(@"[ViewController] QR code scanning cancelled by user.");
}

- (void)showPairingGuideAlert {
    NSString *msg = L(@"【三步完成电视配对与绑定】\n\n1. 启动电视 App：\n在 Apple TV 上打开【糖葫芦视界】或【糖葫芦浏览器】；\n\n2. 调出配对二维码：\n在电视主界面，选中顶部的【📱 手机遥控配对】卡片并按遥控器确认，大屏将呈现专属配对二维码；\n\n3. 手机扫码秒连：\n点击下方【📷 立即扫码配对】（或点击主界面右上角扫码图标），扫描电视屏幕上的二维码，即可在 0.5 秒内完成安全配对并永久绑定！",
                      @"【三步完成电视配对与绑定】\n\n1. 启动电视 App：\n在 Apple TV 上打开【糖葫芦视界】或【糖葫芦浏览器】；\n\n2. 调出配对二维码：\n在电视主界面，选中顶部的【📱 手机遥控配对】卡片并按遥控器确认，大屏将呈现专属配对二维码；\n\n3. 手机扫码秒连：\n点击下方【📷 立即扫码配对】（或点击主界面右上角扫码图标），扫描电视屏幕上的二维码，即可在 0.5 秒内完成安全配对并永久绑定！");
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:L(@"📺 电视遥控配对指引", @"📺 电视遥控配对指引") message:msg preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:L(@"📷 立即扫码配对", @"📷 立即扫码配对") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self openQRCodeScanner];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:L(@"进入遥控器", @"进入遥控器") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self openModernRemoteController];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:L(@"我知道了", @"我知道了") style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
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
    titleLabel.numberOfLines = 0;
    titleLabel.lineBreakMode = NSLineBreakByWordWrapping;
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [titleLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    
    valueLabel.numberOfLines = 0;
    valueLabel.lineBreakMode = NSLineBreakByWordWrapping;
    [valueLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    
    [view addSubview:titleLabel];
    [view addSubview:valueLabel];
    
    if (switchView) {
        [view addSubview:switchView];
        [switchView setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
        [switchView setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
        
        NSLayoutConstraint *switchTrailing = [switchView.trailingAnchor constraintEqualToAnchor:view.trailingAnchor constant:-16];
        switchTrailing.priority = UILayoutPriorityRequired;
        
        [NSLayoutConstraint activateConstraints:@[
            [titleLabel.topAnchor constraintEqualToAnchor:view.topAnchor constant:10],
            [titleLabel.leadingAnchor constraintEqualToAnchor:view.leadingAnchor constant:18],
            [titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:switchView.leadingAnchor constant:-12],
            
            [switchView.centerYAnchor constraintEqualToAnchor:view.centerYAnchor],
            switchTrailing,
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
    [self openModernRemoteController];
}

- (void)pushToModernRemoteWithDevice:(HSBDiscoveredAppleTV *)device {
    if (device) {
        [HSBModernRemoteBridge setCurrentTargetDevice:device];
    }
    UIViewController *modernVC = [HSBModernRemoteBridge createModernRemoteViewController];
    modernVC.hidesBottomBarWhenPushed = YES;
    if (self.navigationController) {
        [self.navigationController pushViewController:modernVC animated:YES];
    } else {
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:modernVC];
        nav.modalPresentationStyle = UIModalPresentationFullScreen;
        if (@available(iOS 13.0, *)) {
            nav.modalInPresentation = YES;
        }
        UIBarButtonItem *closeItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemClose target:self action:@selector(dismissModernRemoteModal)];
        modernVC.navigationItem.leftBarButtonItem = closeItem;
        [self presentViewController:nav animated:YES completion:nil];
    }
}

- (void)openModernRemoteController {
    // 1. 如果当前已经处于连接状态，直接进入遥控器页面
    if ([HSBModernRemoteBridge isUnifiedConnected]) {
        [self pushToModernRemoteWithDevice:nil];
        return;
    }
    
    // 2. 如果未连接，但存在已配对电视记录，自动发起重连并进入遥控器页面
    if ([HSBTVOSConnectionManager pairedTVRecords].count > 0) {
        [[HSBTVOSConnectionManager sharedManager] connectToLastPairedTV];
        [self pushToModernRemoteWithDevice:nil];
        return;
    }
    
    // 2. 如果未连接，但存在已发现的电视设备，触发连接首选设备（连接成功后再进）
    if (self.discoveredDevices.count > 0) {
        HSBDiscoveredAppleTV *firstDevice = self.discoveredDevices.firstObject;
        [self connectAndPushToDevice:firstDevice];
        return;
    }
    
    // 3. 未连接且未扫描到设备，给出温和提示，严禁进入遥控器页面
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:L(@"未连接电视", @"未连接电视")
                                                                   message:L(@"当前尚未连接任何电视设备。请确保 iPhone 与 Apple TV 连接在同一家庭 Wi-Fi，并在下方列表中选择设备进行连接。", @"当前尚未连接任何电视设备。请确保 iPhone 与 Apple TV 连接在同一家庭 Wi-Fi，并在下方列表中选择设备进行连接。")
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:L(@"好的", @"好的") style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:L(@"查看设置指引", @"查看设置指引") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self showPairingGuideAlert];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)dismissModernRemoteModal {
    [self dismissViewControllerAnimated:YES completion:nil];
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
    [self sendDirectPayload:@{HSBRemotePayloadKeyAction: (id)HSBRemoteSimulateActionOpenUrl, HSBRemotePayloadKeyUrl: urlString} msg:[NSString stringWithFormat:L(@"🌐 Navigated to: %@", @"🌐 已跳转至: %@"), urlString]];
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
    payload[HSBRemotePayloadKeyAction] = HSBRemoteSimulateActionUpdateHomeJson;
    payload[HSBRemotePayloadKeyPayload] = jsonString;
    
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
    payload[HSBRemotePayloadKeyAction] = action;
    if (value) {
        payload[HSBRemotePayloadKeyValue] = value;
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
    return self.discoveredDevices.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellID = @"TVCellSubtitle";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellID];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellID];
    }
    cell.backgroundColor = [UIColor clearColor];
    
    HSBThemePalette *palette = [HSBThemeManager shared].currentPalette;
    
    UIView *selectedBg = [[UIView alloc] init];
    selectedBg.backgroundColor = [palette.primaryColor colorWithAlphaComponent:0.15];
    cell.selectedBackgroundView = selectedBg;
    
    if (indexPath.row < self.discoveredDevices.count) {
        HSBDiscoveredAppleTV *device = self.discoveredDevices[indexPath.row];
        cell.textLabel.text = device.name;
        cell.textLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
        cell.textLabel.textColor = [UIColor whiteColor];
        
        cell.imageView.image = [UIImage systemImageNamed:device.deviceCategoryIconName];
        cell.imageView.tintColor = palette.primaryColor;
        
        if (self.connectingDeviceHost && [self.connectingDeviceHost isEqualToString:device.host]) {
            UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
            spinner.color = palette.primaryColor;
            [spinner startAnimating];
            cell.accessoryView = spinner;
            cell.detailTextLabel.text = L(@"Connecting...", @"正在连接...");
            cell.detailTextLabel.textColor = palette.primaryColor;
        } else {
            cell.accessoryView = nil;
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.detailTextLabel.text = device.displaySubtitle;
            cell.detailTextLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.65];
        }
        cell.detailTextLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
    }
    
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    
    return cell;
}

#pragma mark - Native Apple TV PIN Pairing Handling

- (void)handleAppleTVNativePINRequired:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"[NativePIN] Received HSBAppleTVNativePINRequiredNotification in ViewController");
        
        void (^completion)(NSString *) = notification.userInfo[@"completion"];
        NSString *deviceName = notification.userInfo[@"name"];
        
        [self updateUI:^{
            self.tvStatusLabel.text = L(@"🟡 请在屏幕弹窗中输入电视上的 4 位 PIN 码...", @"🟡 请在屏幕弹窗中输入电视上的 4 位 PIN 码...");
            self.tvStatusLabel.textColor = [UIColor systemYellowColor];
        }];
        
        // 顶层主 Window 安全呈现器：标准呈现弹窗，100% 自动唤起系统数字键盘
        [[HSBNativePINAlertPresenter shared] presentPINAlertWithDeviceName:deviceName completion:^(NSString * _Nonnull pin) {
            if (completion) {
                completion(pin);
            }
        }];
    });
}

- (void)handleAppleTVNativePINSubmitting:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"[NativePIN] PIN submitted, verifying and establishing encrypted channel...");
        [self updateUI:^{
            self.tvStatusLabel.text = L(@"🟡 正在验证 PIN 码并建立加密通道...", @"🟡 正在验证 PIN 码并建立加密通道...");
            self.tvStatusLabel.textColor = [UIColor systemYellowColor];
        }];
    });
}

- (void)handleAppleTVNativePINCancelled:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"[NativePIN] PIN pairing cancelled by user");
        self.connectingDeviceHost = nil;
        [self.tvTableView reloadData];
        [self updateUI:^{
            self.tvStatusLabel.text = L(@"⚪️ 已取消配对", @"⚪️ 已取消配对");
            self.tvStatusLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.6];
        }];
    });
}

- (void)connectAndPushToDevice:(HSBDiscoveredAppleTV *)device {
    if (!device) return;
    
    // 如果已经处于连接状态，直接进入遥控器页面
    if ([HSBModernRemoteBridge isUnifiedConnected]) {
        [self pushToModernRemoteWithDevice:device];
        return;
    }
    
    // 避免重复对同一设备发起并发连接
    if (self.connectingDeviceHost && [self.connectingDeviceHost isEqualToString:device.host]) {
        return;
    }
    
    // 如果尚未连接成功，在连接前主动清理可能残留的无效凭证，确保 Apple TV 必定发起 Pair-Setup 并 100% 弹出 PIN 码！
    if (!device.isMacDevice) {
        [HSBModernRemoteBridge clearCredentialsForDevice:device.name];
    }
    
    self.connectingDeviceHost = device.host;
    [self.tvTableView reloadData];
    
    BOOL isMac = device.isMacDevice;
    [self updateUI:^{
        if (isMac) {
            self.tvStatusLabel.text = [NSString stringWithFormat:L(@"🟡 Connecting to Mac %@...", @"🟡 正在连接 Mac %@..."), device.name];
        } else {
            self.tvStatusLabel.text = [NSString stringWithFormat:L(@"🟡 Connecting to Apple TV %@...", @"🟡 正在连接 Apple TV %@..."), device.name];
        }
        self.tvStatusLabel.textColor = [UIColor systemYellowColor];
    }];
    
    __weak typeof(self) weakSelf = self;
    
    // 异步执行双模探测、待机唤醒与通道建立（非模态，零冲突，放宽至15秒）
    [HSBModernRemoteBridge connectToDiscoveredDevice:device timeout:15.0 completion:^(BOOL success, NSString * _Nullable errorMsg) {
        dispatch_async(dispatch_get_main_queue(), ^{
            weakSelf.connectingDeviceHost = nil;
            [weakSelf.tvTableView reloadData];
            
            if (success) {
                // 连接成功：更新状态并平滑推进遥控器页面！
                [weakSelf updateUI:^{
                    weakSelf.tvStatusLabel.text = [NSString stringWithFormat:L(@"🟢 Connected to %@", @"🟢 已连接至 %@"), device.name];
                    weakSelf.tvStatusLabel.textColor = [UIColor systemGreenColor];
                }];
                [weakSelf pushToModernRemoteWithDevice:device];
            } else {
                // 连接未就绪：呈现详尽指引（根据设备类型自适应）
                [weakSelf updateUI:^{
                    weakSelf.tvStatusLabel.text = [NSString stringWithFormat:L(@"🔴 Failed to connect to %@", @"🔴 连接 %@ 失败"), device.name];
                    weakSelf.tvStatusLabel.textColor = [UIColor systemRedColor];
                }];
                
                if (isMac) {
                    NSString *macMsg = [NSString stringWithFormat:L(@"未能与 “%@” 建立原生媒体控制通道。\n\n• 开启免装软件控制通道：\n请确认 Mac 的 [系统设置] -> [通用] -> [隔空播放与接力] 中，已开启【隔空播放接收器】；\n\n• 检查网络环境：\n请确保手机与 Mac 连接在同一局域网 Wi-Fi 下。",
                                                                            @"未能与 “%@” 建立原生媒体控制通道。\n\n• 开启免装软件控制通道：\n请确认 Mac 的 [系统设置] -> [通用] -> [隔空播放与接力] 中，已开启【隔空播放接收器】；\n\n• 检查网络环境：\n请确保手机与 Mac 连接在同一局域网 Wi-Fi 下。"), device.name];
                    UIAlertController *failAlert = [UIAlertController alertControllerWithTitle:L(@"Mac 连接指引", @"Mac 连接指引")
                                                                                       message:macMsg
                                                                                preferredStyle:UIAlertControllerStyleAlert];
                    [failAlert addAction:[UIAlertAction actionWithTitle:L(@"🔄 重试连接", @"🔄 重试连接") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                        [weakSelf connectAndPushToDevice:device];
                    }]];
                    [failAlert addAction:[UIAlertAction actionWithTitle:L(@"好的", @"好的") style:UIAlertActionStyleCancel handler:nil]];
                    [weakSelf presentViewController:failAlert animated:YES completion:nil];
                } else {
                    NSString *msg = [NSString stringWithFormat:L(@"未能与 “%@” 建立连接。\n\n• 如需遥控 Apple TV 全局系统：\n请点击【重试连接】，电视屏幕将弹出 4 位配对码，在手机输入即可完成永久绑定；\n\n• 如需控制电视上的【糖葫芦浏览器】网页：\n请在电视打开应用后，点击下方【扫码连接专属浏览器】。",
                                                                             @"未能与 “%@” 建立连接。\n\n• 如需遥控 Apple TV 全局系统：\n请点击【重试连接】，电视屏幕将弹出 4 位配对码，在手机输入即可完成永久绑定；\n\n• 如需控制电视上的【糖葫芦浏览器】网页：\n请在电视打开应用后，点击下方【扫码连接专属浏览器】。"), device.name];
                    
                    UIAlertController *failAlert = [UIAlertController alertControllerWithTitle:L(@"电视连接指引", @"电视连接指引")
                                                                                       message:msg
                                                                                preferredStyle:UIAlertControllerStyleAlert];
                    [failAlert addAction:[UIAlertAction actionWithTitle:L(@"🔄 重试连接 (等待电视 PIN 码)", @"🔄 重试连接 (等待电视 PIN 码)") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                        // 显式清理旧凭据，确保 Apple TV 必定发起 Pair-Setup 并弹出 PIN 码！
                        [HSBModernRemoteBridge clearCredentialsForDevice:device.name];
                        [weakSelf connectAndPushToDevice:device];
                    }]];
                    [failAlert addAction:[UIAlertAction actionWithTitle:L(@"📷 扫码连接专属浏览器", @"📷 扫码连接专属浏览器") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                        [weakSelf openQRCodeScanner];
                    }]];
                    [failAlert addAction:[UIAlertAction actionWithTitle:L(@"好的", @"好的") style:UIAlertActionStyleCancel handler:nil]];
                    [weakSelf presentViewController:failAlert animated:YES completion:nil];
                }
            }
        });
    }];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    UIImpactFeedbackGenerator *hap = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [hap impactOccurred];
    
    if (indexPath.row < self.discoveredDevices.count) {
        HSBDiscoveredAppleTV *selectedDevice = self.discoveredDevices[indexPath.row];
        [self connectAndPushToDevice:selectedDevice];
    }
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
    NSString *message = userInfo[HSBConnectionStateKeyMessage] ?: userInfo[@"message"];
    nw_connection_state_t state = (nw_connection_state_t)[userInfo[HSBConnectionStateKeyState] ?: userInfo[@"state"] intValue];
    
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

- (void)handleWatchReachabilityChanged:(NSNotification *)note {
    [self updateWatchSessionState];
}

- (void)handleWatchActionReceived:(NSNotification *)note {
    NSString *action = note.userInfo[@"action"];
    if (!action) return;
    
    __weak typeof(self) weakSelf = self;
    [self updateUI:^{
        NSString *readableName = action;
        if ([action isEqualToString:@"flip_up"]) {
            readableName = L(@"⌚️ Wrist Flip Up (Next)", @"⌚️ 向上翻腕 (下一页)");
        } else if ([action isEqualToString:@"flip_down"]) {
            readableName = L(@"⌚️ Wrist Flip Down (Prev)", @"⌚️ 向下翻腕 (上一页)");
        } else if ([action isEqualToString:@"shake"]) {
            readableName = L(@"⌚️ Wrist Shake (Refresh)", @"⌚️ 摇动手腕 (刷新)");
        }
        
        BOOL tvConnected = [HSBTVOSConnectionManager sharedManager].isConnected;
        if (tvConnected) {
            weakSelf.logLabel.text = [NSString stringWithFormat:L(@"✅ %@ -> TV", @"✅ %@ -> 已投送电视"), readableName];
            weakSelf.logLabel.textColor = [UIColor systemGreenColor];
        } else {
            weakSelf.logLabel.text = [NSString stringWithFormat:L(@"⌚️ %@ (TV Offline)", @"⌚️ %@ (电视未连接)"), readableName];
            weakSelf.logLabel.textColor = [UIColor systemCyanColor];
        }
        
        UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
        [feedback impactOccurred];
        
        weakSelf.logLabel.alpha = 0.3;
        [UIView animateWithDuration:0.25 animations:^{
            weakSelf.logLabel.alpha = 1.0;
        }];
    }];
}

- (void)handleTVOSStateUpdated:(NSNotification *)note {
    NSDictionary *userInfo = note.userInfo;
    NSNumber *currentTime = userInfo[HSBRemotePayloadKeyCurrentTime];
    NSNumber *duration = userInfo[HSBRemotePayloadKeyDuration];
    NSNumber *hiddenObj = userInfo[HSBRemotePayloadKeyHidden];
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
        self.browser = nil;
    }
    [[HSBAppleTVDiscovery shared] stopScanning];
    
    [self.discoveredDevices removeAllObjects];
    [self.discoveredEndpoints removeAllObjects];
    [self updateUI:^{
        [self.tvTableView reloadData];
        [self.scanSpinner startAnimating];
        self.scanSpinner.hidden = NO;
        self.tvStatusLabel.text = L(@"🟡 Scanning for Apple TV devices...", @"🟡 正在扫描局域网 Apple TV 硬件设备...");
        self.tvStatusLabel.textColor = [UIColor whiteColor];
    }];
    
    __weak typeof(self) weakSelf = self;
    
    // 🏆 启动参考 itsytv-macos 的 Apple TV 自动发现引擎 (多通道并发扫描 + 0x4000 过滤 + 模型解析)
    [[HSBAppleTVDiscovery shared] startScanningWithOnChange:^(NSArray<HSBDiscoveredAppleTV *> *devices) {
        [weakSelf updateUI:^{
            [weakSelf.discoveredDevices removeAllObjects];
            [weakSelf.discoveredDevices addObjectsFromArray:devices];
            [weakSelf.tvTableView reloadData];
            
            if (weakSelf.discoveredDevices.count > 0) {
                [weakSelf.scanSpinner stopAnimating];
                weakSelf.scanSpinner.hidden = YES;
                weakSelf.tvTableView.backgroundView.hidden = YES;
                weakSelf.tvStatusLabel.text = [NSString stringWithFormat:L(@"🟢 Found %lu Apple TV Device(s)", @"🟢 已发现 %lu 台 Apple TV 硬件设备"), (unsigned long)weakSelf.discoveredDevices.count];
                weakSelf.tvStatusLabel.textColor = [UIColor systemGreenColor];
            }
        }];
    }];
    
    // 10 秒超时若仍无硬件设备，停止旋转菊花并展示空视图提示
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (weakSelf.discoveredDevices.count == 0) {
            [weakSelf.scanSpinner stopAnimating];
            weakSelf.scanSpinner.hidden = YES;
            weakSelf.tvTableView.backgroundView.hidden = NO;
            weakSelf.tvStatusLabel.text = L(@"⚪️ Scanning idle (Tap to retry)", @"⚪️ 扫描完成 (未发现 Apple TV 硬件)");
            weakSelf.tvStatusLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.6];
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
        [[HSBAppleTVDiscovery shared] stopScanning];
        [self.discoveredDevices removeAllObjects];
        [self.discoveredEndpoints removeAllObjects];
        [self.tvTableView reloadData];
        
        [self.scanSpinner stopAnimating];
        self.scanSpinner.hidden = YES;
        
        [[HSBTVOSConnectionManager sharedManager] disconnect];
        [HSBModernRemoteBridge disconnectUnified];
        self.isConnectedToTV = NO;
        self.videoControlCard.hidden = YES;
        
        [self updateUI:^{
            self.tvStatusLabel.text = L(@"🔴 TV Discovery Disabled (Power Save)", @"🔴 电视通道已关闭 (省电模式)");
            self.tvStatusLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.4];
        }];
    }
}

- (void)setupAILoadingHUD {
    // 🏆 非阻断式顶部微型指示胶囊：高度仅 28pt，且 userInteractionEnabled = NO 手势 100% 穿透，绝不遮挡或阻断遥控器按键
    self.aiLoadingHUD = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleDark]];
    self.aiLoadingHUD.translatesAutoresizingMaskIntoConstraints = NO;
    self.aiLoadingHUD.layer.cornerRadius = 14;
    self.aiLoadingHUD.clipsToBounds = YES;
    self.aiLoadingHUD.layer.borderWidth = 0.8;
    self.aiLoadingHUD.layer.borderColor = [[UIColor systemPurpleColor] colorWithAlphaComponent:0.3].CGColor;
    self.aiLoadingHUD.userInteractionEnabled = NO;
    self.aiLoadingHUD.hidden = YES;
    self.aiLoadingHUD.alpha = 0.0;
    [self.view addSubview:self.aiLoadingHUD];
    
    UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    spinner.color = [UIColor systemPurpleColor];
    spinner.transform = CGAffineTransformMakeScale(0.65, 0.65);
    spinner.translatesAutoresizingMaskIntoConstraints = NO;
    [spinner startAnimating];
    [self.aiLoadingHUD.contentView addSubview:spinner];
    
    UILabel *loadingLabel = [[UILabel alloc] init];
    loadingLabel.text = L(@"AI Readying...", @"本地模型静默预热中...");
    loadingLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
    loadingLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.9];
    loadingLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.aiLoadingHUD.contentView addSubview:loadingLabel];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.aiLoadingHUD.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:8],
        [self.aiLoadingHUD.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.aiLoadingHUD.heightAnchor constraintEqualToConstant:28],
        
        [spinner.leadingAnchor constraintEqualToAnchor:self.aiLoadingHUD.contentView.leadingAnchor constant:10],
        [spinner.centerYAnchor constraintEqualToAnchor:self.aiLoadingHUD.contentView.centerYAnchor],
        
        [loadingLabel.leadingAnchor constraintEqualToAnchor:spinner.trailingAnchor constant:6],
        [loadingLabel.trailingAnchor constraintEqualToAnchor:self.aiLoadingHUD.contentView.trailingAnchor constant:-12],
        [loadingLabel.centerYAnchor constraintEqualToAnchor:self.aiLoadingHUD.contentView.centerYAnchor]
    ]];
}

- (void)dismissAILoadingHUD {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(dismissAILoadingHUD) object:nil];
    if (self.aiLoadingHUD.hidden || self.aiLoadingHUD.alpha == 0.0) {
        self.aiLoadingHUD.hidden = YES;
        return;
    }
    [UIView animateWithDuration:0.3 animations:^{
        self.aiLoadingHUD.alpha = 0.0;
    } completion:^(BOOL finished) {
        self.aiLoadingHUD.hidden = YES;
    }];
}

- (void)handleLLMPrewarmingStarted:(NSNotification *)note {
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(dismissAILoadingHUD) object:nil];
        self.aiLoadingHUD.hidden = NO;
        self.aiLoadingHUD.alpha = 0.0;
        [UIView animateWithDuration:0.25 animations:^{
            self.aiLoadingHUD.alpha = 1.0;
        }];
        // 🏆 1.5 秒安全自动关闭兜底：无论底层通知是否丢失，1.5 秒后无条件自动渐隐退出，绝不阻断用户交互
        [self performSelector:@selector(dismissAILoadingHUD) withObject:nil afterDelay:1.5];
    });
}

- (void)handleLLMPrewarmingFinished:(NSNotification *)note {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self dismissAILoadingHUD];
    });
}

- (void)dealloc {
    [[HSBAppleTVDiscovery shared] stopScanning];
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(dismissAILoadingHUD) object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
