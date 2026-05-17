#import "HSBLLMTestViewController.h"
#import "HSBLocalLLMManager.h"
#import "HSBLLMModelCenterViewController.h"

static inline NSString * L(NSString *en, NSString *zh) {
    NSString *language = [[NSLocale preferredLanguages] firstObject];
    if ([language hasPrefix:@"zh"]) {
        return zh ?: en;
    }
    return en;
}

@interface HSBLLMTestViewController () <UITextViewDelegate>

@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *contentContainer;

// 顶部模型状态卡片
@property (nonatomic, strong) UIView *statusCard;
@property (nonatomic, strong) UIView *statusDot;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIButton *goToActivateBtn;

// Segmented Control
@property (nonatomic, strong) UISegmentedControl *typeSegment;

// 快捷 Prompt 标签区
@property (nonatomic, strong) UIScrollView *tagsScrollView;
@property (nonatomic, strong) UIView *tagsContainer;

// 输入区域
@property (nonatomic, strong) UIView *inputContainer;
@property (nonatomic, strong) UITextView *inputTextView;
@property (nonatomic, strong) UILabel *placeholderLabel;

// 推理测试按钮
@property (nonatomic, strong) UIButton *testBtn;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;

// 结果卡片
@property (nonatomic, strong) UIView *resultCard;
@property (nonatomic, strong) UITextView *resultTextView;
@property (nonatomic, strong) UIButton *clipboardBtn;
@property (nonatomic, strong) UIButton *runOnTvBtn;

@end

@implementation HSBLLMTestViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = L(@"AI Model Testing", @"AI 模型测试");
    
    [self setupUI];
    [self updateStatusCard];
    [self updateQuickPromptTags];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleModelStatusChange:) name:@"HSBLocalLLMDownloadFinishedNotification" object:nil];
}

- (void)applyThemeStyle {
    [super applyThemeStyle];
    HSBThemePalette *palette = [HSBThemeManager shared].currentPalette;
    
    self.statusCard.backgroundColor = palette.cardBgColor;
    self.inputContainer.backgroundColor = palette.cardBgColor;
    self.resultCard.backgroundColor = palette.cardBgColor;
    
    self.statusLabel.textColor = [UIColor whiteColor];
    self.inputTextView.textColor = [UIColor whiteColor];
    self.resultTextView.textColor = [UIColor whiteColor];
    self.placeholderLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.4];
    
    self.typeSegment.selectedSegmentTintColor = palette.primaryColor;
    [self.typeSegment setTitleTextAttributes:@{NSForegroundColorAttributeName: [[UIColor whiteColor] colorWithAlphaComponent:0.7]} forState:UIControlStateNormal];
    [self.typeSegment setTitleTextAttributes:@{NSForegroundColorAttributeName: [UIColor whiteColor]} forState:UIControlStateSelected];
    
    self.testBtn.backgroundColor = palette.primaryColor;
    [self.testBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    
    [self.clipboardBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.clipboardBtn.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.1];
    
    [self updateQuickPromptTags];
    [self applyRunOnTvButtonGradient];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self applyRunOnTvButtonGradient];
}

- (void)applyRunOnTvButtonGradient {
    if (!self.runOnTvBtn) return;
    
    HSBThemePalette *palette = [HSBThemeManager shared].currentPalette;
    
    for (CALayer *layer in [self.runOnTvBtn.layer.sublayers copy]) {
        if ([layer isKindOfClass:[CAGradientLayer class]]) {
            [layer removeFromSuperlayer];
        }
    }
    
    CAGradientLayer *grad = [CAGradientLayer layer];
    grad.frame = self.runOnTvBtn.bounds;
    grad.colors = @[
        (id)palette.primaryColor.CGColor,
        (id)palette.secondaryColor.CGColor
    ];
    grad.startPoint = CGPointMake(0.0, 0.5);
    grad.endPoint = CGPointMake(1.0, 0.5);
    grad.cornerRadius = 10;
    
    [self.runOnTvBtn.layer insertSublayer:grad atIndex:0];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)handleModelStatusChange:(NSNotification *)note {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateStatusCard];
    });
}

