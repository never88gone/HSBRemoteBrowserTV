//
//  HSBAboutViewController.m
//  HSBWatchCompanion
//

#import "HSBAboutViewController.h"
#import "HSBThemeManager.h"
#import "HSBContactUsViewController.h"
#import "HSBOpenSourceLibrariesViewController.h"

static inline NSString * L(NSString *en, NSString *zh) {
    NSString *language = [[NSLocale preferredLanguages] firstObject];
    if ([language hasPrefix:@"zh"]) {
        return zh ?: en;
    }
    return en;
}

@interface HSBAboutViewController ()

@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIStackView *contentStackView;
@property (nonatomic, strong) NSMutableArray<UIView *> *themeCards;
@property (nonatomic, strong) UILabel *versionBadgeLabel;

@end

@implementation HSBAboutViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = L(@"About", @"关于");
    self.themeCards = [NSMutableArray array];
    
    [self setupScrollView];
    [self setupHeroHeader];
    [self setupFeaturesCard];
    [self setupEcosystemCard];
    [self setupActionsCard];
    [self setupFooter];
    
    [self applyThemeStyle];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"UITestScrollBottom"]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self.scrollView layoutIfNeeded];
            CGFloat targetY = MAX(0, self.scrollView.contentSize.height - self.scrollView.bounds.size.height + self.scrollView.adjustedContentInset.bottom);
            [self.scrollView setContentOffset:CGPointMake(0, targetY) animated:NO];
        });
    }
}

- (void)setupScrollView {
    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.backgroundColor = [UIColor clearColor];
    self.scrollView.alwaysBounceVertical = YES;
    self.scrollView.showsVerticalScrollIndicator = NO;
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.scrollView];
    
    self.contentStackView = [[UIStackView alloc] init];
    self.contentStackView.axis = UILayoutConstraintAxisVertical;
    self.contentStackView.spacing = 16.0;
    self.contentStackView.alignment = UIStackViewAlignmentFill;
    self.contentStackView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scrollView addSubview:self.contentStackView];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.scrollView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        
        [self.contentStackView.topAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.topAnchor constant:16],
        [self.contentStackView.leadingAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.leadingAnchor constant:16],
        [self.contentStackView.trailingAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.trailingAnchor constant:-16],
        [self.contentStackView.bottomAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.bottomAnchor constant:-32],
        [self.contentStackView.widthAnchor constraintEqualToAnchor:self.scrollView.frameLayoutGuide.widthAnchor constant:-32]
    ]];
}

#pragma mark - 1. 顶部品牌 Hero 区域

