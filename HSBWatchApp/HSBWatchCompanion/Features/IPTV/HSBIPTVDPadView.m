#import "HSBIPTVDPadView.h"
#import "HSBThemeManager.h"

@interface HSBIPTVDPadView ()

@property (nonatomic, strong) UIView *dpadContainer;
@property (nonatomic, strong) UIButton *centerBtn;
@property (nonatomic, strong) NSMutableArray<UIButton *> *dpadDirectionBtns;

@property (nonatomic, strong) UIView *leftWingView;
@property (nonatomic, strong) UIView *rightWingView;
@property (nonatomic, strong) NSMutableArray<UIButton *> *wingBtns;

@end

@implementation HSBIPTVDPadView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _dpadDirectionBtns = [NSMutableArray array];
        _wingBtns = [NSMutableArray array];
        [self setupUI];
    }
    return self;
}

- (void)setupUI {
    // Left Wing (Volume Control: Vol+, Vol-, Mute)
    self.leftWingView = [[UIView alloc] init];
    self.leftWingView.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.06];
    self.leftWingView.layer.cornerRadius = 24;
    self.leftWingView.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.leftWingView];
    
    UIButton *volUpBtn = [self createWingButtonWithIcon:@"speaker.wave.3.fill" action:@selector(sendVolumeUp)];
    UIButton *volDownBtn = [self createWingButtonWithIcon:@"speaker.wave.1.fill" action:@selector(sendVolumeDown)];
    UIButton *muteBtn = [self createWingButtonWithIcon:@"speaker.slash.fill" action:@selector(sendToggleMute)];
    [self.wingBtns addObjectsFromArray:@[volUpBtn, volDownBtn, muteBtn]];
    
    [self.leftWingView addSubview:volUpBtn];
    [self.leftWingView addSubview:volDownBtn];
    [self.leftWingView addSubview:muteBtn];
    
    // Right Wing (Channel Control: Ch+, Ch-, Channels List)
    self.rightWingView = [[UIView alloc] init];
    self.rightWingView.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.06];
    self.rightWingView.layer.cornerRadius = 24;
    self.rightWingView.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.rightWingView];
    
    UIButton *chUpBtn = [self createWingButtonWithIcon:@"chevron.up.circle.fill" action:@selector(sendChannelUp)];
    UIButton *chDownBtn = [self createWingButtonWithIcon:@"chevron.down.circle.fill" action:@selector(sendChannelDown)];
    UIButton *chListBtn = [self createWingButtonWithIcon:@"list.bullet" action:@selector(sendChannels)];
    [self.wingBtns addObjectsFromArray:@[chUpBtn, chDownBtn, chListBtn]];
    
    [self.rightWingView addSubview:chUpBtn];
    [self.rightWingView addSubview:chDownBtn];
    [self.rightWingView addSubview:chListBtn];
    
    // Center D-Pad
    self.dpadContainer = [[UIView alloc] init];
    self.dpadContainer.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.06];
    self.dpadContainer.layer.cornerRadius = 100;
    self.dpadContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.dpadContainer];
    
    UIButton *upBtn = [self createDPadButtonWithIcon:@"chevron.up" action:@selector(sendUp)];
    UIButton *downBtn = [self createDPadButtonWithIcon:@"chevron.down" action:@selector(sendDown)];
    UIButton *leftBtn = [self createDPadButtonWithIcon:@"chevron.left" action:@selector(sendLeft)];
    UIButton *rightBtn = [self createDPadButtonWithIcon:@"chevron.right" action:@selector(sendRight)];
    self.centerBtn = [self createDPadButtonWithIcon:@"circle.fill" action:@selector(sendSelect)];
    self.centerBtn.tintColor = [HSBThemeManager shared].currentPalette.primaryColor;
    
    [self.dpadDirectionBtns addObjectsFromArray:@[upBtn, downBtn, leftBtn, rightBtn]];
    for (UIButton *btn in self.dpadDirectionBtns) {
        btn.tintColor = [UIColor whiteColor];
    }
    
    [self.dpadContainer addSubview:upBtn];
    [self.dpadContainer addSubview:downBtn];
    [self.dpadContainer addSubview:leftBtn];
    [self.dpadContainer addSubview:rightBtn];
    [self.dpadContainer addSubview:self.centerBtn];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.dpadContainer.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
        [self.dpadContainer.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        [self.dpadContainer.widthAnchor constraintEqualToConstant:200],
        [self.dpadContainer.heightAnchor constraintEqualToConstant:200],
        
        [self.centerBtn.centerXAnchor constraintEqualToAnchor:self.dpadContainer.centerXAnchor],
        [self.centerBtn.centerYAnchor constraintEqualToAnchor:self.dpadContainer.centerYAnchor],
        [self.centerBtn.widthAnchor constraintEqualToConstant:54],
        [self.centerBtn.heightAnchor constraintEqualToConstant:54],
        
        [upBtn.centerXAnchor constraintEqualToAnchor:self.dpadContainer.centerXAnchor],
        [upBtn.topAnchor constraintEqualToAnchor:self.dpadContainer.topAnchor constant:8],
        [upBtn.widthAnchor constraintEqualToConstant:50],
        [upBtn.heightAnchor constraintEqualToConstant:50],
        
        [downBtn.centerXAnchor constraintEqualToAnchor:self.dpadContainer.centerXAnchor],
        [downBtn.bottomAnchor constraintEqualToAnchor:self.dpadContainer.bottomAnchor constant:-8],
        [downBtn.widthAnchor constraintEqualToConstant:50],
        [downBtn.heightAnchor constraintEqualToConstant:50],
        
        [leftBtn.centerYAnchor constraintEqualToAnchor:self.dpadContainer.centerYAnchor],
        [leftBtn.leadingAnchor constraintEqualToAnchor:self.dpadContainer.leadingAnchor constant:8],
        [leftBtn.widthAnchor constraintEqualToConstant:50],
        [leftBtn.heightAnchor constraintEqualToConstant:50],
        
        [rightBtn.centerYAnchor constraintEqualToAnchor:self.dpadContainer.centerYAnchor],
        [rightBtn.trailingAnchor constraintEqualToAnchor:self.dpadContainer.trailingAnchor constant:-8],
        [rightBtn.widthAnchor constraintEqualToConstant:50],
        [rightBtn.heightAnchor constraintEqualToConstant:50],
        
        [self.leftWingView.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        [self.leftWingView.trailingAnchor constraintEqualToAnchor:self.dpadContainer.leadingAnchor constant:-14],
        [self.leftWingView.widthAnchor constraintEqualToConstant:48],
        [self.leftWingView.heightAnchor constraintEqualToConstant:160],
        
        [volUpBtn.topAnchor constraintEqualToAnchor:self.leftWingView.topAnchor constant:8],
        [volUpBtn.centerXAnchor constraintEqualToAnchor:self.leftWingView.centerXAnchor],
        [volUpBtn.widthAnchor constraintEqualToConstant:40],
        [volUpBtn.heightAnchor constraintEqualToConstant:40],
        
        [muteBtn.centerYAnchor constraintEqualToAnchor:self.leftWingView.centerYAnchor],
        [muteBtn.centerXAnchor constraintEqualToAnchor:self.leftWingView.centerXAnchor],
        [muteBtn.widthAnchor constraintEqualToConstant:40],
        [muteBtn.heightAnchor constraintEqualToConstant:40],
        
        [volDownBtn.bottomAnchor constraintEqualToAnchor:self.leftWingView.bottomAnchor constant:-8],
        [volDownBtn.centerXAnchor constraintEqualToAnchor:self.leftWingView.centerXAnchor],
        [volDownBtn.widthAnchor constraintEqualToConstant:40],
        [volDownBtn.heightAnchor constraintEqualToConstant:40],
        
        [self.rightWingView.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        [self.rightWingView.leadingAnchor constraintEqualToAnchor:self.dpadContainer.trailingAnchor constant:14],
        [self.rightWingView.widthAnchor constraintEqualToConstant:48],
        [self.rightWingView.heightAnchor constraintEqualToConstant:160],
        
        [chUpBtn.topAnchor constraintEqualToAnchor:self.rightWingView.topAnchor constant:8],
        [chUpBtn.centerXAnchor constraintEqualToAnchor:self.rightWingView.centerXAnchor],
        [chUpBtn.widthAnchor constraintEqualToConstant:40],
        [chUpBtn.heightAnchor constraintEqualToConstant:40],
        
        [chListBtn.centerYAnchor constraintEqualToAnchor:self.rightWingView.centerYAnchor],
        [chListBtn.centerXAnchor constraintEqualToAnchor:self.rightWingView.centerXAnchor],
        [chListBtn.widthAnchor constraintEqualToConstant:40],
        [chListBtn.heightAnchor constraintEqualToConstant:40],
        
        [chDownBtn.bottomAnchor constraintEqualToAnchor:self.rightWingView.bottomAnchor constant:-8],
        [chDownBtn.centerXAnchor constraintEqualToAnchor:self.rightWingView.centerXAnchor],
        [chDownBtn.widthAnchor constraintEqualToConstant:40],
        [chDownBtn.heightAnchor constraintEqualToConstant:40]
    ]];
}