#pragma mark - UI Setup

- (void)setupUI {
    // 1. Scroll View
    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.alwaysBounceVertical = YES;
    self.scrollView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.scrollView];
    
    self.contentContainer = [[UIView alloc] init];
    self.contentContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scrollView addSubview:self.contentContainer];
    
    // 2. 状态卡片 statusCard
    self.statusCard = [[UIView alloc] init];
    self.statusCard.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    self.statusCard.layer.cornerRadius = 16;
    self.statusCard.layer.shadowColor = [UIColor blackColor].CGColor;
    self.statusCard.layer.shadowOpacity = 0.05;
    self.statusCard.layer.shadowOffset = CGSizeMake(0, 4);
    self.statusCard.layer.shadowRadius = 8;
    self.statusCard.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentContainer addSubview:self.statusCard];
    
    self.statusDot = [[UIView alloc] init];
    self.statusDot.layer.cornerRadius = 6;
    self.statusDot.clipsToBounds = YES;
    self.statusDot.translatesAutoresizingMaskIntoConstraints = NO;
    [self.statusCard addSubview:self.statusDot];
    
    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    self.statusLabel.textColor = [UIColor labelColor];
    self.statusLabel.numberOfLines = 0;
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.statusCard addSubview:self.statusLabel];
    
    self.goToActivateBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.goToActivateBtn setTitle:L(@"Go Activate", @"前往激活") forState:UIControlStateNormal];
    self.goToActivateBtn.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
    self.goToActivateBtn.backgroundColor = [UIColor systemOrangeColor];
    [self.goToActivateBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.goToActivateBtn.layer.cornerRadius = 12;
    self.goToActivateBtn.contentEdgeInsets = UIEdgeInsetsMake(6, 12, 6, 12);
    [self.goToActivateBtn addTarget:self action:@selector(goToActivateAction) forControlEvents:UIControlEventTouchUpInside];
    self.goToActivateBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [self.statusCard addSubview:self.goToActivateBtn];
    
    // 3. Segmented Control
    self.typeSegment = [[UISegmentedControl alloc] initWithItems:@[L(@"Translation Mode", @"同声传译(Type 1)"), L(@"Web Control", @"电视控制(Type 2)")]];
    self.typeSegment.selectedSegmentIndex = 0;
    self.typeSegment.tintColor = [UIColor systemPurpleColor];
    [self.typeSegment addTarget:self action:@selector(segmentChanged:) forControlEvents:UIControlEventValueChanged];
    self.typeSegment.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentContainer addSubview:self.typeSegment];
    
    // 4. 快捷标签滚动容器
    self.tagsScrollView = [[UIScrollView alloc] init];
    self.tagsScrollView.showsHorizontalScrollIndicator = NO;
    self.tagsScrollView.alwaysBounceHorizontal = YES;
    self.tagsScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentContainer addSubview:self.tagsScrollView];
    
    self.tagsContainer = [[UIView alloc] init];
    self.tagsContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [self.tagsScrollView addSubview:self.tagsContainer];
    
    // 5. 输入容器及其 TextView
    self.inputContainer = [[UIView alloc] init];
    self.inputContainer.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    self.inputContainer.layer.cornerRadius = 16;
    self.inputContainer.layer.shadowColor = [UIColor blackColor].CGColor;
    self.inputContainer.layer.shadowOpacity = 0.04;
    self.inputContainer.layer.shadowOffset = CGSizeMake(0, 3);
    self.inputContainer.layer.shadowRadius = 6;
    self.inputContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentContainer addSubview:self.inputContainer];
    
    self.inputTextView = [[UITextView alloc] init];
    self.inputTextView.backgroundColor = [UIColor clearColor];
    self.inputTextView.font = [UIFont systemFontOfSize:15 weight:UIFontWeightRegular];
    self.inputTextView.textColor = [UIColor labelColor];
    self.inputTextView.delegate = self;
    self.inputTextView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.inputContainer addSubview:self.inputTextView];
    
    self.placeholderLabel = [[UILabel alloc] init];
    self.placeholderLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightRegular];
    self.placeholderLabel.textColor = [UIColor placeholderTextColor];
    self.placeholderLabel.numberOfLines = 0;
    self.placeholderLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.inputContainer addSubview:self.placeholderLabel];
    
    // 6. 测试按钮与 Spinner
    self.testBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    self.testBtn.backgroundColor = [UIColor systemPurpleColor];
    [self.testBtn setTitle:L(@"Start AI Inference", @"开始端侧 AI 推理") forState:UIControlStateNormal];
    self.testBtn.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightBold];
    [self.testBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.testBtn.layer.cornerRadius = 14;
    [self.testBtn addTarget:self action:@selector(runAIInference) forControlEvents:UIControlEventTouchUpInside];
    self.testBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentContainer addSubview:self.testBtn];
    
    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.spinner.color = [UIColor whiteColor];
    self.spinner.translatesAutoresizingMaskIntoConstraints = NO;
    [self.testBtn addSubview:self.spinner];
    
    // 7. 结果卡片 resultCard
    self.resultCard = [[UIView alloc] init];
    self.resultCard.backgroundColor = [UIColor tertiarySystemGroupedBackgroundColor];
    self.resultCard.layer.cornerRadius = 16;
    self.resultCard.translatesAutoresizingMaskIntoConstraints = NO;
    self.resultCard.hidden = YES; // 默认隐藏，有推理结果时再展示
    [self.contentContainer addSubview:self.resultCard];
    
    self.resultTextView = [[UITextView alloc] init];
    self.resultTextView.backgroundColor = [UIColor clearColor];
    self.resultTextView.editable = NO;
    self.resultTextView.font = [UIFont monospacedSystemFontOfSize:14 weight:UIFontWeightMedium];
    self.resultTextView.textColor = [UIColor labelColor];
    self.resultTextView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.resultCard addSubview:self.resultTextView];
    
    self.clipboardBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.clipboardBtn setTitle:L(@"Copy Result", @"复制结果") forState:UIControlStateNormal];
    self.clipboardBtn.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    self.clipboardBtn.backgroundColor = [UIColor systemGray5Color];
    [self.clipboardBtn setTitleColor:[UIColor labelColor] forState:UIControlStateNormal];
    self.clipboardBtn.layer.cornerRadius = 10;
    self.clipboardBtn.contentEdgeInsets = UIEdgeInsetsMake(6, 12, 6, 12);
    [self.clipboardBtn addTarget:self action:@selector(copyResultAction) forControlEvents:UIControlEventTouchUpInside];
    self.clipboardBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [self.resultCard addSubview:self.clipboardBtn];
    
    self.runOnTvBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.runOnTvBtn setTitle:L(@"Run on TV", @"在电视上运行") forState:UIControlStateNormal];
    self.runOnTvBtn.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
    self.runOnTvBtn.backgroundColor = [UIColor systemIndigoColor];
    [self.runOnTvBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.runOnTvBtn.layer.cornerRadius = 10;
    self.runOnTvBtn.contentEdgeInsets = UIEdgeInsetsMake(6, 12, 6, 12);
    [self.runOnTvBtn addTarget:self action:@selector(runOnTvAction) forControlEvents:UIControlEventTouchUpInside];
    self.runOnTvBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [self.resultCard addSubview:self.runOnTvBtn];
    
    // 8. Auto Layout Constraints
    [NSLayoutConstraint activateConstraints:@[
        // Scroll View
        [self.scrollView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        
        [self.contentContainer.topAnchor constraintEqualToAnchor:self.scrollView.topAnchor],
        [self.contentContainer.leadingAnchor constraintEqualToAnchor:self.scrollView.leadingAnchor],
        [self.contentContainer.trailingAnchor constraintEqualToAnchor:self.scrollView.trailingAnchor],
        [self.contentContainer.bottomAnchor constraintEqualToAnchor:self.scrollView.bottomAnchor],
        [self.contentContainer.widthAnchor constraintEqualToAnchor:self.scrollView.widthAnchor],
        
        // Status Card
        [self.statusCard.topAnchor constraintEqualToAnchor:self.contentContainer.topAnchor constant:16],
        [self.statusCard.leadingAnchor constraintEqualToAnchor:self.contentContainer.leadingAnchor constant:16],
        [self.statusCard.trailingAnchor constraintEqualToAnchor:self.contentContainer.trailingAnchor constant:-16],
        
        [self.statusDot.leadingAnchor constraintEqualToAnchor:self.statusCard.leadingAnchor constant:16],
        [self.statusDot.centerYAnchor constraintEqualToAnchor:self.statusCard.centerYAnchor],
        [self.statusDot.widthAnchor constraintEqualToConstant:12],
        [self.statusDot.heightAnchor constraintEqualToConstant:12],
        
        [self.statusLabel.topAnchor constraintEqualToAnchor:self.statusCard.topAnchor constant:14],
        [self.statusLabel.leadingAnchor constraintEqualToAnchor:self.statusDot.trailingAnchor constant:12],
        [self.statusLabel.trailingAnchor constraintEqualToAnchor:self.goToActivateBtn.leadingAnchor constant:-8],
        [self.statusLabel.bottomAnchor constraintEqualToAnchor:self.statusCard.bottomAnchor constant:-14],
        
        [self.goToActivateBtn.trailingAnchor constraintEqualToAnchor:self.statusCard.trailingAnchor constant:-16],
        [self.goToActivateBtn.centerYAnchor constraintEqualToAnchor:self.statusCard.centerYAnchor],
        
        // Segment
        [self.typeSegment.topAnchor constraintEqualToAnchor:self.statusCard.bottomAnchor constant:16],
        [self.typeSegment.leadingAnchor constraintEqualToAnchor:self.contentContainer.leadingAnchor constant:16],
        [self.typeSegment.trailingAnchor constraintEqualToAnchor:self.contentContainer.trailingAnchor constant:-16],
        [self.typeSegment.heightAnchor constraintEqualToConstant:36],
        
        // Tags Scroll View
        [self.tagsScrollView.topAnchor constraintEqualToAnchor:self.typeSegment.bottomAnchor constant:12],
        [self.tagsScrollView.leadingAnchor constraintEqualToAnchor:self.contentContainer.leadingAnchor],
        [self.tagsScrollView.trailingAnchor constraintEqualToAnchor:self.contentContainer.trailingAnchor],
        [self.tagsScrollView.heightAnchor constraintEqualToConstant:40],
        
        [self.tagsContainer.topAnchor constraintEqualToAnchor:self.tagsScrollView.topAnchor],
        [self.tagsContainer.leadingAnchor constraintEqualToAnchor:self.tagsScrollView.leadingAnchor],
        [self.tagsContainer.trailingAnchor constraintEqualToAnchor:self.tagsScrollView.trailingAnchor],
        [self.tagsContainer.bottomAnchor constraintEqualToAnchor:self.tagsScrollView.bottomAnchor],
        [self.tagsContainer.heightAnchor constraintEqualToAnchor:self.tagsScrollView.heightAnchor],
        
        // Input Container
        [self.inputContainer.topAnchor constraintEqualToAnchor:self.tagsScrollView.bottomAnchor constant:12],
        [self.inputContainer.leadingAnchor constraintEqualToAnchor:self.contentContainer.leadingAnchor constant:16],
        [self.inputContainer.trailingAnchor constraintEqualToAnchor:self.contentContainer.trailingAnchor constant:-16],
        [self.inputContainer.heightAnchor constraintEqualToConstant:120],
        
        [self.inputTextView.topAnchor constraintEqualToAnchor:self.inputContainer.topAnchor constant:10],
        [self.inputTextView.leadingAnchor constraintEqualToAnchor:self.inputContainer.leadingAnchor constant:12],
        [self.inputTextView.trailingAnchor constraintEqualToAnchor:self.inputContainer.trailingAnchor constant:-12],
        [self.inputTextView.bottomAnchor constraintEqualToAnchor:self.inputContainer.bottomAnchor constant:-10],
        
        [self.placeholderLabel.topAnchor constraintEqualToAnchor:self.inputContainer.topAnchor constant:18],
        [self.placeholderLabel.leadingAnchor constraintEqualToAnchor:self.inputContainer.leadingAnchor constant:17],
        [self.placeholderLabel.trailingAnchor constraintEqualToAnchor:self.inputContainer.trailingAnchor constant:-17],
        
        // Test Button
        [self.testBtn.topAnchor constraintEqualToAnchor:self.inputContainer.bottomAnchor constant:16],
        [self.testBtn.leadingAnchor constraintEqualToAnchor:self.contentContainer.leadingAnchor constant:16],
        [self.testBtn.trailingAnchor constraintEqualToAnchor:self.contentContainer.trailingAnchor constant:-16],
        [self.testBtn.heightAnchor constraintEqualToConstant:50],
        
        [self.spinner.centerYAnchor constraintEqualToAnchor:self.testBtn.centerYAnchor],
        [self.spinner.trailingAnchor constraintEqualToAnchor:self.testBtn.trailingAnchor constant:-20],
        
        // Result Card
        [self.resultCard.topAnchor constraintEqualToAnchor:self.testBtn.bottomAnchor constant:16],
        [self.resultCard.leadingAnchor constraintEqualToAnchor:self.contentContainer.leadingAnchor constant:16],
        [self.resultCard.trailingAnchor constraintEqualToAnchor:self.contentContainer.trailingAnchor constant:-16],
        [self.resultCard.bottomAnchor constraintEqualToAnchor:self.contentContainer.bottomAnchor constant:-24],
        
        [self.resultTextView.topAnchor constraintEqualToAnchor:self.resultCard.topAnchor constant:12],
        [self.resultTextView.leadingAnchor constraintEqualToAnchor:self.resultCard.leadingAnchor constant:12],
        [self.resultTextView.trailingAnchor constraintEqualToAnchor:self.resultCard.trailingAnchor constant:-12],
        [self.resultTextView.heightAnchor constraintEqualToConstant:150],
        
        [self.clipboardBtn.topAnchor constraintEqualToAnchor:self.resultTextView.bottomAnchor constant:10],
        [self.clipboardBtn.leadingAnchor constraintEqualToAnchor:self.resultCard.leadingAnchor constant:12],
        [self.clipboardBtn.bottomAnchor constraintEqualToAnchor:self.resultCard.bottomAnchor constant:-12],
        
        [self.runOnTvBtn.topAnchor constraintEqualToAnchor:self.resultTextView.bottomAnchor constant:10],
        [self.runOnTvBtn.trailingAnchor constraintEqualToAnchor:self.resultCard.trailingAnchor constant:-12],
        [self.runOnTvBtn.bottomAnchor constraintEqualToAnchor:self.resultCard.bottomAnchor constant:-12]
    ]];
}

#pragma mark - State Refresh

- (void)updateStatusCard {
    HSBLocalLLMModel *activeModel = [HSBLocalLLMManager shared].activeModel;
    if (activeModel && activeModel.isActive) {
        // 激活状态
        self.statusDot.backgroundColor = [UIColor systemGreenColor];
        self.statusLabel.text = [NSString stringWithFormat:L(@"Active: %@", @"当前已激活大模型：%@"), activeModel.name];
        self.goToActivateBtn.hidden = YES;
        self.testBtn.enabled = YES;
        self.testBtn.alpha = 1.0;
        
        // 呼吸灯动效
        [self.statusDot.layer removeAllAnimations];
        self.statusDot.alpha = 1.0;
        [UIView animateWithDuration:1.0 delay:0 options:UIViewAnimationOptionAutoreverse | UIViewAnimationOptionRepeat animations:^{
            self.statusDot.alpha = 0.3;
        } completion:nil];
    } else {
        // 未激活状态
        self.statusDot.backgroundColor = [UIColor systemOrangeColor];
        self.statusLabel.text = L(@"No active AI Model detected.", @"当前未激活任何端侧大模型，请先前往模型中心进行激活。");
        self.goToActivateBtn.hidden = NO;
        self.testBtn.enabled = NO;
        self.testBtn.alpha = 0.5;
        [self.statusDot.layer removeAllAnimations];
        self.statusDot.alpha = 1.0;
    }
}

- (void)updateQuickPromptTags {
    if (!self.tagsContainer) return;
    
    // 移除已有标签
    for (UIView *v in self.tagsContainer.subviews) {
        [v removeFromSuperview];
    }
    
    NSArray *prompts = nil;
    if (self.typeSegment.selectedSegmentIndex == 0) {
        prompts = @[
            L(@"Translate 'The moon is beautiful tonight'", @"翻译: '今晚月色真美'"),
            L(@"Translate: 'Artificial Intelligence will guide the future'", @"翻译: '人工智能指引未来'"),
            L(@"Translate: 'Enjoy coding!'", @"翻译: '祝你配对编程愉快！'")
        ];
        self.placeholderLabel.text = L(@"Type text here to request translation...", @"在此处输入需要进行端侧 AI 同声传译的中文或英文内容...");
    } else {
        prompts = @[
            L(@"Turn background to soft red", @"电视网页背景变成柔和红"),
            L(@"Hide page header container", @"隐藏电视网页的所有导航栏"),
            L(@"Display an alert dialog", @"在电视上弹出一个 Hello 对话框")
        ];
        self.placeholderLabel.text = L(@"Describe the control action to generate and run JS script on TV...", @"在此处用自然语言描述电视控制指令（如：让背景变红、隐藏标题栏），AI 将自动生成脚本控制电视网页...");
    }
    
    self.placeholderLabel.hidden = (self.inputTextView.text.length > 0);
    
    // 动态生成气泡按钮
    UIView *lastView = nil;
    for (int i = 0; i < prompts.count; i++) {
        NSString *title = prompts[i];
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
        [btn setTitle:title forState:UIControlStateNormal];
        btn.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
        btn.backgroundColor = [[HSBThemeManager shared].currentPalette.primaryColor colorWithAlphaComponent:0.12];
        btn.tintColor = [HSBThemeManager shared].currentPalette.primaryColor;
        btn.layer.cornerRadius = 14;
        btn.contentEdgeInsets = UIEdgeInsetsMake(6, 12, 6, 12);
        btn.tag = i;
        [btn addTarget:self action:@selector(tagPressed:) forControlEvents:UIControlEventTouchUpInside];
        btn.translatesAutoresizingMaskIntoConstraints = NO;
        [self.tagsContainer addSubview:btn];
        
        [NSLayoutConstraint activateConstraints:@[
            [btn.centerYAnchor constraintEqualToAnchor:self.tagsContainer.centerYAnchor],
            [btn.heightAnchor constraintEqualToConstant:28]
        ]];
        
        if (lastView == nil) {
            [btn.leadingAnchor constraintEqualToAnchor:self.tagsContainer.leadingAnchor constant:16].active = YES;
        } else {
            [btn.leadingAnchor constraintEqualToAnchor:lastView.trailingAnchor constant:8].active = YES;
        }
        lastView = btn;
    }
    if (lastView) {
        [lastView.trailingAnchor constraintEqualToAnchor:self.tagsContainer.trailingAnchor constant:-16].active = YES;
    }
}

#pragma mark - UI Actions

- (void)goToActivateAction {
    HSBLLMModelCenterViewController *vc = [[HSBLLMModelCenterViewController alloc] init];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)segmentChanged:(UISegmentedControl *)sender {
    [self updateQuickPromptTags];
    self.inputTextView.text = @"";
    self.placeholderLabel.hidden = NO;
}

- (void)tagPressed:(UIButton *)sender {
    NSArray *prompts = nil;
    if (self.typeSegment.selectedSegmentIndex == 0) {
        prompts = @[
            @"今晚月色真美，适合去散散步。",
            @"Artificial Intelligence will guide the future of human-machine interaction.",
            @"Enjoy pair programming with your smart assistant!"
        ];
    } else {
        prompts = @[
            @"让电视网页的背景变成粉红色",
            @"隐藏当前网页的 header 头部导航栏",
            @"alert('糖葫芦遥控器：端侧大模型验证成功！');"
        ];
    }
    
    if (sender.tag < prompts.count) {
        UIImpactFeedbackGenerator *hap = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
        [hap impactOccurred];
        self.inputTextView.text = prompts[sender.tag];
        self.placeholderLabel.hidden = YES;
    }
}

- (void)runAIInference {
    NSString *prompt = [self.inputTextView.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (prompt.length == 0) return;
    
    [self.inputTextView resignFirstResponder];
    self.testBtn.enabled = NO;
    self.testBtn.alpha = 0.7;
    [self.spinner startAnimating];
    [self.testBtn setTitle:L(@"AI Thinking...", @"端侧大模型推理中...") forState:UIControlStateNormal];
    
    NSInteger type = (self.typeSegment.selectedSegmentIndex == 0) ? 1 : 2;
    
    __weak typeof(self) weakSelf = self;
    [[HSBLocalLLMManager shared] processMessage:prompt type:type completion:^(NSString * _Nonnull response) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf.spinner stopAnimating];
            weakSelf.testBtn.enabled = YES;
            weakSelf.testBtn.alpha = 1.0;
            [weakSelf.testBtn setTitle:L(@"Start AI Inference", @"开始端侧 AI 推理") forState:UIControlStateNormal];
            
            // 展示结果卡片
            weakSelf.resultCard.hidden = NO;
            weakSelf.resultTextView.text = response;
            
            // 根据类型动态显示或隐藏“在电视运行”按钮
            weakSelf.runOnTvBtn.hidden = (type != 2);
            
            // 结果滚动到顶部
            [weakSelf.resultTextView scrollRangeToVisible:NSMakeRange(0, 0)];
            
            // 触觉反馈
            UINotificationFeedbackGenerator *hap = [[UINotificationFeedbackGenerator alloc] init];
            [hap notificationOccurred:UINotificationFeedbackTypeSuccess];
        });
    }];
}

