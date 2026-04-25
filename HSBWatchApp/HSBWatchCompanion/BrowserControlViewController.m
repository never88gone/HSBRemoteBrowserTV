//
//  BrowserControlViewController.m
//  HSBWatchCompanion
//

#import "BrowserControlViewController.h"
#import <UIKit/UIKit.h>
#import <UIKit/UIGestureRecognizerSubclass.h>

// 自定义四指拖动手势识别器
// 与 UIPanGestureRecognizer 不同：四指按下时即刻进入 Began，无需等待移动
@interface FourFingerDragGestureRecognizer : UIGestureRecognizer
@property (nonatomic, assign) CGPoint lastCenter; // 上一帧的触控中心点
@property (nonatomic, assign) CGPoint currentDelta; // 当前帧增量
@end

@implementation FourFingerDragGestureRecognizer

- (CGPoint)centerOfTouches:(NSSet<UITouch *> *)touches inView:(UIView *)view {
    CGFloat x = 0, y = 0;
    for (UITouch *t in touches) {
        CGPoint p = [t locationInView:view];
        x += p.x;
        y += p.y;
    }
    return CGPointMake(x / touches.count, y / touches.count);
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    NSUInteger total = event.allTouches.count;
    if (total == 4) {
        // 四指全部按下：立刻进入 Began
        self.lastCenter = [self centerOfTouches:event.allTouches inView:self.view];
        self.currentDelta = CGPointZero;
        self.state = UIGestureRecognizerStateBegan;
    } else if (total > 4) {
        self.state = UIGestureRecognizerStateFailed;
    }
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (self.state != UIGestureRecognizerStateBegan &&
        self.state != UIGestureRecognizerStateChanged) return;
    CGPoint newCenter = [self centerOfTouches:event.allTouches inView:self.view];
    self.currentDelta = CGPointMake(newCenter.x - self.lastCenter.x,
                                    newCenter.y - self.lastCenter.y);
    self.lastCenter = newCenter;
    self.state = UIGestureRecognizerStateChanged;
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (self.state == UIGestureRecognizerStateBegan ||
        self.state == UIGestureRecognizerStateChanged) {
        // 任一手指抬起即结束
        self.state = UIGestureRecognizerStateEnded;
    }
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    self.state = UIGestureRecognizerStateCancelled;
}

@end

static NSString * L(NSString *en, NSString *zh) {
    NSString *language = [[NSLocale preferredLanguages] firstObject];
    if ([language hasPrefix:@"zh"]) {
        return zh ?: en;
    }
    return en;
}

@interface BrowserControlViewController () <UIGestureRecognizerDelegate, UITextFieldDelegate>

@property (nonatomic, strong) UIView *trackpadView;
@property (nonatomic, strong) UILabel *trackpadStatusLabel; // 当前操作状态提示
@property (nonatomic, strong) UITextField *urlTextField; // URL 输入框

// 节流处理
@property (nonatomic, assign) CFTimeInterval lastPanSendTime;  // 单指滑动节流
@property (nonatomic, assign) CFTimeInterval lastScrollSendTime; // 双指滚动节流
@property (nonatomic, assign) BOOL isDragging; // Drag visual state

@end

@implementation BrowserControlViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    self.title = L(@"Fullscreen Trackpad", @"全屏触控板");
    
    [self setupUI];
}

