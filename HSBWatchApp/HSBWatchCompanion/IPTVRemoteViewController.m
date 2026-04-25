//
//  IPTVRemoteViewController.m
//  HSBWatchCompanion
//

#import "IPTVRemoteViewController.h"

static inline NSString * L(NSString *en, NSString *zh) {
    NSString *language = [[NSLocale preferredLanguages] firstObject];
    if ([language hasPrefix:@"zh"]) {
        return zh ?: en;
    }
    return en;
}

@interface IPTVRemoteViewController ()
@end

@implementation IPTVRemoteViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    // No title or close button needed — embedded as child VC
    
    // Create D-Pad Container
    UIView *dpadContainer = [[UIView alloc] init];
    dpadContainer.backgroundColor = [UIColor secondarySystemFillColor];
    dpadContainer.layer.cornerRadius = 120;
    dpadContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:dpadContainer];
    
    // Create D-Pad Buttons
    UIButton *upBtn = [self createDPadButtonWithIcon:@"chevron.up" action:@selector(sendUp)];
    UIButton *downBtn = [self createDPadButtonWithIcon:@"chevron.down" action:@selector(sendDown)];
    UIButton *leftBtn = [self createDPadButtonWithIcon:@"chevron.left" action:@selector(sendLeft)];
    UIButton *rightBtn = [self createDPadButtonWithIcon:@"chevron.right" action:@selector(sendRight)];
    UIButton *centerBtn = [self createDPadButtonWithIcon:@"circle.fill" action:@selector(sendSelect)];
    // Make center button pop a bit
    centerBtn.tintColor = [UIColor systemIndigoColor];
    
    [dpadContainer addSubview:upBtn];
    [dpadContainer addSubview:downBtn];
    [dpadContainer addSubview:leftBtn];
    [dpadContainer addSubview:rightBtn];
    [dpadContainer addSubview:centerBtn];
    
    // Layout D-Pad
    [NSLayoutConstraint activateConstraints:@[
        [dpadContainer.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [dpadContainer.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:-30],
        [dpadContainer.widthAnchor constraintEqualToConstant:240],
        [dpadContainer.heightAnchor constraintEqualToConstant:240],
        
        [centerBtn.centerXAnchor constraintEqualToAnchor:dpadContainer.centerXAnchor],
        [centerBtn.centerYAnchor constraintEqualToAnchor:dpadContainer.centerYAnchor],
        [centerBtn.widthAnchor constraintEqualToConstant:60],
        [centerBtn.heightAnchor constraintEqualToConstant:60],
        
        [upBtn.centerXAnchor constraintEqualToAnchor:dpadContainer.centerXAnchor],
        [upBtn.topAnchor constraintEqualToAnchor:dpadContainer.topAnchor constant:10],
        [upBtn.widthAnchor constraintEqualToConstant:60],
        [upBtn.heightAnchor constraintEqualToConstant:60],
        
        [downBtn.centerXAnchor constraintEqualToAnchor:dpadContainer.centerXAnchor],
        [downBtn.bottomAnchor constraintEqualToAnchor:dpadContainer.bottomAnchor constant:-10],
        [downBtn.widthAnchor constraintEqualToConstant:60],
        [downBtn.heightAnchor constraintEqualToConstant:60],
        
        [leftBtn.centerYAnchor constraintEqualToAnchor:dpadContainer.centerYAnchor],
        [leftBtn.leadingAnchor constraintEqualToAnchor:dpadContainer.leadingAnchor constant:10],
        [leftBtn.widthAnchor constraintEqualToConstant:60],
        [leftBtn.heightAnchor constraintEqualToConstant:60],
        
        [rightBtn.centerYAnchor constraintEqualToAnchor:dpadContainer.centerYAnchor],
        [rightBtn.trailingAnchor constraintEqualToAnchor:dpadContainer.trailingAnchor constant:-10],
        [rightBtn.widthAnchor constraintEqualToConstant:60],
        [rightBtn.heightAnchor constraintEqualToConstant:60],
    ]];
    
    // Create Menu Button
    UIButton *menuBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [menuBtn setTitle:L(@"Menu", @"菜单/返回") forState:UIControlStateNormal];
    menuBtn.titleLabel.font = [UIFont systemFontOfSize:22 weight:UIFontWeightBold];
    menuBtn.backgroundColor = [UIColor systemGray5Color];
    menuBtn.layer.cornerRadius = 20;
    [menuBtn addTarget:self action:@selector(sendMenu) forControlEvents:UIControlEventTouchUpInside];
    menuBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:menuBtn];
    
    [NSLayoutConstraint activateConstraints:@[
        [menuBtn.topAnchor constraintEqualToAnchor:dpadContainer.bottomAnchor constant:40],
        [menuBtn.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [menuBtn.widthAnchor constraintEqualToConstant:140],
        [menuBtn.heightAnchor constraintEqualToConstant:60]
    ]];
}

- (UIButton *)createDPadButtonWithIcon:(NSString *)iconName action:(SEL)selector {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:28 weight:UIImageSymbolWeightBold];
    [btn setImage:[UIImage systemImageNamed:iconName withConfiguration:config] forState:UIControlStateNormal];
    btn.tintColor = [UIColor labelColor];
    [btn addTarget:self action:selector forControlEvents:UIControlEventTouchUpInside];
    btn.translatesAutoresizingMaskIntoConstraints = NO;
    return btn;
}

- (void)closeSettings {
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Actions

- (void)triggerAction:(NSString *)action {
    if (self.checkConnectionBlock && !self.checkConnectionBlock()) {
        NSLog(@"[IPTVRemote] TV not connected.");
        return;
    }
    
    UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [feedback impactOccurred];
    
    if (self.sendPayloadBlock) {
        self.sendPayloadBlock(@{@"action": action});
    }
}

- (void)sendUp { [self triggerAction:@"iptv_up"]; }
- (void)sendDown { [self triggerAction:@"iptv_down"]; }
- (void)sendLeft { [self triggerAction:@"iptv_left"]; }
- (void)sendRight { [self triggerAction:@"iptv_right"]; }
- (void)sendSelect { [self triggerAction:@"iptv_select"]; }
- (void)sendMenu { [self triggerAction:@"iptv_menu"]; }

@end
