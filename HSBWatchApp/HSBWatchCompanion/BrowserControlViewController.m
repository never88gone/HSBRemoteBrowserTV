//
//  BrowserControlViewController.m
//  HSBWatchCompanion
//

#import "BrowserControlViewController.h"
#import <UIKit/UIKit.h>
#import <UIKit/UIGestureRecognizerSubclass.h>
#import "HSBLocalLLMManager.h"


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

// 视频扩展控件
@property (nonatomic, strong) UIButton *openPlayerBtn;
@property (nonatomic, strong) UIButton *closePlayerBtn;
@property (nonatomic, strong) UISlider *videoSlider;
@property (nonatomic, strong) UILabel *videoPercentLabel;

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
    

    
    // AI Assistant Button
    UIButton *aiBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [aiBtn setImage:[UIImage systemImageNamed:@"sparkles" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:20]] forState:UIControlStateNormal];
    aiBtn.tintColor = [UIColor systemPurpleColor];
    [aiBtn addTarget:self action:@selector(aiAssistantAction) forControlEvents:UIControlEventTouchUpInside];
    aiBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [headerView addSubview:aiBtn];

    
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
    
    // Video Control Panel Stack
    UIStackView *videoPanel = [[UIStackView alloc] init];
    videoPanel.axis = UILayoutConstraintAxisVertical;
    videoPanel.spacing = 12;
    videoPanel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:videoPanel];
    
    // 1. Player Button Row (Open & Close in one row)
    UIStackView *playerBtnRow = [[UIStackView alloc] init];
    playerBtnRow.axis = UILayoutConstraintAxisHorizontal;
    playerBtnRow.distribution = UIStackViewDistributionFillEqually;
    playerBtnRow.spacing = 12;
    playerBtnRow.translatesAutoresizingMaskIntoConstraints = NO;
    [videoPanel addArrangedSubview:playerBtnRow];
    
    self.openPlayerBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    self.openPlayerBtn.backgroundColor = [[HSBThemeManager shared].currentPalette.primaryColor colorWithAlphaComponent:0.15];
    self.openPlayerBtn.layer.cornerRadius = 12;
    [self.openPlayerBtn setTitle:L(@"Open Video Player", @"打开播放器") forState:UIControlStateNormal];
    [self.openPlayerBtn setTitleColor:[HSBThemeManager shared].currentPalette.primaryColor forState:UIControlStateNormal];
    [self.openPlayerBtn setImage:[UIImage systemImageNamed:@"play.rectangle.fill" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:16 weight:UIImageSymbolWeightBold]] forState:UIControlStateNormal];
    self.openPlayerBtn.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightBold];
    self.openPlayerBtn.tintColor = [HSBThemeManager shared].currentPalette.primaryColor;
    
    self.openPlayerBtn.titleEdgeInsets = UIEdgeInsetsMake(0, 8, 0, 0);
    self.openPlayerBtn.imageEdgeInsets = UIEdgeInsetsMake(0, 0, 0, 8);
    self.openPlayerBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [self.openPlayerBtn.heightAnchor constraintEqualToConstant:46].active = YES;
    [self.openPlayerBtn addTarget:self action:@selector(openPlayerAction) forControlEvents:UIControlEventTouchUpInside];
    [playerBtnRow addArrangedSubview:self.openPlayerBtn];
    
    self.closePlayerBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    self.closePlayerBtn.backgroundColor = [[HSBThemeManager shared].currentPalette.primaryColor colorWithAlphaComponent:0.15];
    self.closePlayerBtn.layer.cornerRadius = 12;
    [self.closePlayerBtn setTitle:L(@"Close Player", @"关闭播放器") forState:UIControlStateNormal];
    [self.closePlayerBtn setTitleColor:[HSBThemeManager shared].currentPalette.primaryColor forState:UIControlStateNormal];
    [self.closePlayerBtn setImage:[UIImage systemImageNamed:@"xmark.rectangle.fill" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:16 weight:UIImageSymbolWeightBold]] forState:UIControlStateNormal];
    self.closePlayerBtn.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightBold];
    self.closePlayerBtn.tintColor = [HSBThemeManager shared].currentPalette.primaryColor;
    
    self.closePlayerBtn.titleEdgeInsets = UIEdgeInsetsMake(0, 8, 0, 0);
    self.closePlayerBtn.imageEdgeInsets = UIEdgeInsetsMake(0, 0, 0, 8);
    self.closePlayerBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [self.closePlayerBtn.heightAnchor constraintEqualToConstant:46].active = YES;
    [self.closePlayerBtn addTarget:self action:@selector(closePlayerAction) forControlEvents:UIControlEventTouchUpInside];
    [playerBtnRow addArrangedSubview:self.closePlayerBtn];
    
    // 2. Video Slider Row
    UIStackView *sliderRow = [[UIStackView alloc] init];
    sliderRow.axis = UILayoutConstraintAxisHorizontal;
    sliderRow.spacing = 10;
    sliderRow.alignment = UIStackViewAlignmentCenter;
    sliderRow.translatesAutoresizingMaskIntoConstraints = NO;
    
    UIImageView *sliderIcon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"video.fill" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightMedium]]];
    sliderIcon.tintColor = [UIColor secondaryLabelColor];
    sliderIcon.translatesAutoresizingMaskIntoConstraints = NO;
    [sliderIcon.widthAnchor constraintEqualToConstant:20].active = YES;
    [sliderIcon.heightAnchor constraintEqualToConstant:20].active = YES;
    [sliderRow addArrangedSubview:sliderIcon];
    
    self.videoSlider = [[UISlider alloc] init];
    self.videoSlider.minimumValue = 0.0;
    self.videoSlider.maximumValue = 1.0;
    self.videoSlider.value = 0.5;
    self.videoSlider.minimumTrackTintColor = [HSBThemeManager shared].currentPalette.primaryColor;
    [self.videoSlider addTarget:self action:@selector(videoSliderChanged:) forControlEvents:UIControlEventValueChanged];
    [self.videoSlider addTarget:self action:@selector(videoSliderEnded:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside];
    self.videoSlider.translatesAutoresizingMaskIntoConstraints = NO;
    [sliderRow addArrangedSubview:self.videoSlider];
    
    self.videoPercentLabel = [[UILabel alloc] init];
    self.videoPercentLabel.text = @"50%";
    self.videoPercentLabel.font = [UIFont monospacedDigitSystemFontOfSize:13 weight:UIFontWeightMedium];
    self.videoPercentLabel.textColor = [UIColor secondaryLabelColor];
    self.videoPercentLabel.textAlignment = NSTextAlignmentRight;
    self.videoPercentLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.videoPercentLabel.widthAnchor constraintEqualToConstant:40].active = YES;
    [sliderRow addArrangedSubview:self.videoPercentLabel];
    
    [videoPanel addArrangedSubview:sliderRow];
    
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
        

        
        [aiBtn.centerYAnchor constraintEqualToAnchor:headerView.centerYAnchor constant:4],
        [aiBtn.leadingAnchor constraintEqualToAnchor:headerView.leadingAnchor constant:20],

        
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
        [urlBarContainer.bottomAnchor constraintEqualToAnchor:videoPanel.topAnchor constant:-16],
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
        [videoPanel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [videoPanel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        [videoPanel.bottomAnchor constraintEqualToAnchor:btnStack.topAnchor constant:-16],
        
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

- (void)aiAssistantAction {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:L(@"AI Assistant", @"AI 助手")
                                                                   message:L(@"Describe what you want to do...", @"描述你想做的事情...")
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = L(@"e.g. Translate this page, or make background red", @"例如：翻译这段话，或让网页背景变红");
    }];
    
    [alert addAction:[UIAlertAction actionWithTitle:L(@"Translate", @"翻译") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        NSString *text = alert.textFields.firstObject.text;
        [self processAIRequest:text type:1];
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:L(@"Generate JS", @"生成 JS") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        NSString *text = alert.textFields.firstObject.text;
        [self processAIRequest:text type:2];
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:L(@"Cancel", @"取消") style:UIAlertActionStyleCancel handler:nil]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)processAIRequest:(NSString *)text type:(NSInteger)type {
    if (text.length == 0) return;
    
    self.trackpadStatusLabel.text = L(@"AI Thinking...", @"AI 思考中...");
    
    NSString *systemPrompt = @"";
    NSString *enhancedUserPrompt = @"";
    
    if (type == 1) { // 翻译
        systemPrompt = @"你是一个精准的翻译助手。只输出最终的翻译结果，不要任何多余的解释、Markdown 或标注。";
        enhancedUserPrompt = [NSString stringWithFormat:@"请将下面这句话自动识别并翻译成英文：\n%@", text];
    } else { // JS
        systemPrompt = @"你是一个前端开发助手。只输出纯 JavaScript 代码，不要任何 Markdown 格式(如 ```javascript) 或解释。";
        enhancedUserPrompt = [NSString stringWithFormat:@"请写一段 JavaScript 代码来实现这个需求：%@", text];
    }
    
    [[HSBLocalLLMManager shared] processMessage:enhancedUserPrompt systemPrompt:systemPrompt completion:^(NSString * _Nonnull response, BOOL isFinished) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!isFinished) {
                // 流式生成中，仅更新状态标签显示，不进行任何震动、弹窗或 TV 推送
                self.trackpadStatusLabel.text = [NSString stringWithFormat:@"%@ (%lu)", L(@"AI Thinking...", @"AI 思考中..."), (unsigned long)response.length];
                return;
            }
            
            // 物理生成完全结束
            self.trackpadStatusLabel.text = L(@"AI Done", @"AI 处理完成");
            
            NSDictionary *payload = @{
                @"action": (type == 1 ? @"show_translation" : @"run_js"),
                @"content": response,
                @"timestamp": @([[NSDate date] timeIntervalSince1970]),
                @"requestId": [[NSUUID UUID] UUIDString]
            };
            
            if (type == 1) { // 翻译结果
                // 1. 手机弹窗（仅在生成结束时弹一次）
                UIAlertController *res = [UIAlertController alertControllerWithTitle:L(@"Translation Result", @"翻译结果")
                                                                             message:response
                                                                      preferredStyle:UIAlertControllerStyleAlert];
                [res addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
                [self presentViewController:res animated:YES completion:nil];
                
                // 2. 同步到 TV (可选功能：在大屏显示翻译结果)
                [self sendDirectPayload:payload];
                
                // 结束触觉反馈
                UIImpactFeedbackGenerator *hap = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
                [hap impactOccurred];
            } else { // JS 脚本
                // 1. 直接下发执行到 TV（仅在生成结束时下发最终版完整脚本）
                NSMutableDictionary *jsPayload = [payload mutableCopy];
                [jsPayload setObject:response forKey:@"script"]; // 保持兼容性
                [self sendDirectPayload:jsPayload];
                
                // 2. 结束触觉反馈：只有生成结束时才震动，流式不震动
                UIImpactFeedbackGenerator *hap = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
                [hap impactOccurred];
            }
            
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                self.trackpadStatusLabel.text = L(@"Ready", @"就绪");
            });
        });
    }];
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

