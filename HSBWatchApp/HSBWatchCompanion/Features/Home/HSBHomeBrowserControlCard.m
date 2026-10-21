//
//  HSBHomeBrowserControlCard.m
//  HSBWatchCompanion
//

#import "HSBHomeBrowserControlCard.h"

@interface HSBHomeBrowserControlCard ()

@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIButton *openRemoteButton;
@property (nonatomic, strong) UIButton *editConfigButton;

@end

@implementation HSBHomeBrowserControlCard

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupSubviews];
    }
    return self;
}

- (void)setupSubviews {
    self.backgroundColor = [UIColor secondarySystemBackgroundColor];
    self.layer.cornerRadius = 16;
    self.translatesAutoresizingMaskIntoConstraints = NO;
    
    self.layer.shadowColor = [UIColor blackColor].CGColor;
    self.layer.shadowOpacity = 0.05;
    self.layer.shadowOffset = CGSizeMake(0, 4);
    self.layer.shadowRadius = 8;
    
    NSString *language = [[NSLocale preferredLanguages] firstObject];
    BOOL isZH = [language hasPrefix:@"zh"];
    
    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.text = isZH ? @"网页浏览器控制" : @"BROWSER CONTROLS";
    self.titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightBold];
    self.titleLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.6];
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.titleLabel];
    
    self.openRemoteButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.openRemoteButton setTitle:isZH ? @"打开全屏触控板界面" : @"Open Fullscreen Trackpad" forState:UIControlStateNormal];
    self.openRemoteButton.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    [self.openRemoteButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.openRemoteButton.layer.cornerRadius = 12;
    [self.openRemoteButton addTarget:self action:@selector(handleOpenRemoteTapped) forControlEvents:UIControlEventTouchUpInside];
    self.openRemoteButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.openRemoteButton];
    
    self.editConfigButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.editConfigButton setTitle:isZH ? @"编辑主页配置" : @"Edit Home Config" forState:UIControlStateNormal];
    self.editConfigButton.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    self.editConfigButton.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.06];
    [self.editConfigButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.editConfigButton.tintColor = [UIColor whiteColor];
    self.editConfigButton.layer.cornerRadius = 12;
    [self.editConfigButton addTarget:self action:@selector(handleEditConfigTapped) forControlEvents:UIControlEventTouchUpInside];
    self.editConfigButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.editConfigButton];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.titleLabel.topAnchor constraintEqualToAnchor:self.topAnchor constant:16],
        [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:20],
        [self.titleLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-20],
        
        [self.openRemoteButton.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:14],
        [self.openRemoteButton.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:20],
        [self.openRemoteButton.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-20],
        [self.openRemoteButton.heightAnchor constraintEqualToConstant:50],
        
        [self.editConfigButton.topAnchor constraintEqualToAnchor:self.openRemoteButton.bottomAnchor constant:10],
        [self.editConfigButton.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:20],
        [self.editConfigButton.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-20],
        [self.editConfigButton.heightAnchor constraintEqualToConstant:44],
        [self.editConfigButton.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-16]
    ]];
}

- (void)handleOpenRemoteTapped {
    if (self.onOpenRemoteRequested) {
        self.onOpenRemoteRequested();
    }
}

- (void)handleEditConfigTapped {
    if (self.onEditHomeConfigRequested) {
        self.onEditHomeConfigRequested();
    }
}

- (void)applyThemePrimaryColor:(UIColor *)color {
    self.openRemoteButton.backgroundColor = color;
}

@end