- (void)copyResultAction {
    NSString *text = self.resultTextView.text;
    if (text.length > 0) {
        [UIPasteboard generalPasteboard].string = text;
        
        UIImpactFeedbackGenerator *hap = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
        [hap impactOccurred];
        
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:L(@"Success", @"成功")
                                                                       message:L(@"Copied to clipboard!", @"已成功复制到剪切板！")
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [self presentViewController:alert animated:YES completion:nil];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [alert dismissViewControllerAnimated:YES completion:nil];
        });
    }
}

- (void)runOnTvAction {
    NSString *jsCode = self.resultTextView.text;
    if (jsCode.length == 0) return;
    
    if (self.sendPayloadBlock) {
        UIImpactFeedbackGenerator *hap = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
        [hap impactOccurred];
        
        // 构造控制电视的 JSON payload，与 BrowserControlViewController 保持完全兼容
        NSDictionary *payload = @{
            @"action": @"run_js",
            @"script": jsCode,
            @"content": jsCode,
            @"timestamp": @([[NSDate date] timeIntervalSince1970]),
            @"requestId": [[NSUUID UUID] UUIDString]
        };
        
        self.sendPayloadBlock(payload);
        
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:L(@"Instruction Sent", @"已发送")
                                                                       message:L(@"Script has been sent to external display.", @"控制脚本已实时投送并在大屏网页运行！")
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [self presentViewController:alert animated:YES completion:nil];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [alert dismissViewControllerAnimated:YES completion:nil];
        });
    } else {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:L(@"Error", @"发送失败")
                                                                       message:L(@"TV is not connected or screen link is inactive.", @"大屏显示器未就绪或未连接。")
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    }
}

#pragma mark - UITextViewDelegate

- (void)textViewDidChange:(UITextView *)textView {
    self.placeholderLabel.hidden = (textView.text.length > 0);
}

@end
