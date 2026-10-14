//
//  HSBAboutViewController.m
//  HSBWatchCompanion
//

#import "HSBAboutViewController.h"
#import "HSBThemeManager.h"

static inline NSString * L(NSString *en, NSString *zh) {
    NSString *language = [[NSLocale preferredLanguages] firstObject];
    if ([language hasPrefix:@"zh"]) {
        return zh ?: en;
    }
    return en;
}

@interface HSBAboutViewController ()

@property (nonatomic, strong) UIView *iconGlowContainer;
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIView *badgeView;
@property (nonatomic, strong) UILabel *versionBadgeLabel;
@property (nonatomic, strong) UIImageView *docIconView;
@property (nonatomic, strong) UILabel *copyrightLabel;

@end

@implementation HSBAboutViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = L(@"About", @"关于");
    
    [self setupMinimalViews];
    [self applyThemeStyle];
}

- (void)setupMinimalViews {
    // 居中内容容器
    UIView *centerContainer = [[UIView alloc] init];
    centerContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:centerContainer];
    
    // 1. 图标容器与外发光
    self.iconGlowContainer = [[UIView alloc] init];
    self.iconGlowContainer.backgroundColor = [UIColor clearColor];
    self.iconGlowContainer.layer.shadowColor = [HSBThemeManager tanghuluBrandColor].CGColor;
    self.iconGlowContainer.layer.shadowRadius = 18.0;
    self.iconGlowContainer.layer.shadowOpacity = 0.45;
    self.iconGlowContainer.layer.shadowOffset = CGSizeMake(0, 8);
    self.iconGlowContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [centerContainer addSubview:self.iconGlowContainer];
    
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
    
    self.iconView = [[UIImageView alloc] initWithImage:logoImg];
    self.iconView.contentMode = UIViewContentModeScaleAspectFit;
    self.iconView.layer.cornerRadius = 24.0;
    self.iconView.layer.masksToBounds = YES;
    self.iconView.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.18].CGColor;
    self.iconView.layer.borderWidth = 1.0;
    self.iconView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.iconGlowContainer addSubview:self.iconView];
    
    // 2. 应用名称
    NSDictionary *infoDict = [[NSBundle mainBundle] infoDictionary];
    NSString *appName = [infoDict objectForKey:@"CFBundleDisplayName"] ?: [infoDict objectForKey:@"CFBundleName"] ?: @"糖葫芦遥控器";
    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.text = appName;
    self.titleLabel.font = [UIFont systemFontOfSize:24 weight:UIFontWeightBold];
    self.titleLabel.textColor = [UIColor whiteColor];
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [centerContainer addSubview:self.titleLabel];
    
    // 3. 版本 Badge 胶囊
    NSString *appVersion = [infoDict objectForKey:@"CFBundleShortVersionString"] ?: @"1.0.0";
    NSString *buildNum = [infoDict objectForKey:@"CFBundleVersion"] ?: @"1";
    
    self.badgeView = [[UIView alloc] init];
    self.badgeView.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.06];
    self.badgeView.layer.cornerRadius = 15.0;
    self.badgeView.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.12].CGColor;
    self.badgeView.layer.borderWidth = 0.8;
    self.badgeView.translatesAutoresizingMaskIntoConstraints = NO;
    
    self.versionBadgeLabel = [[UILabel alloc] init];
    self.versionBadgeLabel.text = [NSString stringWithFormat:@"Version %@ (%@)", appVersion, buildNum];
    self.versionBadgeLabel.font = [UIFont monospacedDigitSystemFontOfSize:13 weight:UIFontWeightMedium];
    self.versionBadgeLabel.textColor = [HSBThemeManager tanghuluBrandColor];
    self.versionBadgeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.badgeView addSubview:self.versionBadgeLabel];
    
    self.docIconView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"doc.on.doc" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:11 weight:UIImageSymbolWeightMedium]]];
    self.docIconView.tintColor = [HSBThemeManager tanghuluBrandColor];
    self.docIconView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.badgeView addSubview:self.docIconView];
    
    UITapGestureRecognizer *badgeTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(didTapVersionBadge)];
    [self.badgeView addGestureRecognizer:badgeTap];
    self.badgeView.userInteractionEnabled = YES;
    [centerContainer addSubview:self.badgeView];
    
    // 4. 底部版权文字
    self.copyrightLabel = [[UILabel alloc] init];
    self.copyrightLabel.text = @"Copyright © 2026 Never88gone. All rights reserved.";
    self.copyrightLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
    self.copyrightLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.35];
    self.copyrightLabel.textAlignment = NSTextAlignmentCenter;
    self.copyrightLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.copyrightLabel];
    
    // 布局约束
    [NSLayoutConstraint activateConstraints:@[
        // 居中容器垂直居中偏上，视觉黄金比例
        [centerContainer.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [centerContainer.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:-40],
        [centerContainer.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.view.leadingAnchor constant:24],
        [centerContainer.trailingAnchor constraintLessThanOrEqualToAnchor:self.view.trailingAnchor constant:-24],
        
        // 图标
        [self.iconGlowContainer.topAnchor constraintEqualToAnchor:centerContainer.topAnchor],
        [self.iconGlowContainer.centerXAnchor constraintEqualToAnchor:centerContainer.centerXAnchor],
        [self.iconGlowContainer.widthAnchor constraintEqualToConstant:96],
        [self.iconGlowContainer.heightAnchor constraintEqualToConstant:96],
        
        [self.iconView.topAnchor constraintEqualToAnchor:self.iconGlowContainer.topAnchor],
        [self.iconView.leadingAnchor constraintEqualToAnchor:self.iconGlowContainer.leadingAnchor],
        [self.iconView.trailingAnchor constraintEqualToAnchor:self.iconGlowContainer.trailingAnchor],
        [self.iconView.bottomAnchor constraintEqualToAnchor:self.iconGlowContainer.bottomAnchor],
        
        // 应用名称
        [self.titleLabel.topAnchor constraintEqualToAnchor:self.iconGlowContainer.bottomAnchor constant:20],
        [self.titleLabel.centerXAnchor constraintEqualToAnchor:centerContainer.centerXAnchor],
        
        // 版本胶囊
        [self.badgeView.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:14],
        [self.badgeView.centerXAnchor constraintEqualToAnchor:centerContainer.centerXAnchor],
        [self.badgeView.bottomAnchor constraintEqualToAnchor:centerContainer.bottomAnchor],
        [self.badgeView.heightAnchor constraintEqualToConstant:30],
        
        [self.versionBadgeLabel.leadingAnchor constraintEqualToAnchor:self.badgeView.leadingAnchor constant:14],
        [self.versionBadgeLabel.centerYAnchor constraintEqualToAnchor:self.badgeView.centerYAnchor],
        
        [self.docIconView.leadingAnchor constraintEqualToAnchor:self.versionBadgeLabel.trailingAnchor constant:6],
        [self.docIconView.trailingAnchor constraintEqualToAnchor:self.badgeView.trailingAnchor constant:-12],
        [self.docIconView.centerYAnchor constraintEqualToAnchor:self.badgeView.centerYAnchor],
        
        // 底部版权
        [self.copyrightLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.copyrightLabel.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-20]
    ]];
}

