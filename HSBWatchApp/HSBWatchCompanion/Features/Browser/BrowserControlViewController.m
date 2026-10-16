//
//  BrowserControlViewController.m
//  HSBWatchCompanion
//

#import "BrowserControlViewController.h"
#import "HSBBrowserScriptsBarView.h"
#import "HSBBrowserVideoControlPanel.h"
#import "HSBBrowserTouchpadView.h"
#import "HSBBrowserSpeechAssistant.h"
#import "HSBWatchCompanion-Swift.h"
#import "HSBTVOSConnectionConstants.h"

static NSString * L(NSString *en, NSString *zh) {
    NSString *language = [[NSLocale preferredLanguages] firstObject];
    if ([language hasPrefix:@"zh"]) {
        return zh ?: en;
    }
    return en;
}

@interface BrowserControlViewController () <UITextFieldDelegate>

@property (nonatomic, strong) HSBBrowserScriptsBarView *scriptsBarView;
@property (nonatomic, strong) HSBBrowserTouchpadView *touchpadView;
@property (nonatomic, strong) HSBBrowserVideoControlPanel *videoControlPanel;
@property (nonatomic, strong) HSBBrowserSpeechAssistant *speechAssistant;
@property (nonatomic, strong) UITextField *urlTextField;

@end

@implementation BrowserControlViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor clearColor];
    self.title = L(@"Fullscreen Trackpad", @"全屏触控板");
    
    [self setupUI];
    [self setupSpeechAssistant];
}

