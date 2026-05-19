//
//  BrowserControlViewController.m
//  HSBWatchCompanion
//

#import "BrowserControlViewController.h"
#import <UIKit/UIKit.h>
#import <UIKit/UIGestureRecognizerSubclass.h>
#import <Speech/Speech.h>
#import <AVFoundation/AVFoundation.h>
#import "HSBLocalLLMManager.h"
#import "HSBWatchCompanion-Swift.h"


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

// 🎙️ 实时语音听写引擎与右下角毛玻璃状态看板属性
@property (nonatomic, strong) SFSpeechRecognizer *speechRecognizer;
@property (nonatomic, strong) SFSpeechAudioBufferRecognitionRequest *recognitionRequest;
@property (nonatomic, strong) SFSpeechRecognitionTask *recognitionTask;
@property (nonatomic, strong) AVAudioEngine *audioEngine;
@property (nonatomic, copy) NSString *recognizedSpeechText;

@property (nonatomic, strong) UIView *speechPanel;
@property (nonatomic, strong) UILabel *speechStatusLabel;
@property (nonatomic, strong) UILabel *speechResultLabel;

@property (nonatomic, strong) UIButton *aiBtn;
@property (nonatomic, assign) BOOL isAIButtonPressed;

@end

@implementation BrowserControlViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    self.title = L(@"Fullscreen Trackpad", @"全屏触控板");
    
    [self setupUI];
    [self setupSpeechPanel];
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

    

    // AI Assistant Floating Button
    self.aiBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.aiBtn setImage:[UIImage systemImageNamed:@"sparkles" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:22 weight:UIImageSymbolWeightBold]] forState:UIControlStateNormal];
    self.aiBtn.tintColor = [UIColor whiteColor];
    self.aiBtn.backgroundColor = [UIColor systemPurpleColor];
    self.aiBtn.layer.cornerRadius = 28;
    self.aiBtn.clipsToBounds = NO;
    
    // 阴影效果
    self.aiBtn.layer.shadowColor = [UIColor systemPurpleColor].CGColor;
    self.aiBtn.layer.shadowOffset = CGSizeMake(0, 4);
    self.aiBtn.layer.shadowOpacity = 0.4;
    self.aiBtn.layer.shadowRadius = 8;
    
    [self.aiBtn addTarget:self action:@selector(aiButtonTouchDown) forControlEvents:UIControlEventTouchDown];
    [self.aiBtn addTarget:self action:@selector(aiButtonTouchUp) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
    self.aiBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.aiBtn];

    
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
        [headerView.heightAnchor constraintEqualToConstant:20],
        
        [handleIndicator.topAnchor constraintEqualToAnchor:headerView.topAnchor constant:4],
        [handleIndicator.centerXAnchor constraintEqualToAnchor:headerView.centerXAnchor],
        [handleIndicator.widthAnchor constraintEqualToConstant:40],
        [handleIndicator.heightAnchor constraintEqualToConstant:6],
        

        
        [self.aiBtn.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-24],
        [self.aiBtn.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-90],
        [self.aiBtn.widthAnchor constraintEqualToConstant:56],
        [self.aiBtn.heightAnchor constraintEqualToConstant:56],

        
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
    
    // 🥇 强制将悬浮 AI 按钮置于视图层级最顶层，防止被 Trackpad 触控板等大视图遮挡
    [self.view bringSubviewToFront:self.aiBtn];
}

- (void)dismissAction {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    if (self.audioEngine.isRunning) {
        [self.audioEngine stop];
        self.recognitionRequest = nil;
        self.recognitionTask = nil;
    }
}

- (void)aiButtonTouchDown {
    self.isAIButtonPressed = YES;
    
    // 触发触觉反馈并立刻开始录音
    UIImpactFeedbackGenerator *hap = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleHeavy];
    [hap impactOccurred];
    
    [self startRecordingAndRecognition];
}

- (void)aiButtonTouchUp {
    if (!self.isAIButtonPressed) return;
    self.isAIButtonPressed = NO;
    
    // 松开手就立刻停止录音并处理结果
    [self stopRecordingAndRecognition];
}