- (void)openPlayerAction {
    UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [fb impactOccurred];
    
    self.trackpadStatusLabel.text = L(@"▶️ Opening Player...", @"▶️ 正在打开播放器...");
    
    [self sendDirectPayload:@{@"action": @"open_player"}];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (!self.isDragging) self.trackpadStatusLabel.text = L(@"Ready", @"就绪");
    });
}

- (void)closePlayerAction {
    UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [fb impactOccurred];
    
    self.trackpadStatusLabel.text = L(@"⏹️ Closing Player...", @"⏹️ 正在关闭播放器...");
    
    [self sendDirectPayload:@{@"action": @"close_player"}];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (!self.isDragging) self.trackpadStatusLabel.text = L(@"Ready", @"就绪");
    });
}

- (void)videoSliderChanged:(UISlider *)slider {
    self.videoPercentLabel.text = [NSString stringWithFormat:@"%.0f%%", slider.value * 100];
}

- (void)videoSliderEnded:(UISlider *)slider {
    UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [fb impactOccurred];
    
    [self sendDirectPayload:@{@"action": @"seek_percent", @"value": @(slider.value)}];
}

- (void)applyThemeStyle {
    [super applyThemeStyle];
    HSBThemePalette *palette = [HSBThemeManager shared].currentPalette;
    
    if (self.openPlayerBtn) {
        self.openPlayerBtn.backgroundColor = [palette.primaryColor colorWithAlphaComponent:0.15];
        [self.openPlayerBtn setTitleColor:palette.primaryColor forState:UIControlStateNormal];
        [self.openPlayerBtn setTintColor:palette.primaryColor];
    }
    if (self.closePlayerBtn) {
        self.closePlayerBtn.backgroundColor = [palette.primaryColor colorWithAlphaComponent:0.15];
        [self.closePlayerBtn setTitleColor:palette.primaryColor forState:UIControlStateNormal];
        [self.closePlayerBtn setTintColor:palette.primaryColor];
    }
    if (self.videoSlider) {
        self.videoSlider.minimumTrackTintColor = palette.primaryColor;
    }
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