- (void)setupUI {
    
    // Header View to dismiss
    UIView *headerView = [[UIView alloc] init];
    headerView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:headerView];
    
    // Drag Handle Indicator
    UIView *handleIndicator = [[UIView alloc] init];
    handleIndicator.backgroundColor = [UIColor quaternarySystemFillColor];
    handleIndicator.layer.cornerRadius = 3;
    handleIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    [headerView addSubview:handleIndicator];
    
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = L(@"BROWSER CONTROLS", @"网页浏览器控制");
    titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightBold];
    titleLabel.textColor = [UIColor secondaryLabelColor];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [headerView addSubview:titleLabel];
    
    // Close button
    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [closeBtn setImage:[UIImage systemImageNamed:@"xmark.circle.fill" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:24]] forState:UIControlStateNormal];
    closeBtn.tintColor = [UIColor tertiaryLabelColor];
    [closeBtn addTarget:self action:@selector(dismissAction) forControlEvents:UIControlEventTouchUpInside];
    closeBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [headerView addSubview:closeBtn];
    
    // Large Trackpad View
    self.trackpadView = [[UIView alloc] init];
    self.trackpadView.backgroundColor = [UIColor secondarySystemBackgroundColor];
    self.trackpadView.layer.cornerRadius = 24;
    self.trackpadView.layer.borderWidth = 1;
    self.trackpadView.layer.borderColor = [UIColor separatorColor].CGColor;
    self.trackpadView.translatesAutoresizingMaskIntoConstraints = NO;
    
    // 阴影
    self.trackpadView.layer.shadowColor = [UIColor blackColor].CGColor;
    self.trackpadView.layer.shadowOpacity = 0.05;
    self.trackpadView.layer.shadowOffset = CGSizeMake(0, 4);
    self.trackpadView.layer.shadowRadius = 8;
    
    UILabel *trackpadHint = [[UILabel alloc] init];
    trackpadHint.text = L(@"1-Finger: Move | 2-Fingers: Scroll/Tap | 3-Tap: Force Click | 4-Fingers: Drag",
                          @"单指移动 · 双指滚动/触控点击 · 三指强力点击 · 四指拖动");
    trackpadHint.numberOfLines = 0;
    trackpadHint.textAlignment = NSTextAlignmentCenter;
    trackpadHint.textColor = [[UIColor secondaryLabelColor] colorWithAlphaComponent:0.5];
    trackpadHint.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    trackpadHint.translatesAutoresizingMaskIntoConstraints = NO;
    
    // 当前状态动态标签
    self.trackpadStatusLabel = [[UILabel alloc] init];
    self.trackpadStatusLabel.text = L(@"Ready", @"就绪");
    self.trackpadStatusLabel.textAlignment = NSTextAlignmentCenter;
    self.trackpadStatusLabel.textColor = [[UIColor secondaryLabelColor] colorWithAlphaComponent:0.4];
    self.trackpadStatusLabel.font = [UIFont systemFontOfSize:42 weight:UIFontWeightUltraLight];
    self.trackpadStatusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    
    [self.view addSubview:self.trackpadView];
    [self.trackpadView addSubview:trackpadHint];
    [self.trackpadView addSubview:self.trackpadStatusLabel];
    
    // Gestures Setup
    UITapGestureRecognizer *tripleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTrackpadTripleTap:)];
    tripleTap.numberOfTouchesRequired = 3;
    [self.trackpadView addGestureRecognizer:tripleTap];
    
    // 双指单击 → WebViewOpTypeTouch(3) 点击
    UITapGestureRecognizer *doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTrackpadDoubleTap:)];
    doubleTap.numberOfTouchesRequired = 2;
    [doubleTap requireGestureRecognizerToFail:tripleTap];
    [self.trackpadView addGestureRecognizer:doubleTap];
    
    UITapGestureRecognizer *singleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTrackpadSingleTap:)];
    singleTap.numberOfTouchesRequired = 1;
    [singleTap requireGestureRecognizerToFail:doubleTap];
    [singleTap requireGestureRecognizerToFail:tripleTap];
    [self.trackpadView addGestureRecognizer:singleTap];
    
    UIPanGestureRecognizer *singlePan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleTrackpadSinglePan:)];
    singlePan.minimumNumberOfTouches = 1;
    singlePan.maximumNumberOfTouches = 1;
    singlePan.delegate = self;
    [self.trackpadView addGestureRecognizer:singlePan];
    
    UIPanGestureRecognizer *doublePan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleTrackpadDoublePan:)];
    doublePan.minimumNumberOfTouches = 2;
    doublePan.maximumNumberOfTouches = 2;
    // 双指滑动优先于双指单击，双指点击要求双指pan失败才触发（实际上pan不会失败，点击/滑动靠距离阈值区分）
    [self.trackpadView addGestureRecognizer:doublePan];
    
    FourFingerDragGestureRecognizer *fourFingerDrag = [[FourFingerDragGestureRecognizer alloc] initWithTarget:self action:@selector(handleTrackpadFourFingerDrag:)];
    [self.trackpadView addGestureRecognizer:fourFingerDrag];
    
    // URL Input Bar
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
    
    // Toolbar buttons
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
        [headerView.heightAnchor constraintEqualToConstant:60],
        
        [handleIndicator.topAnchor constraintEqualToAnchor:headerView.topAnchor constant:4],
        [handleIndicator.centerXAnchor constraintEqualToAnchor:headerView.centerXAnchor],
        [handleIndicator.widthAnchor constraintEqualToConstant:40],
        [handleIndicator.heightAnchor constraintEqualToConstant:6],
        
        [titleLabel.centerYAnchor constraintEqualToAnchor:headerView.centerYAnchor constant:4],
        [titleLabel.centerXAnchor constraintEqualToAnchor:headerView.centerXAnchor],
        
        [closeBtn.centerYAnchor constraintEqualToAnchor:headerView.centerYAnchor constant:4],
        [closeBtn.trailingAnchor constraintEqualToAnchor:headerView.trailingAnchor constant:-20],
        
        // Trackpad
        [self.trackpadView.topAnchor constraintEqualToAnchor:headerView.bottomAnchor constant:10],
        [self.trackpadView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [self.trackpadView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        [self.trackpadView.bottomAnchor constraintEqualToAnchor:urlBarContainer.topAnchor constant:-12],
        
        // Trackpad hints
        [trackpadHint.bottomAnchor constraintEqualToAnchor:self.trackpadView.bottomAnchor constant:-20],
        [trackpadHint.leadingAnchor constraintEqualToAnchor:self.trackpadView.leadingAnchor constant:20],
        [trackpadHint.trailingAnchor constraintEqualToAnchor:self.trackpadView.trailingAnchor constant:-20],
        
        [self.trackpadStatusLabel.centerXAnchor constraintEqualToAnchor:self.trackpadView.centerXAnchor],
        [self.trackpadStatusLabel.centerYAnchor constraintEqualToAnchor:self.trackpadView.centerYAnchor],
        
        // URL Bar
        [urlBarContainer.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [urlBarContainer.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        [urlBarContainer.bottomAnchor constraintEqualToAnchor:btnStack.topAnchor constant:-12],
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
        
        // Button stack
        [btnStack.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [btnStack.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        [btnStack.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-20],
        [btnStack.heightAnchor constraintEqualToConstant:60]
    ]];
}

- (void)dismissAction {
    [self dismissViewControllerAnimated:YES completion:nil];
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

#pragma mark - URL Input Actions

- (void)urlGoAction {
    NSString *urlString = [self.urlTextField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (urlString.length == 0) return;
    
    // 自动补全协议头
    if (![urlString.lowercaseString hasPrefix:@"http://"] && ![urlString.lowercaseString hasPrefix:@"https://"]) {
        urlString = [NSString stringWithFormat:@"https://%@", urlString];
    }
    
    UIImpactFeedbackGenerator *hap = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [hap impactOccurred];
    
    [self.urlTextField resignFirstResponder];
    [self sendDirectPayload:@{@"action": @"open_url", @"url": urlString}];
    
    self.trackpadStatusLabel.text = [NSString stringWithFormat:L(@"🌐 Navigating...", @"🌐 正在跳转...")];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (!self.isDragging) self.trackpadStatusLabel.text = L(@"Ready", @"就绪");
    });
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [self urlGoAction];
    return YES;
}

#pragma mark - Button Actions

- (void)browserActionBack {
    UIImpactFeedbackGenerator *hap = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [hap impactOccurred];
    [self sendActionToTV:@"page_back"];
}
- (void)browserActionForward {
    UIImpactFeedbackGenerator *hap = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [hap impactOccurred];
    [self sendActionToTV:@"page_forward"];
}
- (void)browserActionRefresh {
    UIImpactFeedbackGenerator *hap = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [hap impactOccurred];
    [self sendActionToTV:@"page_reload"];
}
- (void)browserActionHome {
    UIImpactFeedbackGenerator *hap = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [hap impactOccurred];
    [self sendActionToTV:@"page_home"];
}

#pragma mark - Gestures

- (void)handleTrackpadSingleTap:(UITapGestureRecognizer *)tap {
    if (tap.state == UIGestureRecognizerStateEnded) {
        if (self.checkConnectionBlock && !self.checkConnectionBlock()) { [self showTVNotConnectedError]; return; }
        
        UIImpactFeedbackGenerator *hap = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
        [hap impactOccurred];
        
        // 方弹动画点击反馈
        [UIView animateWithDuration:0.1 animations:^{ self.trackpadView.alpha = 0.5; }
                         completion:^(BOOL f) { [UIView animateWithDuration:0.15 animations:^{ self.trackpadView.alpha = 1.0; }]; }];
        
        self.trackpadStatusLabel.text = L(@"\U0001F5B1 Click", @"\U0001F5B1 点击");
        [self sendDirectPayload:@{@"action": @"mac_tap", @"mode": @1}];
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (!self.isDragging) self.trackpadStatusLabel.text = L(@"Ready", @"就绪");
        });
    }
}

- (void)handleTrackpadDoubleTap:(UITapGestureRecognizer *)tap {
    if (tap.state == UIGestureRecognizerStateEnded) {
        if (self.checkConnectionBlock && !self.checkConnectionBlock()) { [self showTVNotConnectedError]; return; }
        
        UIImpactFeedbackGenerator *hap = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
        [hap impactOccurred];
        
        [UIView animateWithDuration:0.08 animations:^{ self.trackpadView.alpha = 0.6; }
                         completion:^(BOOL f) { [UIView animateWithDuration:0.12 animations:^{ self.trackpadView.alpha = 1.0; }]; }];
        
        self.trackpadStatusLabel.text = L(@"\U0001F44C Touch Click", @"\U0001F44C 触控点击");
        [self sendDirectPayload:@{@"action": @"mac_tap", @"mode": @3}]; // 3 = WebViewOpTypeTouch
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (!self.isDragging) self.trackpadStatusLabel.text = L(@"Ready", @"就绪");
        });
    }
}