- (void)startRecordingAndRecognition {
    // 检查并申请语音听写与麦克风录音权限
    [SFSpeechRecognizer requestAuthorization:^(SFSpeechRecognizerAuthorizationStatus status) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (status == SFSpeechRecognizerAuthorizationStatusAuthorized) {
                [AVCaptureDevice requestAccessForMediaType:AVMediaTypeAudio completionHandler:^(BOOL granted) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (granted) {
                            [self performRecordingStart];
                        } else {
                            [self showSpeechAlertError:L(@"Microphone permission denied.", @"麦克风权限未开启")];
                        }
                    });
                }];
            } else {
                [self showSpeechAlertError:L(@"Speech recognition permission denied.", @"语音识别权限未开启")];
            }
        });
    }];
}

- (void)performRecordingStart {
    // 🥇 智能防越界检查：如果异步麦克风或识别权限回调完成时，用户早已松开手指，则直接截断，拒绝启动录音
    if (!self.isAIButtonPressed) {
        NSLog(@"[Speech] User already released AI button before permissions granted. Aborting.");
        return;
    }
    
    // 1. 如果有旧任务，取消它
    if (self.recognitionTask) {
        [self.recognitionTask cancel];
        self.recognitionTask = nil;
    }
    
    // 2. 初始化音频会话
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    NSError *error = nil;
    [audioSession setCategory:AVAudioSessionCategoryRecord mode:AVAudioSessionModeMeasurement options:AVAudioSessionCategoryOptionDuckOthers error:&error];
    [audioSession setActive:YES withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:&error];
    
    self.recognitionRequest = [[SFSpeechAudioBufferRecognitionRequest alloc] init];
    self.audioEngine = [[AVAudioEngine alloc] init];
    
    AVAudioInputNode *inputNode = self.audioEngine.inputNode;
    self.recognitionRequest.shouldReportPartialResults = YES;
    
    // 3. 配置本地识别器（支持中英文识别）
    NSString *localeStr = L(@"en-US", @"zh-CN");
    self.speechRecognizer = [[SFSpeechRecognizer alloc] initWithLocale:[NSLocale localeWithLocaleIdentifier:localeStr]];
    
    __weak typeof(self) weakSelf = self;
    self.recognitionTask = [self.speechRecognizer recognitionTaskWithRequest:self.recognitionRequest resultHandler:^(SFSpeechRecognitionResult * _Nullable result, NSError * _Nullable error) {
        if (result) {
            NSString *bestString = result.bestTranscription.formattedString;
            weakSelf.recognizedSpeechText = bestString;
            dispatch_async(dispatch_get_main_queue(), ^{
                weakSelf.speechResultLabel.text = bestString;
            });
        }
        
        if (error || (result && result.isFinal)) {
            [weakSelf.audioEngine stop];
            [inputNode removeTapOnBus:0];
            weakSelf.recognitionRequest = nil;
            weakSelf.recognitionTask = nil;
        }
    }];
    
    // 4. 配置麦克风输入 Tap 缓存区
    AVAudioFormat *recordingFormat = [inputNode outputFormatForBus:0];
    [inputNode installTapOnBus:0 bufferSize:1024 format:recordingFormat block:^(AVAudioPCMBuffer * _Nonnull buffer, AVAudioTime * _Nonnull when) {
        [weakSelf.recognitionRequest appendAudioPCMBuffer:buffer];
    }];
    
    [self.audioEngine prepare];
    [self.audioEngine startAndReturnError:&error];
    
    self.recognizedSpeechText = @"";
    [self showSpeechPanel];
}