- (void)setupHeroHeader {
    UIView *heroView = [[UIView alloc] init];
    heroView.translatesAutoresizingMaskIntoConstraints = NO;
    
    // 图标发光外壳
    UIView *iconGlowContainer = [[UIView alloc] init];
    iconGlowContainer.backgroundColor = [UIColor clearColor];
    iconGlowContainer.layer.shadowColor = [HSBThemeManager tanghuluBrandColor].CGColor;
    iconGlowContainer.layer.shadowRadius = 14.0;
    iconGlowContainer.layer.shadowOpacity = 0.45;
    iconGlowContainer.layer.shadowOffset = CGSizeMake(0, 6);
    iconGlowContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [heroView addSubview:iconGlowContainer];
    
    // 图标本体
    UIImage *logoImg = [UIImage imageNamed:@"brandlogo"];
    if (!logoImg) {
        NSDictionary *infoDict = [[NSBundle mainBundle] infoDictionary];
        NSDictionary *iconsDict = infoDict[@"CFBundleIcons"];
        NSDictionary *primaryIconDict = iconsDict[@"CFBundlePrimaryIcon"];
        NSArray *iconFiles = primaryIconDict[@"CFBundleIconFiles"];
        logoImg = [UIImage imageNamed:[iconFiles lastObject]];
    }
    if (!logoImg) {
        logoImg = [UIImage systemImageNamed:@"appletvremote.gen4.fill"];
    }
    
    UIImageView *iconView = [[UIImageView alloc] initWithImage:logoImg];
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    iconView.layer.cornerRadius = 20.0;
    iconView.layer.masksToBounds = YES;
    iconView.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.18].CGColor;
    iconView.layer.borderWidth = 1.0;
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    [iconGlowContainer addSubview:iconView];
    
    // 应用名称
    NSDictionary *infoDict = [[NSBundle mainBundle] infoDictionary];
    NSString *appName = [infoDict objectForKey:@"CFBundleDisplayName"] ?: [infoDict objectForKey:@"CFBundleName"] ?: @"糖葫芦遥控器";
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = appName;
    titleLabel.font = [UIFont systemFontOfSize:22 weight:UIFontWeightBold];
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [heroView addSubview:titleLabel];
    
    // 品牌 Slogan
    UILabel *sloganLabel = [[UILabel alloc] init];
    sloganLabel.text = L(@"Smart Touch & Presentation Remote for Apple TV", @"专为大屏与 Apple TV 打造的智能触控助手");
    sloganLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    sloganLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.65];
    sloganLabel.textAlignment = NSTextAlignmentCenter;
    sloganLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [heroView addSubview:sloganLabel];
    
    // 版本 Badge 胶囊
    NSString *appVersion = [infoDict objectForKey:@"CFBundleShortVersionString"] ?: @"1.0.0";
    NSString *buildNum = [infoDict objectForKey:@"CFBundleVersion"] ?: @"1";
    
    UIView *badgeView = [[UIView alloc] init];
    badgeView.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.06];
    badgeView.layer.cornerRadius = 13.0;
    badgeView.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.12].CGColor;
    badgeView.layer.borderWidth = 0.8;
    badgeView.translatesAutoresizingMaskIntoConstraints = NO;
    
    self.versionBadgeLabel = [[UILabel alloc] init];
    self.versionBadgeLabel.text = [NSString stringWithFormat:@"Version %@ (%@)", appVersion, buildNum];
    self.versionBadgeLabel.font = [UIFont monospacedDigitSystemFontOfSize:12 weight:UIFontWeightMedium];
    self.versionBadgeLabel.textColor = [HSBThemeManager tanghuluBrandColor];
    self.versionBadgeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [badgeView addSubview:self.versionBadgeLabel];
    
    UIImageView *copyIcon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"doc.on.doc" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:10 weight:UIImageSymbolWeightMedium]]];
    copyIcon.tintColor = [HSBThemeManager tanghuluBrandColor];
    copyIcon.translatesAutoresizingMaskIntoConstraints = NO;
    [badgeView addSubview:copyIcon];
    
    UITapGestureRecognizer *badgeTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(didTapVersionBadge)];
    [badgeView addGestureRecognizer:badgeTap];
    badgeView.userInteractionEnabled = YES;
    [heroView addSubview:badgeView];
    
    [NSLayoutConstraint activateConstraints:@[
        [iconGlowContainer.centerXAnchor constraintEqualToAnchor:heroView.centerXAnchor],
        [iconGlowContainer.topAnchor constraintEqualToAnchor:heroView.topAnchor constant:8],
        [iconGlowContainer.widthAnchor constraintEqualToConstant:76],
        [iconGlowContainer.heightAnchor constraintEqualToConstant:76],
        
        [iconView.topAnchor constraintEqualToAnchor:iconGlowContainer.topAnchor],
        [iconView.leadingAnchor constraintEqualToAnchor:iconGlowContainer.leadingAnchor],
        [iconView.trailingAnchor constraintEqualToAnchor:iconGlowContainer.trailingAnchor],
        [iconView.bottomAnchor constraintEqualToAnchor:iconGlowContainer.bottomAnchor],
        
        [titleLabel.centerXAnchor constraintEqualToAnchor:heroView.centerXAnchor],
        [titleLabel.topAnchor constraintEqualToAnchor:iconGlowContainer.bottomAnchor constant:14],
        
        [sloganLabel.centerXAnchor constraintEqualToAnchor:heroView.centerXAnchor],
        [sloganLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:5],
        [sloganLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:heroView.leadingAnchor constant:16],
        [sloganLabel.trailingAnchor constraintLessThanOrEqualToAnchor:heroView.trailingAnchor constant:-16],
        
        [badgeView.centerXAnchor constraintEqualToAnchor:heroView.centerXAnchor],
        [badgeView.topAnchor constraintEqualToAnchor:sloganLabel.bottomAnchor constant:10],
        [badgeView.bottomAnchor constraintEqualToAnchor:heroView.bottomAnchor constant:-8],
        [badgeView.heightAnchor constraintEqualToConstant:26],
        
        [self.versionBadgeLabel.leadingAnchor constraintEqualToAnchor:badgeView.leadingAnchor constant:12],
        [self.versionBadgeLabel.centerYAnchor constraintEqualToAnchor:badgeView.centerYAnchor],
        
        [copyIcon.leadingAnchor constraintEqualToAnchor:self.versionBadgeLabel.trailingAnchor constant:6],
        [copyIcon.trailingAnchor constraintEqualToAnchor:badgeView.trailingAnchor constant:-10],
        [copyIcon.centerYAnchor constraintEqualToAnchor:badgeView.centerYAnchor]
    ]];
    
    [self.contentStackView addArrangedSubview:heroView];
}

