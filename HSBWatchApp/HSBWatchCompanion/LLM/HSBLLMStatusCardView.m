#import "HSBLLMStatusCardView.h"
#import "HSBLocalLLMManager.h"
#import "HSBThemeManager.h"

static inline NSString * L(NSString *en, NSString *zh) {
    NSString *language = [[NSLocale preferredLanguages] firstObject];
    if ([language hasPrefix:@"zh"]) {
        return zh ?: en;
    }
    return en;
}

@interface HSBLLMStatusCardView ()

@property (nonatomic, strong) UIView *statusDot;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIButton *goToActivateBtn;

@end

@implementation HSBLLMStatusCardView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupUI];
    }
    return self;
}

- (void)setupUI {
    self.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    self.layer.cornerRadius = 16;
    self.layer.shadowColor = [UIColor blackColor].CGColor;
    self.layer.shadowOpacity = 0.05;
    self.layer.shadowOffset = CGSizeMake(0, 4);
    self.layer.shadowRadius = 8;
    
    _statusDot = [[UIView alloc] init];
    _statusDot.layer.cornerRadius = 6;
    _statusDot.clipsToBounds = YES;
    _statusDot.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:_statusDot];
    
    _statusLabel = [[UILabel alloc] init];
    _statusLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    _statusLabel.textColor = [UIColor labelColor];
    _statusLabel.numberOfLines = 0;
    _statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:_statusLabel];
    
    _goToActivateBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [_goToActivateBtn setTitle:L(@"Go Activate", @"前往激活") forState:UIControlStateNormal];
    _goToActivateBtn.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
    _goToActivateBtn.backgroundColor = [UIColor systemOrangeColor];
    [_goToActivateBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    _goToActivateBtn.layer.cornerRadius = 12;
    _goToActivateBtn.contentEdgeInsets = UIEdgeInsetsMake(6, 12, 6, 12);
    [_goToActivateBtn addTarget:self action:@selector(btnClicked) forControlEvents:UIControlEventTouchUpInside];
    _goToActivateBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:_goToActivateBtn];
    
    [NSLayoutConstraint activateConstraints:@[
        [_statusDot.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:16],
        [_statusDot.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        [_statusDot.widthAnchor constraintEqualToConstant:12],
        [_statusDot.heightAnchor constraintEqualToConstant:12],
        
        [_statusLabel.topAnchor constraintEqualToAnchor:self.topAnchor constant:14],
        [_statusLabel.leadingAnchor constraintEqualToAnchor:_statusDot.trailingAnchor constant:12],
        [_statusLabel.trailingAnchor constraintEqualToAnchor:_goToActivateBtn.leadingAnchor constant:-8],
        [_statusLabel.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-14],
        
        [_goToActivateBtn.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-16],
        [_goToActivateBtn.centerYAnchor constraintEqualToAnchor:self.centerYAnchor]
    ]];
    
    [self updateStatus];
}

- (void)updateStatus {
    HSBLocalLLMModel *activeModel = [HSBLocalLLMManager shared].activeModel;
    self.statusDot.backgroundColor = [UIColor systemGreenColor];
    
    if ([HSBLocalLLMManager useCustomAPI]) {
        self.statusLabel.text = [NSString stringWithFormat:@"已连接自定义 API：%@\n%@", [HSBLocalLLMManager customAPIModel], [HSBLocalLLMManager customAPIEndpoint]];
        self.goToActivateBtn.hidden = NO;
        [self.goToActivateBtn setTitle:@"管理配置" forState:UIControlStateNormal];
    } else if (activeModel && activeModel.isActive) {
        self.statusLabel.text = [NSString stringWithFormat:L(@"Active Model: %@ (MLX Engine)", @"已挂载物理大模型：%@ (MLX 神经网络推理)"), activeModel.name];
        self.goToActivateBtn.hidden = YES;
    } else {
        self.statusLabel.text = L(@"Built-in Smart Engine Ready (Instant)", @"内置端侧智能引擎就绪 (无需下载，秒级响应)");
        self.goToActivateBtn.hidden = NO;
        [self.goToActivateBtn setTitle:L(@"Explore Models", @"探索大模型") forState:UIControlStateNormal];
    }
    
    [self.statusDot.layer removeAllAnimations];
    self.statusDot.alpha = 1.0;
    [UIView animateWithDuration:1.2 delay:0 options:UIViewAnimationOptionAutoreverse | UIViewAnimationOptionRepeat animations:^{
        self.statusDot.alpha = 0.35;
    } completion:nil];
}

- (void)applyThemeStyle {
    HSBThemePalette *palette = [HSBThemeManager shared].currentPalette;
    self.backgroundColor = palette.cardBgColor;
    self.statusLabel.textColor = [UIColor whiteColor];
}

- (void)btnClicked {
    if (self.onActionBtnClicked) {
        self.onActionBtnClicked();
    }
}

@end