- (void)setupUI {
    // 1. Header View to dismiss
    UIView *headerView = [[UIView alloc] init];
    headerView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:headerView];
    
    UIView *handleIndicator = [[UIView alloc] init];
    handleIndicator.backgroundColor = [UIColor quaternarySystemFillColor];
    handleIndicator.layer.cornerRadius = 3;
    handleIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    [headerView addSubview:handleIndicator];

    // 2. JS Scripts Horizontal Bar
    self.scriptsBarView = [[HSBBrowserScriptsBarView alloc] init];
    self.scriptsBarView.translatesAutoresizingMaskIntoConstraints = NO;
    __weak typeof(self) weakSelf = self;
    self.scriptsBarView.onExecuteScript = ^(NSString *scriptName, NSString *jsContent) {
        [weakSelf.touchpadView setStatusText:[NSString stringWithFormat:@"🚀 Running %@...", scriptName]];
        NSDictionary *payload = @{
            HSBRemotePayloadKeyAction: HSBRemoteSimulateActionExecuteJS,
            HSBRemotePayloadKeyContent: jsContent,
            HSBRemotePayloadKeyScript: jsContent,
            HSBRemotePayloadKeyTimestamp: @([[NSDate date] timeIntervalSince1970]),
            HSBRemotePayloadKeyRequestId: [[NSUUID UUID] UUIDString]
        };
        [weakSelf sendDirectPayload:payload];
        [weakSelf.touchpadView setStatusText:L(@"Ready", @"就绪") restoreReadyAfter:1.5];
    };
    [self.view addSubview:self.scriptsBarView];

    // 3. Touchpad View
    self.touchpadView = [[HSBBrowserTouchpadView alloc] init];
    self.touchpadView.translatesAutoresizingMaskIntoConstraints = NO;
    self.touchpadView.checkConnection = ^BOOL{
        if (weakSelf.checkConnectionBlock && !weakSelf.checkConnectionBlock()) {
            [weakSelf showTVNotConnectedError];
            return NO;
        }
        return YES;
    };
    self.touchpadView.onPan = ^(CGFloat dx, CGFloat dy) {
        [weakSelf sendDirectPayload:@{
            HSBRemotePayloadKeyAction: HSBRemoteSimulateActionMacPan,
            HSBRemotePayloadKeyDx: @(dx),
            HSBRemotePayloadKeyDy: @(dy)
        }];
    };
    self.touchpadView.onScroll = ^(CGFloat dx, CGFloat dy) {
        [weakSelf sendDirectPayload:@{
            HSBRemotePayloadKeyAction: HSBRemoteSimulateActionMacScroll,
            HSBRemotePayloadKeyDx: @(dx),
            HSBRemotePayloadKeyDy: @(dy)
        }];
    };
    self.touchpadView.onTap = ^(NSInteger mode) {
        [weakSelf sendDirectPayload:@{
            HSBRemotePayloadKeyAction: HSBRemoteSimulateActionMacTap,
            HSBRemotePayloadKeyMode: @(mode)
        }];
    };
    self.touchpadView.onDrag = ^(NSString *state, CGFloat dx, CGFloat dy) {
        NSMutableDictionary *dict = [@{
            HSBRemotePayloadKeyAction: HSBRemoteSimulateActionMacDrag,
            HSBRemotePayloadKeyState: state
        } mutableCopy];
        if (fabs(dx) > 0.01 || fabs(dy) > 0.01) {
            dict[HSBRemotePayloadKeyDx] = @(dx);
            dict[HSBRemotePayloadKeyDy] = @(dy);
        }
        [weakSelf sendDirectPayload:dict];
    };
    self.touchpadView.onCancelAI = ^{
        [weakSelf.speechAssistant cancelCurrentAIInference];
    };
    [self.view addSubview:self.touchpadView];

    // 4. URL Input Bar
    UIView *urlBarContainer = [[UIView alloc] init];
    urlBarContainer.backgroundColor = [UIColor tertiarySystemBackgroundColor];
    urlBarContainer.layer.cornerRadius = 12;
    urlBarContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:urlBarContainer];
    
    UIImageView *urlIcon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"globe" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:16 weight:UIImageSymbolWeightMedium]]];
    urlIcon.tintColor = [UIColor secondaryLabelColor];
    urlIcon.translatesAutoresizingMaskIntoConstraints = NO;
    [urlBarContainer addSubview:urlIcon];
    
    self.urlTextField = [[UITextField alloc] init];
    self.urlTextField.placeholder = L(@"Enter URL to navigate...", @"输入网址跳转...");
    self.urlTextField.font = [UIFont systemFontOfSize:15 weight:UIFontWeightRegular];
    self.urlTextField.textColor = [UIColor labelColor];
    self.urlTextField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.urlTextField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.urlTextField.spellCheckingType = UITextSpellCheckingTypeNo;
    self.urlTextField.keyboardType = UIKeyboardTypeURL;
    self.urlTextField.returnKeyType = UIReturnKeyGo;
    self.urlTextField.clearButtonMode = UITextFieldViewModeWhileEditing;
    self.urlTextField.delegate = self;
    self.urlTextField.translatesAutoresizingMaskIntoConstraints = NO;
    [urlBarContainer addSubview:self.urlTextField];
    
    UIButton *goBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [goBtn setImage:[UIImage systemImageNamed:@"arrow.right.circle.fill" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:28 weight:UIImageSymbolWeightMedium]] forState:UIControlStateNormal];
    goBtn.tintColor = [UIColor systemBlueColor];
    [goBtn addTarget:self action:@selector(urlGoAction) forControlEvents:UIControlEventTouchUpInside];
    goBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [urlBarContainer addSubview:goBtn];

    // 5. Video Control Panel
    self.videoControlPanel = [[HSBBrowserVideoControlPanel alloc] init];
    self.videoControlPanel.translatesAutoresizingMaskIntoConstraints = NO;
    self.videoControlPanel.onOpenPlayer = ^{
        [weakSelf.touchpadView setStatusText:L(@"▶️ Opening Player...", @"▶️ 正在打开播放器...")];
        [weakSelf sendDirectPayload:@{HSBRemotePayloadKeyAction: HSBRemoteSimulateActionOpenPlayer}];
        [weakSelf.touchpadView setStatusText:L(@"Ready", @"就绪") restoreReadyAfter:1.5];
    };
    self.videoControlPanel.onClosePlayer = ^{
        [weakSelf.touchpadView setStatusText:L(@"⏹️ Closing Player...", @"⏹️ 正在关闭播放器...")];
        [weakSelf sendDirectPayload:@{HSBRemotePayloadKeyAction: HSBRemoteSimulateActionClosePlayer}];
        [weakSelf.touchpadView setStatusText:L(@"Ready", @"就绪") restoreReadyAfter:1.5];
    };
    self.videoControlPanel.onSeekPercent = ^(CGFloat percent) {
        [weakSelf sendDirectPayload:@{
            HSBRemotePayloadKeyAction: HSBRemoteSimulateActionSeekPercent,
            HSBRemotePayloadKeyValue: @(percent)
        }];
    };
    [self.view addSubview:self.videoControlPanel];

    // 6. Navigation Buttons Toolbar
    UIButton *backBtn = [self createBrowserButtonWithSystemIcon:@"chevron.left" action:@selector(browserActionBack)];
    UIButton *forwardBtn = [self createBrowserButtonWithSystemIcon:@"chevron.right" action:@selector(browserActionForward)];
    UIButton *refreshBtn = [self createBrowserButtonWithSystemIcon:@"arrow.clockwise" action:@selector(browserActionRefresh)];
    UIButton *homeBtn = [self createBrowserButtonWithSystemIcon:@"house" action:@selector(browserActionHome)];
    
    UIButton *editHomeBtn = [self createBrowserButtonWithSystemIcon:@"square.and.pencil" action:@selector(browserActionEditHome)];
    editHomeBtn.tintColor = [UIColor systemOrangeColor];
    
    UIStackView *btnStack = [[UIStackView alloc] initWithArrangedSubviews:@[backBtn, forwardBtn, refreshBtn, homeBtn, editHomeBtn]];
    btnStack.axis = UILayoutConstraintAxisHorizontal;
    btnStack.distribution = UIStackViewDistributionFillEqually;
    btnStack.spacing = 10;
    btnStack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:btnStack];

    [NSLayoutConstraint activateConstraints:@[
        // Header
        [headerView.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:10],
        [headerView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [headerView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [headerView.heightAnchor constraintEqualToConstant:20],
        
        [handleIndicator.topAnchor constraintEqualToAnchor:headerView.topAnchor constant:4],
        [handleIndicator.centerXAnchor constraintEqualToAnchor:headerView.centerXAnchor],
        [handleIndicator.widthAnchor constraintEqualToConstant:40],
        [handleIndicator.heightAnchor constraintEqualToConstant:6],
        
        // Scripts
        [self.scriptsBarView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:8],
        [self.scriptsBarView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scriptsBarView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.scriptsBarView.heightAnchor constraintEqualToConstant:36],
        
        // Trackpad
        [self.touchpadView.topAnchor constraintEqualToAnchor:self.scriptsBarView.bottomAnchor constant:12],
        [self.touchpadView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [self.touchpadView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        [self.touchpadView.bottomAnchor constraintEqualToAnchor:urlBarContainer.topAnchor constant:-12],
        
        // URL Bar
        [urlBarContainer.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [urlBarContainer.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        [urlBarContainer.bottomAnchor constraintEqualToAnchor:self.videoControlPanel.topAnchor constant:-16],
        [urlBarContainer.heightAnchor constraintEqualToConstant:48],
        
        [urlIcon.leadingAnchor constraintEqualToAnchor:urlBarContainer.leadingAnchor constant:14],
        [urlIcon.centerYAnchor constraintEqualToAnchor:urlBarContainer.centerYAnchor],
        [urlIcon.widthAnchor constraintEqualToConstant:20],
        [urlIcon.heightAnchor constraintEqualToConstant:20],
        
        [self.urlTextField.leadingAnchor constraintEqualToAnchor:urlIcon.trailingAnchor constant:10],
        [self.urlTextField.trailingAnchor constraintEqualToAnchor:goBtn.leadingAnchor constant:-8],
        [self.urlTextField.centerYAnchor constraintEqualToAnchor:urlBarContainer.centerYAnchor],
        
        [goBtn.trailingAnchor constraintEqualToAnchor:urlBarContainer.trailingAnchor constant:-10],
        [goBtn.centerYAnchor constraintEqualToAnchor:urlBarContainer.centerYAnchor],
        [goBtn.widthAnchor constraintEqualToConstant:32],
        [goBtn.heightAnchor constraintEqualToConstant:32],
        
        // Video Panel
        [self.videoControlPanel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [self.videoControlPanel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        [self.videoControlPanel.bottomAnchor constraintEqualToAnchor:btnStack.topAnchor constant:-16],
        
        // Button Stack
        [btnStack.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [btnStack.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        [btnStack.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-20],
        [btnStack.heightAnchor constraintEqualToConstant:60]
    ]];
}

- (void)setupSpeechAssistant {
    self.speechAssistant = [[HSBBrowserSpeechAssistant alloc] initWithContainerView:self.view];
    __weak typeof(self) weakSelf = self;
    self.speechAssistant.onSendAction = ^(NSString *action) {
        [weakSelf sendActionToTV:action];
    };
    self.speechAssistant.onSendPayload = ^(NSDictionary *payload) {
        [weakSelf sendDirectPayload:payload];
    };
    self.speechAssistant.onStatusUpdate = ^(NSString *statusText, BOOL showCancelButton) {
        [weakSelf.touchpadView setStatusText:statusText];
        [weakSelf.touchpadView setAICancelButtonHidden:!showCancelButton];
    };
    self.speechAssistant.onShowToast = ^(NSString *message) {
        [weakSelf showToast:message];
    };
    self.speechAssistant.onPresentAlert = ^(UIAlertController *alert) {
        [weakSelf presentViewController:alert animated:YES completion:nil];
    };
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.speechAssistant stopAudioIfRunning];
}

#pragma mark - URL & Toolbar Actions

- (void)urlGoAction {
    NSString *urlString = [self.urlTextField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (urlString.length == 0) return;
    
    if (![urlString.lowercaseString hasPrefix:@"http://"] && ![urlString.lowercaseString hasPrefix:@"https://"]) {
        urlString = [NSString stringWithFormat:@"https://%@", urlString];
    }
    
    UIImpactFeedbackGenerator *hap = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [hap impactOccurred];
    
    [self.urlTextField resignFirstResponder];
    [self sendDirectPayload:@{HSBRemotePayloadKeyAction: HSBRemoteSimulateActionOpenUrl, HSBRemotePayloadKeyUrl: urlString}];
    
    [self.touchpadView setStatusText:L(@"🌐 Navigating...", @"🌐 正在跳转...") restoreReadyAfter:2.0];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [self urlGoAction];
    return YES;
}

- (void)browserActionBack {
    UIImpactFeedbackGenerator *hap = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [hap impactOccurred];
    [self sendDirectPayload:@{HSBRemotePayloadKeyAction: HSBRemoteSimulateActionPageBack}];
}

- (void)browserActionForward {
    UIImpactFeedbackGenerator *hap = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [hap impactOccurred];
    [self sendDirectPayload:@{HSBRemotePayloadKeyAction: HSBRemoteSimulateActionPageForward}];
}

- (void)browserActionRefresh {
    UIImpactFeedbackGenerator *hap = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [hap impactOccurred];
    [self sendDirectPayload:@{HSBRemotePayloadKeyAction: HSBRemoteSimulateActionPageReload}];
}

- (void)browserActionHome {
    UIImpactFeedbackGenerator *hap = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [hap impactOccurred];
    [self sendDirectPayload:@{HSBRemotePayloadKeyAction: HSBRemoteSimulateActionPageHome}];
}

- (void)browserActionEditHome {
    if (self.editHomeBlock) {
        self.editHomeBlock();
    }
}

- (UIButton *)createBrowserButtonWithSystemIcon:(NSString *)iconName action:(SEL)action {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    UIImage *img = [UIImage systemImageNamed:iconName withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:24 weight:UIImageSymbolWeightMedium]];
    [btn setImage:img forState:UIControlStateNormal];
    btn.backgroundColor = [UIColor tertiarySystemBackgroundColor];
    btn.layer.cornerRadius = 16;
    btn.tintColor = [UIColor labelColor];
    
    btn.layer.shadowColor = [UIColor blackColor].CGColor;
    btn.layer.shadowOpacity = 0.05;
    btn.layer.shadowOffset = CGSizeMake(0, 2);
    btn.layer.shadowRadius = 4;
    
    [btn addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return btn;
}

- (void)showTVNotConnectedError {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:L(@"TV Not Connected", @"未连接到电视")
                                                                   message:L(@"Please ensure you are connected to the Apple TV.", @"请先连接到 Apple TV 后再使用手势控制。")
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)sendActionToTV:(NSString *)action {
    if (self.checkConnectionBlock && !self.checkConnectionBlock()) {
        [self showTVNotConnectedError];
        return;
    }
    if (self.sendActionBlock) {
        self.sendActionBlock(action);
    }
}

- (void)sendDirectPayload:(NSDictionary *)payload {
    if (self.checkConnectionBlock && !self.checkConnectionBlock()) {
        [self showTVNotConnectedError];
        return;
    }
    if (self.sendPayloadBlock) {
        self.sendPayloadBlock(payload);
    }
}

- (void)showToast:(NSString *)msg {
    UILabel *toast = [[UILabel alloc] init];
    toast.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.75];
    toast.textColor = [UIColor whiteColor];
    toast.textAlignment = NSTextAlignmentCenter;
    toast.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    toast.text = msg;
    toast.layer.cornerRadius = 20;
    toast.clipsToBounds = YES;
    toast.alpha = 0;
    toast.translatesAutoresizingMaskIntoConstraints = NO;
    
    [self.view addSubview:toast];
    [NSLayoutConstraint activateConstraints:@[
        [toast.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [toast.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-160],
        [toast.widthAnchor constraintGreaterThanOrEqualToConstant:200],
        [toast.heightAnchor constraintEqualToConstant:40]
    ]];
    
    [UIView animateWithDuration:0.3 animations:^{
        toast.alpha = 1;
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.3 delay:1.5 options:0 animations:^{
            toast.alpha = 0;
        } completion:^(BOOL finished) {
            [toast removeFromSuperview];
        }];
    }];
}

- (void)applyThemeStyle {
    [super applyThemeStyle];
    [self.scriptsBarView applyThemeStyle];
    [self.videoControlPanel applyThemeStyle];
}

@end