#pragma mark - 2. 核心特性卡片

- (void)setupFeaturesCard {
    UIView *card = [self createCardContainer];
    
    UILabel *headerLabel = [self createCardHeaderLabel:L(@" CORE CAPABILITIES", @" 核心功能特性")];
    [card addSubview:headerLabel];
    
    NSArray *features = @[
        @{
            @"icon": @"appletvremote.gen4.fill",
            @"title": L(@"Multi-Scenario Remote Suite", @"多场景智能遥控矩阵"),
            @"desc": L(@"D-Pad navigation, media controls, IPTV channel tuning, and presentation laser pointer.", @"集成 Apple TV 原生轮盘导航、大屏媒体流控、IPTV 极速换台与演讲激光笔涂鸦。")
        },
        @{
            @"icon": @"bolt.horizontal.fill",
            @"title": L(@"Dual-Protocol Self-Healing", @"双模协同自愈传输"),
            @"desc": L(@"Seamlessly blends zero-latency Bonjour LAN socket with native system control.", @"结合 Bonjour 局域网高速广播、TCP Socket 与系统底层指令通道，毫秒级响应。")
        },
        @{
            @"icon": @"keyboard.fill",
            @"title": L(@"Real-Time Text Sync (RTI)", @"RTI 实时原子输入同步"),
            @"desc": L(@"Native keyboard input synchronization eliminates tedious letter picking on TV.", @"手机端无缝中文拼音输入与回车上屏，彻底告别在电视屏幕逐字移选的繁琐。")
        },
        @{
            @"icon": @"sparkles.tv.fill",
            @"title": L(@"On-Device Local AI", @"端侧智能大模型管家"),
            @"desc": L(@"Integrated offline LLM assistant for intelligent voice and TV interaction control.", @"内嵌端侧离线大模型，支持自然语言电视操控问答与智能助手联动。")
        }
    ];
    
    UIStackView *itemStack = [[UIStackView alloc] init];
    itemStack.axis = UILayoutConstraintAxisVertical;
    itemStack.spacing = 14.0;
    itemStack.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:itemStack];
    
    for (NSDictionary *dict in features) {
        UIView *row = [self createFeatureRowWithIcon:dict[@"icon"] title:dict[@"title"] desc:dict[@"desc"]];
        [itemStack addArrangedSubview:row];
    }
    
    [NSLayoutConstraint activateConstraints:@[
        [headerLabel.topAnchor constraintEqualToAnchor:card.topAnchor constant:14],
        [headerLabel.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [headerLabel.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16],
        
        [itemStack.topAnchor constraintEqualToAnchor:headerLabel.bottomAnchor constant:14],
        [itemStack.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [itemStack.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16],
        [itemStack.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-16]
    ]];
    
    [self.contentStackView addArrangedSubview:card];
}

- (UIView *)createFeatureRowWithIcon:(NSString *)iconName title:(NSString *)title desc:(NSString *)desc {
    UIView *view = [[UIView alloc] init];
    
    UIView *iconBg = [[UIView alloc] init];
    iconBg.backgroundColor = [[HSBThemeManager tanghuluBrandColor] colorWithAlphaComponent:0.15];
    iconBg.layer.cornerRadius = 10.0;
    iconBg.translatesAutoresizingMaskIntoConstraints = NO;
    [view addSubview:iconBg];
    
    UIImageView *iconView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:iconName withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:16 weight:UIImageSymbolWeightSemibold]]];
    iconView.tintColor = [HSBThemeManager tanghuluBrandColor];
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    [iconBg addSubview:iconView];
    
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = title;
    titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [view addSubview:titleLabel];
    
    UILabel *descLabel = [[UILabel alloc] init];
    descLabel.text = desc;
    descLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
    descLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.62];
    descLabel.numberOfLines = 0;
    descLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [view addSubview:descLabel];
    
    [NSLayoutConstraint activateConstraints:@[
        [iconBg.leadingAnchor constraintEqualToAnchor:view.leadingAnchor],
        [iconBg.topAnchor constraintEqualToAnchor:view.topAnchor constant:2],
        [iconBg.widthAnchor constraintEqualToConstant:34],
        [iconBg.heightAnchor constraintEqualToConstant:34],
        
        [iconView.centerXAnchor constraintEqualToAnchor:iconBg.centerXAnchor],
        [iconView.centerYAnchor constraintEqualToAnchor:iconBg.centerYAnchor],
        
        [titleLabel.leadingAnchor constraintEqualToAnchor:iconBg.trailingAnchor constant:12],
        [titleLabel.topAnchor constraintEqualToAnchor:view.topAnchor],
        [titleLabel.trailingAnchor constraintEqualToAnchor:view.trailingAnchor],
        
        [descLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [descLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:3],
        [descLabel.trailingAnchor constraintEqualToAnchor:view.trailingAnchor],
        [descLabel.bottomAnchor constraintEqualToAnchor:view.bottomAnchor]
    ]];
    
    return view;
}