- (void)applyThemeStyle {
    [super applyThemeStyle];
    HSBThemePalette *palette = [HSBThemeManager shared].currentPalette;
    
    self.iconGlowContainer.layer.shadowColor = palette.primaryColor.CGColor;
    self.versionBadgeLabel.textColor = palette.primaryColor;
    self.docIconView.tintColor = palette.primaryColor;
    self.badgeView.layer.borderColor = [palette.primaryColor colorWithAlphaComponent:0.25].CGColor;
    self.badgeView.backgroundColor = [palette.primaryColor colorWithAlphaComponent:0.08];
}

- (void)didTapVersionBadge {
    UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [feedback impactOccurred];
    
    NSDictionary *infoDict = [[NSBundle mainBundle] infoDictionary];
    NSString *appVersion = [infoDict objectForKey:@"CFBundleShortVersionString"] ?: @"1.0.0";
    NSString *buildNum = [infoDict objectForKey:@"CFBundleVersion"] ?: @"1";
    NSString *verStr = [NSString stringWithFormat:@"Version %@ (%@)", appVersion, buildNum];
    [UIPasteboard generalPasteboard].string = verStr;
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:L(@"Version Copied", @"已复制版本号")
                                                                   message:verStr
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [self presentViewController:alert animated:YES completion:^{
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [alert dismissViewControllerAnimated:YES completion:nil];
        });
    }];
}

@end
