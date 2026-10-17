//
//  HSBHomeStatusCardsView.m
//  HSBWatchCompanion
//

#import "HSBHomeStatusCardsView.h"

static inline NSString * L(NSString *en, NSString *zh) {
    NSString *language = [[NSLocale preferredLanguages] firstObject];
    if ([language hasPrefix:@"zh"]) {
        return zh ?: en;
    }
    return en;
}

@interface HSBHomeStatusCardsView ()

@property (nonatomic, strong) UILabel *watchStatusLabel;
@property (nonatomic, strong) UILabel *tvStatusLabel;
@property (nonatomic, strong) UILabel *logLabel;
@property (nonatomic, strong, readwrite) UISwitch *watchSyncSwitch;
@property (nonatomic, strong, readwrite) UISwitch *tvScanSwitch;
@property (nonatomic, strong) NSMutableArray<UIView *> *mutableCardViews;

@end

@implementation HSBHomeStatusCardsView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _mutableCardViews = [NSMutableArray array];
        [self setupSubviews];
    }
    return self;
}

- (NSArray<UIView *> *)cardViews {
    return [self.mutableCardViews copy];
}

- (void)setupSubviews {
    self.translatesAutoresizingMaskIntoConstraints = NO;
    
    self.watchStatusLabel = [self createLabel];
    self.tvStatusLabel = [self createLabel];
    self.logLabel = [self createLabel];
    
    self.watchSyncSwitch = [[UISwitch alloc] init];
    self.watchSyncSwitch.translatesAutoresizingMaskIntoConstraints = NO;
    [self.watchSyncSwitch setOn:YES animated:NO];
    [self.watchSyncSwitch addTarget:self action:@selector(handleWatchSyncChanged:) forControlEvents:UIControlEventValueChanged];
    
    self.tvScanSwitch = [[UISwitch alloc] init];
    self.tvScanSwitch.translatesAutoresizingMaskIntoConstraints = NO;
    [self.tvScanSwitch setOn:YES animated:NO];
    [self.tvScanSwitch addTarget:self action:@selector(handleTVScanChanged:) forControlEvents:UIControlEventValueChanged];
    
    UIView *card1 = [self createCard:L(@" WATCH SYNC ENGINE", @" 穿戴设备运动同步引擎") valueLabel:self.watchStatusLabel switchView:self.watchSyncSwitch];
    UIView *card2 = [self createCard:L(@" APPLE TV HARDWARE LINK", @" Apple TV 硬件设备直连") valueLabel:self.tvStatusLabel switchView:self.tvScanSwitch];
    UITapGestureRecognizer *tvCardTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTVCardTapped)];
    [card2 addGestureRecognizer:tvCardTap];
    card2.userInteractionEnabled = YES;
    
    UIView *card3 = [self createCard:L(@"LATEST DETECTED ACTION", @"最终判定体感动作") valueLabel:self.logLabel switchView:nil];
    
    self.watchStatusLabel.text = L(@"🟡 Connecting...", @"🟡 获取 Apple Watch 状态中...");
    self.tvStatusLabel.text = L(@"⚪️ Hardware Idle", @"⚪️ 未连接 Apple TV 硬件");
    self.logLabel.text = L(@"Waiting for gestures...", @"等待进行体感动作...");
    self.logLabel.textColor = [UIColor tertiaryLabelColor];
    
    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[card1, card2, card3]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 6;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:stack];
    
    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:self.topAnchor],
        [stack.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [stack.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [stack.bottomAnchor constraintEqualToAnchor:self.bottomAnchor]
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
    [self.mutableCardViews addObject:view];
    
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

- (void)handleWatchSyncChanged:(UISwitch *)sender {
    if (self.onWatchSyncChanged) {
        self.onWatchSyncChanged(sender.isOn);
    }
}

- (void)handleTVScanChanged:(UISwitch *)sender {
    if (self.onTVScanChanged) {
        self.onTVScanChanged(sender.isOn);
    }
}

- (void)handleTVCardTapped {
    if (self.onTVCardTapped) {
        self.onTVCardTapped();
    }
}

- (void)updateWatchStatusText:(NSString *)text color:(nullable UIColor *)color {
    self.watchStatusLabel.text = text;
    if (color) {
        self.watchStatusLabel.textColor = color;
    }
}

- (void)updateTVStatusText:(NSString *)text color:(nullable UIColor *)color {
    self.tvStatusLabel.text = text;
    if (color) {
        self.tvStatusLabel.textColor = color;
    }
}

- (void)updateActionLogText:(NSString *)text {
    self.logLabel.text = text;
    self.logLabel.textColor = [UIColor whiteColor];
}

- (void)applyThemePrimaryColor:(UIColor *)primaryColor {
    self.watchSyncSwitch.onTintColor = primaryColor;
    self.tvScanSwitch.onTintColor = primaryColor;
}

@end