- (void)handleTrackpadTripleTap:(UITapGestureRecognizer *)tap {
    if (tap.state == UIGestureRecognizerStateEnded) {
        if (self.checkConnectionBlock && !self.checkConnectionBlock()) { [self showTVNotConnectedError]; return; }
        
        UIImpactFeedbackGenerator *hap = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleHeavy];
        [hap impactOccurred];
        
        self.trackpadStatusLabel.text = L(@"Force Click", @"强力点击");
        [self sendDirectPayload:@{@"action": @"mac_tap", @"mode": @5}]; // 5 = WebViewOpTypeForceClick
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (!self.isDragging) self.trackpadStatusLabel.text = L(@"Ready", @"就绪");
        });
    }
}

- (void)handleTrackpadSinglePan:(UIPanGestureRecognizer *)pan {
    if (self.checkConnectionBlock && !self.checkConnectionBlock()) return;
    if (pan.numberOfTouches != 1 && pan.state != UIGestureRecognizerStateEnded && pan.state != UIGestureRecognizerStateCancelled) return;
    if (self.isDragging) return;
    
    if (pan.state == UIGestureRecognizerStateBegan) {
        // 重置translation，以便后续用增量计算
        [pan setTranslation:CGPointZero inView:self.trackpadView];
        return;
    }
    
    CFTimeInterval now = CACurrentMediaTime();
    if (now - self.lastPanSendTime < 0.016) { return; } // ~60fps
    self.lastPanSendTime = now;
    
    if (pan.state == UIGestureRecognizerStateChanged) {
        // 使用 translation 增量：更精准，不受速度衰减影响
        // tvOS 分辨率 1920x1080，iPhone trackpad 约 350pt 宽
        // 映射倍率 ≈ 1920/350 ≈ 5.5，让 1pt 手指移动 ≈ 5.5pt 光标移动
        static const CGFloat kPanScale = 5.5;
        CGPoint translation = [pan translationInView:self.trackpadView];
        CGFloat dx = translation.x * kPanScale;
        CGFloat dy = translation.y * kPanScale;
        [pan setTranslation:CGPointZero inView:self.trackpadView];
        
        if (fabs(dx) > 0.1 || fabs(dy) > 0.1) {
            [self sendDirectPayload:@{@"action": @"mac_pan", @"dx": @(dx), @"dy": @(dy)}];
            self.trackpadStatusLabel.text = L(@"Moving", @"移动");
        }
    } else if (pan.state == UIGestureRecognizerStateEnded || pan.state == UIGestureRecognizerStateCancelled) {
        if (!self.isDragging) self.trackpadStatusLabel.text = L(@"Ready", @"就绪");
    }
}