#pragma mark - 3. 生态矩阵卡片

- (void)setupEcosystemCard {
    UIView *card = [self createCardContainer];
    
    UILabel *headerLabel = [self createCardHeaderLabel:L(@"ECOSYSTEM CONNECTIVITY", @"大屏生态协同")];
    [card addSubview:headerLabel];
    
    NSArray *ecosystems = @[
        @{@"platform": L(@"Apple TV App", @"Apple TV 大屏端"), @"app": @"HSBBrowser for tvOS", @"icon": @"tv"},
        @{@"platform": L(@"macOS Desktop", @"Mac 桌面协同端"), @"app": @"itsytv for macOS", @"icon": @"macmini"},
        @{@"platform": L(@"Apple Watch", @"穿戴设备协同引擎"), @"app": @"ZE Watch Motion Hub", @"icon": @"applewatch"}
    ];
    
    UIStackView *stack = [[UIStackView alloc] init];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 10.0;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:stack];
    
    for (NSDictionary *dict in ecosystems) {
        UIView *row = [[UIView alloc] init];
        
        UIImageView *iconView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:dict[@"icon"] withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightMedium]]];
        iconView.tintColor = [HSBThemeManager tanghuluBrandColor];
        iconView.translatesAutoresizingMaskIntoConstraints = NO;
        [row addSubview:iconView];
        
        UILabel *platformLabel = [[UILabel alloc] init];
        platformLabel.text = dict[@"platform"];
        platformLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
        platformLabel.textColor = [UIColor whiteColor];
        platformLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [row addSubview:platformLabel];
        
        UILabel *appLabel = [[UILabel alloc] init];
        appLabel.text = dict[@"app"];
        appLabel.font = [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular];
        appLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.55];
        appLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [row addSubview:appLabel];
        
        [NSLayoutConstraint activateConstraints:@[
            [row.heightAnchor constraintEqualToConstant:28],
            
            [iconView.leadingAnchor constraintEqualToAnchor:row.leadingAnchor],
            [iconView.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
            [iconView.widthAnchor constraintEqualToConstant:20],
            
            [platformLabel.leadingAnchor constraintEqualToAnchor:iconView.trailingAnchor constant:10],
            [platformLabel.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
            
            [appLabel.trailingAnchor constraintEqualToAnchor:row.trailingAnchor],
            [appLabel.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
            [appLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:platformLabel.trailingAnchor constant:8]
        ]];
        
        [stack addArrangedSubview:row];
    }
    
    [NSLayoutConstraint activateConstraints:@[
        [headerLabel.topAnchor constraintEqualToAnchor:card.topAnchor constant:14],
        [headerLabel.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [headerLabel.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16],
        
        [stack.topAnchor constraintEqualToAnchor:headerLabel.bottomAnchor constant:12],
        [stack.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [stack.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16],
        [stack.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-16]
    ]];
    
    [self.contentStackView addArrangedSubview:card];
}

#pragma mark - 4. 快捷操作与支持卡片

- (void)setupActionsCard {
    UIView *card = [self createCardContainer];
    
    UILabel *headerLabel = [self createCardHeaderLabel:L(@"RESOURCES & LEGAL", @"资源与支持")];
    [card addSubview:headerLabel];
    
    NSArray *actions = @[
        @{@"title": L(@"Privacy Policy", @"隐私政策"), @"icon": @"hand.raised.fill", @"sel": NSStringFromSelector(@selector(openPrivacyPolicy))},
        @{@"title": L(@"Open Source Licenses", @"第三方开源许可"), @"icon": @"shippingbox.fill", @"sel": NSStringFromSelector(@selector(openOpenSourceLicenses))},
        @{@"title": L(@"Contact Us & Feedback", @"联系我们与支持反馈"), @"icon": @"envelope.fill", @"sel": NSStringFromSelector(@selector(openContactUs))},
        @{@"title": L(@"Rate on App Store", @"在 App Store 给我们好评"), @"icon": @"star.fill", @"sel": NSStringFromSelector(@selector(rateOnAppStore))}
    ];
    
    UIStackView *stack = [[UIStackView alloc] init];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 2.0;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:stack];
    
    for (NSInteger i = 0; i < actions.count; i++) {
        NSDictionary *dict = actions[i];
        UIButton *btn = [self createActionButtonWithTitle:dict[@"title"] icon:dict[@"icon"] selector:NSSelectorFromString(dict[@"sel"]) isLast:(i == actions.count - 1)];
        [stack addArrangedSubview:btn];
    }
    
    [NSLayoutConstraint activateConstraints:@[
        [headerLabel.topAnchor constraintEqualToAnchor:card.topAnchor constant:14],
        [headerLabel.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [headerLabel.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16],
        
        [stack.topAnchor constraintEqualToAnchor:headerLabel.bottomAnchor constant:8],
        [stack.leadingAnchor constraintEqualToAnchor:card.leadingAnchor],
        [stack.trailingAnchor constraintEqualToAnchor:card.trailingAnchor],
        [stack.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-8]
    ]];
    
    [self.contentStackView addArrangedSubview:card];
}

- (UIButton *)createActionButtonWithTitle:(NSString *)title icon:(NSString *)iconName selector:(SEL)selector isLast:(BOOL)isLast {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    btn.translatesAutoresizingMaskIntoConstraints = NO;
    [btn addTarget:self action:selector forControlEvents:UIControlEventTouchUpInside];
    
    UIImageView *iconView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:iconName withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:15 weight:UIImageSymbolWeightMedium]]];
    iconView.tintColor = [HSBThemeManager tanghuluBrandColor];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    [btn addSubview:iconView];
    
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = title;
    titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [btn addSubview:titleLabel];
    
    UIImageView *chevron = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"chevron.right" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:12 weight:UIImageSymbolWeightSemibold]]];
    chevron.tintColor = [[UIColor whiteColor] colorWithAlphaComponent:0.3];
    chevron.translatesAutoresizingMaskIntoConstraints = NO;
    [btn addSubview:chevron];
    
    UIView *divider = [[UIView alloc] init];
    divider.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.06];
    divider.translatesAutoresizingMaskIntoConstraints = NO;
    divider.hidden = isLast;
    [btn addSubview:divider];
    
    [NSLayoutConstraint activateConstraints:@[
        [btn.heightAnchor constraintEqualToConstant:46],
        
        [iconView.leadingAnchor constraintEqualToAnchor:btn.leadingAnchor constant:16],
        [iconView.centerYAnchor constraintEqualToAnchor:btn.centerYAnchor],
        [iconView.widthAnchor constraintEqualToConstant:20],
        
        [titleLabel.leadingAnchor constraintEqualToAnchor:iconView.trailingAnchor constant:12],
        [titleLabel.centerYAnchor constraintEqualToAnchor:btn.centerYAnchor],
        
        [chevron.trailingAnchor constraintEqualToAnchor:btn.trailingAnchor constant:-16],
        [chevron.centerYAnchor constraintEqualToAnchor:btn.centerYAnchor],
        
        [divider.leadingAnchor constraintEqualToAnchor:btn.leadingAnchor constant:48],
        [divider.trailingAnchor constraintEqualToAnchor:btn.trailingAnchor constant:-16],
        [divider.bottomAnchor constraintEqualToAnchor:btn.bottomAnchor],
        [divider.heightAnchor constraintEqualToConstant:0.5]
    ]];
    
    return btn;
}