- (UIButton *)createDPadButtonWithIcon:(NSString *)iconName action:(SEL)selector {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:26 weight:UIImageSymbolWeightBold];
    [btn setImage:[UIImage systemImageNamed:iconName withConfiguration:config] forState:UIControlStateNormal];
    btn.tintColor = [UIColor whiteColor];
    [btn addTarget:self action:selector forControlEvents:UIControlEventTouchUpInside];
    btn.translatesAutoresizingMaskIntoConstraints = NO;
    return btn;
}

- (UIButton *)createWingButtonWithIcon:(NSString *)iconName action:(SEL)selector {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:18 weight:UIImageSymbolWeightMedium];
    [btn setImage:[UIImage systemImageNamed:iconName withConfiguration:config] forState:UIControlStateNormal];
    btn.tintColor = [UIColor whiteColor];
    [btn addTarget:self action:selector forControlEvents:UIControlEventTouchUpInside];
    btn.translatesAutoresizingMaskIntoConstraints = NO;
    return btn;
}

- (void)triggerAction:(HSBRemoteSimulateAction)action {
    if (self.onActionTriggeredBlock) {
        self.onActionTriggeredBlock(action);
    }
}

- (void)sendUp { [self triggerAction:HSBRemoteSimulateActionUp]; }
- (void)sendDown { [self triggerAction:HSBRemoteSimulateActionDown]; }
- (void)sendLeft { [self triggerAction:HSBRemoteSimulateActionLeft]; }
- (void)sendRight { [self triggerAction:HSBRemoteSimulateActionRight]; }
- (void)sendSelect { [self triggerAction:HSBRemoteSimulateActionSelect]; }
- (void)sendVolumeUp { [self triggerAction:HSBRemoteSimulateActionVolumeUp]; }
- (void)sendVolumeDown { [self triggerAction:HSBRemoteSimulateActionVolumeDown]; }
- (void)sendToggleMute { [self triggerAction:HSBRemoteSimulateActionToggleMute]; }
- (void)sendChannelUp { [self triggerAction:HSBRemoteSimulateActionChannelUp]; }
- (void)sendChannelDown { [self triggerAction:HSBRemoteSimulateActionChannelDown]; }
- (void)sendChannels { [self triggerAction:HSBRemoteSimulateActionIPTVChannels]; }

- (void)applyThemeStyle {
    self.centerBtn.tintColor = [HSBThemeManager shared].currentPalette.primaryColor;
}

@end