- (void)handleTrackpadDoublePan:(UIPanGestureRecognizer *)pan {
    if (self.checkConnectionBlock && !self.checkConnectionBlock()) return;
    
    if (pan.state == UIGestureRecognizerStateBegan) {
        [pan setTranslation:CGPointZero inView:self.trackpadView];
        self.trackpadStatusLabel.text = L(@"Scrolling", @"滚动");
        return;
    }
    
    CFTimeInterval now = CACurrentMediaTime();
    if (now - self.lastScrollSendTime < 0.025) { return; } // ~40fps，兼顾流畅与网络压力
    self.lastScrollSendTime = now;
    
    if (pan.state == UIGestureRecognizerStateChanged) {
        // 使用 translation 增量驱动滚动
        // tvOS 滚动：负值向上，正值向下（自然方向取反）
        // 倍率 3.0 ≈ 适合大屏幕滚动幅度
        static const CGFloat kScrollScale = 3.0;
        CGPoint translation = [pan translationInView:self.trackpadView];
        CGFloat dx = translation.x * kScrollScale;
        CGFloat dy = translation.y * kScrollScale;
        [pan setTranslation:CGPointZero inView:self.trackpadView];
        
        [self sendDirectPayload:@{@"action": @"mac_scroll", @"dx": @(dx), @"dy": @(dy)}];
    } else if (pan.state == UIGestureRecognizerStateEnded || pan.state == UIGestureRecognizerStateCancelled) {
        if (!self.isDragging) self.trackpadStatusLabel.text = L(@"Ready", @"就绪");
    }
}