#pragma mark - 5. 底部版权信息

- (void)setupFooter {
    UIView *footerView = [[UIView alloc] init];
    footerView.translatesAutoresizingMaskIntoConstraints = NO;
    
    UILabel *crLabel = [[UILabel alloc] init];
    crLabel.text = @"Copyright © 2026 Never88gone. All rights reserved.";
    crLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightRegular];
    crLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.4];
    crLabel.textAlignment = NSTextAlignmentCenter;
    crLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [footerView addSubview:crLabel];
    
    UILabel *loveLabel = [[UILabel alloc] init];
    loveLabel.text = L(@"Crafted with Passion for Seamless Screen Control", @"精雕细琢 · 专注流畅纯粹的大屏遥控");
    loveLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
    loveLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.3];
    loveLabel.textAlignment = NSTextAlignmentCenter;
    loveLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [footerView addSubview:loveLabel];
    
    [NSLayoutConstraint activateConstraints:@[
        [crLabel.topAnchor constraintEqualToAnchor:footerView.topAnchor constant:12],
        [crLabel.centerXAnchor constraintEqualToAnchor:footerView.centerXAnchor],
        
        [loveLabel.topAnchor constraintEqualToAnchor:crLabel.bottomAnchor constant:4],
        [loveLabel.centerXAnchor constraintEqualToAnchor:footerView.centerXAnchor],
        [loveLabel.bottomAnchor constraintEqualToAnchor:footerView.bottomAnchor constant:-8]
    ]];
    
    [self.contentStackView addArrangedSubview:footerView];
}