- (void)stopRecordingAndRecognition {
    if (self.audioEngine.isRunning) {
        [self.audioEngine stop];
        [self.recognitionRequest endAudio];
        [self hideSpeechPanel];
        
        // 触发触觉反馈
        UIImpactFeedbackGenerator *hap = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
        [hap impactOccurred];
        
        // 如果识别到了指令文本，直接丢给大模型处理并生成 JS 并下发
        NSString *trimmedText = [self.recognizedSpeechText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (trimmedText.length > 0) {
            [self processAIRequest:trimmedText type:2];
        }
    }
}

- (void)setupSpeechPanel {
    self.speechPanel = [[UIView alloc] init];
    self.speechPanel.translatesAutoresizingMaskIntoConstraints = NO;
    self.speechPanel.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.75];
    self.speechPanel.layer.cornerRadius = 20;
    self.speechPanel.layer.borderWidth = 1.5;
    self.speechPanel.layer.borderColor = [[UIColor systemPurpleColor] colorWithAlphaComponent:0.4].CGColor;
    
    // 阴影
    self.speechPanel.layer.shadowColor = [UIColor systemPurpleColor].CGColor;
    self.speechPanel.layer.shadowOpacity = 0.25;
    self.speechPanel.layer.shadowOffset = CGSizeMake(0, 8);
    self.speechPanel.layer.shadowRadius = 16;
    self.speechPanel.hidden = YES;
    [self.view addSubview:self.speechPanel];
    
    // 毛玻璃效果
    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blur];
    blurView.frame = self.speechPanel.bounds;
    blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    blurView.layer.cornerRadius = 20;
    blurView.clipsToBounds = YES;
    [self.speechPanel addSubview:blurView];
    
    // 微缩麦克风图标
    UIImageView *micIcon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"waveform.and.mic" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIFontWeightSemibold]]];
    micIcon.tintColor = [UIColor systemPurpleColor];
    micIcon.translatesAutoresizingMaskIntoConstraints = NO;
    [self.speechPanel addSubview:micIcon];
    
    // 状态标题 Label
    self.speechStatusLabel = [[UILabel alloc] init];
    self.speechStatusLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightBold];
    self.speechStatusLabel.textColor = [UIColor systemPurpleColor];
    self.speechStatusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.speechPanel addSubview:self.speechStatusLabel];
    
    // 语音识别结果实时显示 Label
    self.speechResultLabel = [[UILabel alloc] init];
    self.speechResultLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    self.speechResultLabel.textColor = [UIColor whiteColor];
    self.speechResultLabel.numberOfLines = 2;
    self.speechResultLabel.textAlignment = NSTextAlignmentLeft;
    self.speechResultLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.speechPanel addSubview:self.speechResultLabel];
    
    // 约束：放置在悬浮 AI 按钮（aiBtn）的上方，完美层叠对齐
    [NSLayoutConstraint activateConstraints:@[
        [self.speechPanel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-24],
        [self.speechPanel.bottomAnchor constraintEqualToAnchor:self.aiBtn.topAnchor constant:-12],
        [self.speechPanel.widthAnchor constraintEqualToConstant:220],
        [self.speechPanel.heightAnchor constraintEqualToConstant:100],
        
        [micIcon.leadingAnchor constraintEqualToAnchor:self.speechPanel.leadingAnchor constant:14],
        [micIcon.topAnchor constraintEqualToAnchor:self.speechPanel.topAnchor constant:12],
        [micIcon.widthAnchor constraintEqualToConstant:16],
        [micIcon.heightAnchor constraintEqualToConstant:16],
        
        [self.speechStatusLabel.leadingAnchor constraintEqualToAnchor:micIcon.trailingAnchor constant:6],
        [self.speechStatusLabel.centerYAnchor constraintEqualToAnchor:micIcon.centerYAnchor],
        
        [self.speechResultLabel.leadingAnchor constraintEqualToAnchor:self.speechPanel.leadingAnchor constant:14],
        [self.speechResultLabel.trailingAnchor constraintEqualToAnchor:self.speechPanel.trailingAnchor constant:-14],
        [self.speechResultLabel.topAnchor constraintEqualToAnchor:micIcon.bottomAnchor constant:10],
        [self.speechResultLabel.bottomAnchor constraintEqualToAnchor:self.speechPanel.bottomAnchor constant:-12]
    ]];
    
    // 🥇 强制将语音听写状态卡片也置于视图层级最顶端，保证随时显示可见
    [self.view bringSubviewToFront:self.speechPanel];
}

- (void)showSpeechPanel {
    self.speechPanel.hidden = NO;
    self.speechPanel.alpha = 0.0;
    self.speechPanel.transform = CGAffineTransformMakeTranslation(0, 30);
    self.speechStatusLabel.text = L(@"Listening...", @"正在倾听...");
    self.speechResultLabel.text = L(@"Speak your instruction...", @"请说出您的操作指令...");
    
    [UIView animateWithDuration:0.3 delay:0.0 usingSpringWithDamping:0.8 initialSpringVelocity:0.5 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        self.speechPanel.alpha = 1.0;
        self.speechPanel.transform = CGAffineTransformIdentity;
    } completion:nil];
    
    CABasicAnimation *pulse = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    pulse.duration = 1.0;
    pulse.fromValue = @(0.95);
    pulse.toValue = @(1.05);
    pulse.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    pulse.autoreverses = YES;
    pulse.repeatCount = INFINITY;
    [self.speechPanel.layer addAnimation:pulse forKey:@"pulseAnimation"];
}