- (void)handleTrackpadFourFingerDrag:(FourFingerDragGestureRecognizer *)pan {
    if (self.checkConnectionBlock && !self.checkConnectionBlock()) return;
    
    if (pan.state == UIGestureRecognizerStateBegan) {
        // 四指按下即刻触发（无需等待移动）
        self.isDragging = YES;
        self.trackpadStatusLabel.text = L(@"Dragging", @"拖动中");
        self.trackpadView.layer.borderColor = [UIColor systemBlueColor].CGColor;
        self.trackpadView.layer.borderWidth = 2.0;
        
        UIImpactFeedbackGenerator *hap = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleHeavy];
        [hap impactOccurred];
        
        [self sendDirectPayload:@{@"action": @"mac_drag", @"state": @"began"}];
        
    } else if (pan.state == UIGestureRecognizerStateChanged) {
        CFTimeInterval now = CACurrentMediaTime();
        if (now - self.lastPanSendTime < 0.016) { return; }
        self.lastPanSendTime = now;
        
        // 四指中心点移动增量 × 5.5，与单指移动保持一致的 tvOS 坐标映射
        static const CGFloat kDragScale = 5.5;
        CGFloat dx = pan.currentDelta.x * kDragScale;
        CGFloat dy = pan.currentDelta.y * kDragScale;
        
        if (fabs(dx) > 0.1 || fabs(dy) > 0.1) {
            [self sendDirectPayload:@{@"action": @"mac_drag", @"state": @"changed", @"dx": @(dx), @"dy": @(dy)}];
        }
        
    } else if (pan.state == UIGestureRecognizerStateEnded || pan.state == UIGestureRecognizerStateCancelled) {
        // 任一手指抬起即结束
        self.isDragging = NO;
        self.trackpadStatusLabel.text = L(@"Ready", @"就绪");
        self.trackpadView.layer.borderColor = [UIColor separatorColor].CGColor;
        self.trackpadView.layer.borderWidth = 1.0;
        
        UIImpactFeedbackGenerator *hap = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleHeavy];
        [hap impactOccurred];
        
        [self sendDirectPayload:@{@"action": @"mac_drag", @"state": @"ended"}];
    }
}

// 确保多个手势不冲突，仅单指可以与其他并存，但代码里已经通过 touches 数量做了隔离
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return NO;
}

@end