#pragma mark - 通用卡片构建辅助

- (UIView *)createCardContainer {
    UIView *card = [[UIView alloc] init];
    card.layer.cornerRadius = 16.0;
    card.layer.masksToBounds = YES;
    card.translatesAutoresizingMaskIntoConstraints = NO;
    [self.themeCards addObject:card];
    return card;
}

- (UILabel *)createCardHeaderLabel:(NSString *)text {
    UILabel *l = [[UILabel alloc] init];
    l.text = [text uppercaseString];
    l.font = [UIFont systemFontOfSize:11 weight:UIFontWeightBold];
    l.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.55];
    l.translatesAutoresizingMaskIntoConstraints = NO;
    return l;
}

- (void)applyThemeStyle {
    [super applyThemeStyle];
    HSBThemePalette *palette = [HSBThemeManager shared].currentPalette;
    
    for (UIView *card in self.themeCards) {
        card.backgroundColor = palette.cardBgColor;
        card.layer.borderColor = [palette.primaryColor colorWithAlphaComponent:0.15].CGColor;
        card.layer.borderWidth = 1.0;
    }
}

#pragma mark - 交互动作

- (void)didTapVersionBadge {
    UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [feedback impactOccurred];
    
    NSDictionary *infoDict = [[NSBundle mainBundle] infoDictionary];
    NSString *appVersion = [infoDict objectForKey:@"CFBundleShortVersionString"] ?: @"1.0.0";
    NSString *buildNum = [infoDict objectForKey:@"CFBundleVersion"] ?: @"1";
    NSString *verStr = [NSString stringWithFormat:@"Version %@ (%@)", appVersion, buildNum];
    [UIPasteboard generalPasteboard].string = verStr;
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:L(@"Version Copied", @"已复制版本号") message:verStr preferredStyle:UIAlertControllerStyleAlert];
    [self presentViewController:alert animated:YES completion:^{
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [alert dismissViewControllerAnimated:YES completion:nil];
        });
    }];
}