- (void)hideSpeechPanel {
    [UIView animateWithDuration:0.25 animations:^{
        self.speechPanel.alpha = 0.0;
        self.speechPanel.transform = CGAffineTransformMakeTranslation(0, 30);
    } completion:^(BOOL finished) {
        self.speechPanel.hidden = YES;
        [self.speechPanel.layer removeAnimationForKey:@"pulseAnimation"];
    }];
}

- (void)showSpeechAlertError:(NSString *)msg {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:L(@"Voice Control Error", @"语音控制失败")
                                                                   message:msg
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:L(@"OK", @"好的") style:UIAlertActionStyleDefault handler:nil]];
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
        systemPrompt = @"You are a browser automation assistant. Generate ONLY executable browser JavaScript code based on the user's request. Keep the code extremely simple and solid.\n\n"
                       "RULES:\n"
                       "1. Output ONLY executable browser JavaScript code. No explanations, no markdown formatting (DO NOT use ``` or ```javascript), no HTML tags, no intro/outro.\n"
                       "2. The code must be immediately executable by browser eval().\n"
                       "3. Do NOT output HTML like '<div>'. If changing background, use DOM style APIs.\n\n"
                       "EXAMPLES:\n"
                       "Request: \"让网页背景变黑\"\n"
                       "Output: document.body.style.backgroundColor = 'black';\n\n"
                       "Request: \"把背景变成绿色\"\n"
                       "Output: document.body.style.backgroundColor = 'green';\n\n"
                       "Request: \"滚动到最底部\"\n"
                       "Output: window.scrollTo({ top: document.body.scrollHeight, behavior: 'smooth' });\n\n"
                       "Request: \"将所有字体变大\"\n"
                       "Output: document.querySelectorAll('*').forEach(el => { el.style.fontSize = '1.2em'; });";
                       
        enhancedUserPrompt = [NSString stringWithFormat:@"Request: \"%@\"\nOutput: ", text];
    }
    
    [[HSBLocalLLMManager shared] processMessage:enhancedUserPrompt systemPrompt:systemPrompt completion:^(NSString * _Nonnull response, BOOL isFinished) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!isFinished) {
                // 流式生成中，仅更新状态标签显示，不进行 any 震动、弹窗或 TV 推送
                self.trackpadStatusLabel.text = [NSString stringWithFormat:@"%@ (%lu)", L(@"AI Thinking...", @"AI 思考中..."), (unsigned long)response.length];
                return;
            }
            
            // 物理生成完全结束
            self.trackpadStatusLabel.text = L(@"AI Done", @"AI 处理完成");
            
            // 🥇 程序级安全过滤净化：过滤可能多余包裹的 markdown 代码块与前后空白
            NSString *cleanResponse = [response stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if ([cleanResponse hasPrefix:@"```javascript"]) {
                cleanResponse = [cleanResponse substringFromIndex:13];
            } else if ([cleanResponse hasPrefix:@"```js"]) {
                cleanResponse = [cleanResponse substringFromIndex:5];
            } else if ([cleanResponse hasPrefix:@"```"]) {
                cleanResponse = [cleanResponse substringFromIndex:3];
            }
            
            if ([cleanResponse hasSuffix:@"```"]) {
                cleanResponse = [cleanResponse substringToIndex:cleanResponse.length - 3];
            }
            
            cleanResponse = [cleanResponse stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            
            // 如果是以 Output: 开头，去掉它（防御式编程）
            if ([cleanResponse hasPrefix:@"Output:"]) {
                cleanResponse = [cleanResponse substringFromIndex:7];
                cleanResponse = [cleanResponse stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            } else if ([cleanResponse hasPrefix:@"Output: "]) {
                cleanResponse = [cleanResponse substringFromIndex:8];
                cleanResponse = [cleanResponse stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            }
            
            NSDictionary *payload = @{
                @"action": (type == 1 ? @"show_translation" : @"run_js"),
                @"content": cleanResponse,
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