- (void)openPrivacyPolicy {
    UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [feedback impactOccurred];
    
    HSBBaseViewController *vc = [[HSBBaseViewController alloc] init];
    vc.title = L(@"Privacy Policy", @"隐私政策");
    
    UITextView *tv = [[UITextView alloc] initWithFrame:vc.view.bounds];
    tv.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    tv.editable = NO;
    tv.backgroundColor = [UIColor clearColor];
    tv.textColor = [UIColor whiteColor];
    tv.font = [UIFont systemFontOfSize:15];
    tv.textContainerInset = UIEdgeInsetsMake(20, 20, 20, 20);
    tv.text = L(@"Tanghulu Remote Privacy Policy\n\n1. Data Collection & Usage\nThis app operates as a remote control and motion tracker companion. We solemnly promise that this app does NOT collect, store, or upload any of your personal identifiable information.\nAll control communications are transmitted directly between your devices over your local area network.\n\n2. Permissions Description\n- Local Network: Used strictly to discover and connect to smart TV or large display devices within your local network.\n- Motion & Fitness: Used for calculating motion gestures and local step counting.\n\n3. Information Sharing\nWe do not share any data with third parties. All processing is handled locally on-device.\n\n4. Contact Us\nIf you have any questions, please contact developer support.",
                @"糖葫芦遥控器（Tanghulu Remote）隐私政策\n\n1. 数据收集与使用\n本应用主要作为外围设备的遥控和体感数据采集工具。我们郑重承诺，本应用不会收集、存储或上传您的任何个人身份信息与隐私。\n所有的控制通信（如控制指令）仅在您的本地局域网内进行设备间的直接传输。\n\n2. 权限说明\n- 本地网络权限：仅用于发现并连接局域网内的智能电视或大屏设备。\n- 运动与健身权限：仅用于体感手势判定与本地步数统计。\n\n3. 信息共享\n我们不会与任何第三方分享您的数据，所有数据均只在本地实时处理。\n\n4. 联系我们\n如有任何问题，可联系官方开发者支持。");
    
    [vc.view addSubview:tv];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)openOpenSourceLicenses {
    UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [feedback impactOccurred];
    
    HSBOpenSourceLibrariesViewController *vc = [[HSBOpenSourceLibrariesViewController alloc] init];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)openContactUs {
    UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [feedback impactOccurred];
    
    HSBContactUsViewController *vc = [[HSBContactUsViewController alloc] init];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)rateOnAppStore {
    UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [feedback impactOccurred];
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:L(@"Thank You", @"感谢您的支持！") message:L(@"Your high rating and feedback empower us to make Tanghulu Remote even better for everyone.", @"您的每一个五星好评与诚恳建议，都是我们不断打磨极致大屏控制体验的最大动力。") preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:L(@"I Love It!", @"必须好评 ⭐️⭐️⭐️⭐️⭐️") style:UIAlertActionStyleDefault handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:L(@"Later", @"稍后") style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
