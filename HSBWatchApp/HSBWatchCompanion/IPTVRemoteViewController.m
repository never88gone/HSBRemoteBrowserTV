//
//  IPTVRemoteViewController.m
//  HSBWatchCompanion
//

#import "IPTVRemoteViewController.h"
#import "HSBThemeManager.h"
#import "HSBTVOSConnectionManager.h"

static inline NSString * L(NSString *en, NSString *zh) {
    NSString *language = [[NSLocale preferredLanguages] firstObject];
    if ([language hasPrefix:@"zh"]) {
        return zh ?: en;
    }
    return en;
}

@interface IPTVRemoteViewController () <UISearchBarDelegate>

@property (nonatomic, strong) UISegmentedControl *modeSegment;
@property (nonatomic, strong) UIImageView *favHeartIcon;
@property (nonatomic, strong) UILabel *favTitleLabel;
@property (nonatomic, strong) UIButton *addFavBtn;
@property (nonatomic, strong) UIButton *searchToggleBtn;
@property (nonatomic, strong) UISearchBar *favSearchBar;
@property (nonatomic, strong) UIScrollView *favScrollView;
@property (nonatomic, strong) UIView *favContainer;
@property (nonatomic, copy) NSString *filterKeyword;

// D-Pad View Container
@property (nonatomic, strong) UIView *dpadModeView;
@property (nonatomic, strong) UIView *dpadContainer;
@property (nonatomic, strong) UIButton *centerBtn;
@property (nonatomic, strong) NSMutableArray<UIButton *> *dpadDirectionBtns;

// Wing Controls
@property (nonatomic, strong) UIView *leftWingView;
@property (nonatomic, strong) UIView *rightWingView;
@property (nonatomic, strong) NSMutableArray<UIButton *> *wingBtns;

// Bottom Action Controls
@property (nonatomic, strong) UIStackView *bottomActionStack;
@property (nonatomic, strong) UIButton *menuBtn;
@property (nonatomic, strong) NSMutableArray<UIButton *> *extraActionBtns;

// Keypad Mode Container
@property (nonatomic, strong) UIView *keypadModeView;
@property (nonatomic, strong) UILabel *keypadDisplayLabel;
@property (nonatomic, strong) UIButton *keypadClearBtn;
@property (nonatomic, strong) NSMutableString *currentDigits;
@property (nonatomic, strong) NSTimer *autoCommitTimer;

@end

@implementation IPTVRemoteViewController

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self.autoCommitTimer invalidate];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.currentDigits = [NSMutableString string];
    self.extraActionBtns = [NSMutableArray array];
    self.dpadDirectionBtns = [NSMutableArray array];
    self.wingBtns = [NSMutableArray array];
    
    // 监听电视端 IPTV 收藏更新通知
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleFavoritesUpdated:) name:HSBIPTVFavoritesUpdatedNotification object:nil];
    
    [self setupTopControls];
    [self setupFavoritesArea];
    [self setupDPadModeView];
    [self setupKeypadModeView];
    [self setupBottomControls];
    
    // 默认展示 D-Pad 模式
    self.dpadModeView.hidden = NO;
    self.keypadModeView.hidden = YES;
    
    [self reloadFavoritesUI];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (self.sendPayloadBlock) {
        self.sendPayloadBlock(@{
            HSBRemotePayloadKeyAction: HSBRemoteSimulateActionIPTVGetFavorites,
            HSBRemotePayloadKeyTimestamp: @([[NSDate date] timeIntervalSince1970])
        });
    }
}

#pragma mark - UI Setup

- (void)setupTopControls {
    self.modeSegment = [[UISegmentedControl alloc] initWithItems:@[
        L(@"Navigation", @"方向导航"),
        L(@"Keypad", @"数字键盘")
    ]];
    self.modeSegment.selectedSegmentIndex = 0;
    self.modeSegment.selectedSegmentTintColor = [HSBThemeManager shared].currentPalette.primaryColor;
    [self.modeSegment addTarget:self action:@selector(modeSegmentChanged:) forControlEvents:UIControlEventValueChanged];
    self.modeSegment.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.modeSegment];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.modeSegment.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:8],
        [self.modeSegment.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.modeSegment.widthAnchor constraintEqualToConstant:220],
        [self.modeSegment.heightAnchor constraintEqualToConstant:32]
    ]];
}

- (void)setupFavoritesArea {
    self.favHeartIcon = [[UIImageView alloc] init];
    self.favHeartIcon.image = [UIImage systemImageNamed:@"heart.fill"];
    self.favHeartIcon.tintColor = [UIColor systemPinkColor];
    self.favHeartIcon.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.favHeartIcon];
    
    self.favTitleLabel = [[UILabel alloc] init];
    self.favTitleLabel.text = L(@"Favorite Channels", @"我的收藏频道");
    self.favTitleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
    self.favTitleLabel.textColor = [UIColor secondaryLabelColor];
    self.favTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.favTitleLabel];
    
    self.addFavBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.addFavBtn setImage:[UIImage systemImageNamed:@"plus.circle.fill" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightSemibold]] forState:UIControlStateNormal];
    self.addFavBtn.tintColor = [HSBThemeManager shared].currentPalette.primaryColor;
    [self.addFavBtn addTarget:self action:@selector(addFavoriteChannelAction) forControlEvents:UIControlEventTouchUpInside];
    self.addFavBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.addFavBtn];
    
    self.searchToggleBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.searchToggleBtn setImage:[UIImage systemImageNamed:@"magnifyingglass" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:13 weight:UIImageSymbolWeightSemibold]] forState:UIControlStateNormal];
    self.searchToggleBtn.tintColor = [UIColor secondaryLabelColor];
    [self.searchToggleBtn addTarget:self action:@selector(toggleSearchBar) forControlEvents:UIControlEventTouchUpInside];
    self.searchToggleBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.searchToggleBtn];
    
    self.favSearchBar = [[UISearchBar alloc] init];
    self.favSearchBar.placeholder = L(@"Filter favorites...", @"搜索收藏频道");
    self.favSearchBar.searchBarStyle = UISearchBarStyleMinimal;
    self.favSearchBar.delegate = self;
    self.favSearchBar.hidden = YES;
    self.favSearchBar.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.favSearchBar];
    
    self.favScrollView = [[UIScrollView alloc] init];
    self.favScrollView.showsHorizontalScrollIndicator = NO;
    self.favScrollView.alwaysBounceHorizontal = YES;
    self.favScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.favScrollView];
    
    self.favContainer = [[UIView alloc] init];
    self.favContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [self.favScrollView addSubview:self.favContainer];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.favHeartIcon.topAnchor constraintEqualToAnchor:self.modeSegment.bottomAnchor constant:12],
        [self.favHeartIcon.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [self.favHeartIcon.widthAnchor constraintEqualToConstant:14],
        [self.favHeartIcon.heightAnchor constraintEqualToConstant:14],
        
        [self.favTitleLabel.centerYAnchor constraintEqualToAnchor:self.favHeartIcon.centerYAnchor],
        [self.favTitleLabel.leadingAnchor constraintEqualToAnchor:self.favHeartIcon.trailingAnchor constant:6],
        
        [self.addFavBtn.centerYAnchor constraintEqualToAnchor:self.favHeartIcon.centerYAnchor],
        [self.addFavBtn.leadingAnchor constraintEqualToAnchor:self.favTitleLabel.trailingAnchor constant:6],
        [self.addFavBtn.widthAnchor constraintEqualToConstant:18],
        [self.addFavBtn.heightAnchor constraintEqualToConstant:18],
        
        [self.searchToggleBtn.centerYAnchor constraintEqualToAnchor:self.favHeartIcon.centerYAnchor],
        [self.searchToggleBtn.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        [self.searchToggleBtn.widthAnchor constraintEqualToConstant:24],
        [self.searchToggleBtn.heightAnchor constraintEqualToConstant:24],
        
        [self.favSearchBar.topAnchor constraintEqualToAnchor:self.favTitleLabel.bottomAnchor constant:4],
        [self.favSearchBar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:12],
        [self.favSearchBar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-12],
        [self.favSearchBar.heightAnchor constraintEqualToConstant:36],
        
        [self.favScrollView.topAnchor constraintEqualToAnchor:self.favTitleLabel.bottomAnchor constant:8],
        [self.favScrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.favScrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.favScrollView.heightAnchor constraintEqualToConstant:36],
        
        [self.favContainer.topAnchor constraintEqualToAnchor:self.favScrollView.topAnchor],
        [self.favContainer.leadingAnchor constraintEqualToAnchor:self.favScrollView.leadingAnchor],
        [self.favContainer.trailingAnchor constraintEqualToAnchor:self.favScrollView.trailingAnchor],
        [self.favContainer.bottomAnchor constraintEqualToAnchor:self.favScrollView.bottomAnchor],
        [self.favContainer.heightAnchor constraintEqualToAnchor:self.favScrollView.heightAnchor]
    ]];
}

- (void)setupDPadModeView {
    self.dpadModeView = [[UIView alloc] init];
    self.dpadModeView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.dpadModeView];
    
    // Left Wing (Volume Control: Vol+, Vol-, Mute)
    self.leftWingView = [[UIView alloc] init];
    self.leftWingView.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.06];
    self.leftWingView.layer.cornerRadius = 24;
    self.leftWingView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.dpadModeView addSubview:self.leftWingView];
    
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
    [self.dpadModeView addSubview:self.rightWingView];
    
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
    [self.dpadModeView addSubview:self.dpadContainer];
    
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
        [self.dpadModeView.topAnchor constraintEqualToAnchor:self.favScrollView.bottomAnchor constant:12],
        [self.dpadModeView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.dpadModeView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.dpadModeView.heightAnchor constraintEqualToConstant:210],
        
        // D-Pad Container Center
        [self.dpadContainer.centerXAnchor constraintEqualToAnchor:self.dpadModeView.centerXAnchor],
        [self.dpadContainer.centerYAnchor constraintEqualToAnchor:self.dpadModeView.centerYAnchor],
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
        
        // Left Wing Layout (Vol+, Mute, Vol-)
        [self.leftWingView.centerYAnchor constraintEqualToAnchor:self.dpadModeView.centerYAnchor],
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
        
        // Right Wing Layout (Ch+, List, Ch-)
        [self.rightWingView.centerYAnchor constraintEqualToAnchor:self.dpadModeView.centerYAnchor],
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

- (void)setupKeypadModeView {
    self.keypadModeView = [[UIView alloc] init];
    self.keypadModeView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.keypadModeView];
    
    // Display Box
    UIView *displayBox = [[UIView alloc] init];
    displayBox.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.06];
    displayBox.layer.cornerRadius = 12;
    displayBox.translatesAutoresizingMaskIntoConstraints = NO;
    [self.keypadModeView addSubview:displayBox];
    
    self.keypadDisplayLabel = [[UILabel alloc] init];
    self.keypadDisplayLabel.text = L(@"Channel: ---", @"频道: ---");
    self.keypadDisplayLabel.font = [UIFont monospacedDigitSystemFontOfSize:18 weight:UIFontWeightBold];
    self.keypadDisplayLabel.textColor = [HSBThemeManager shared].currentPalette.primaryColor;
    self.keypadDisplayLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [displayBox addSubview:self.keypadDisplayLabel];
    
    self.keypadClearBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.keypadClearBtn setImage:[UIImage systemImageNamed:@"delete.left.fill"] forState:UIControlStateNormal];
    self.keypadClearBtn.tintColor = [UIColor secondaryLabelColor];
    [self.keypadClearBtn addTarget:self action:@selector(keypadBackspace) forControlEvents:UIControlEventTouchUpInside];
    self.keypadClearBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [displayBox addSubview:self.keypadClearBtn];
    
    [NSLayoutConstraint activateConstraints:@[
        [displayBox.topAnchor constraintEqualToAnchor:self.keypadModeView.topAnchor],
        [displayBox.leadingAnchor constraintEqualToAnchor:self.keypadModeView.leadingAnchor constant:24],
        [displayBox.trailingAnchor constraintEqualToAnchor:self.keypadModeView.trailingAnchor constant:-24],
        [displayBox.heightAnchor constraintEqualToConstant:36],
        
        [self.keypadDisplayLabel.centerYAnchor constraintEqualToAnchor:displayBox.centerYAnchor],
        [self.keypadDisplayLabel.leadingAnchor constraintEqualToAnchor:displayBox.leadingAnchor constant:14],
        
        [self.keypadClearBtn.centerYAnchor constraintEqualToAnchor:displayBox.centerYAnchor],
        [self.keypadClearBtn.trailingAnchor constraintEqualToAnchor:displayBox.trailingAnchor constant:-10],
        [self.keypadClearBtn.widthAnchor constraintEqualToConstant:30],
        [self.keypadClearBtn.heightAnchor constraintEqualToConstant:30]
    ]];
    
    // 3x4 Grid (1..9, Back, 0, OK)
    UIStackView *vertStack = [[UIStackView alloc] init];
    vertStack.axis = UILayoutConstraintAxisVertical;
    vertStack.distribution = UIStackViewDistributionFillEqually;
    vertStack.spacing = 8;
    vertStack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.keypadModeView addSubview:vertStack];
    
    NSArray *rows = @[
        @[@"1", @"2", @"3"],
        @[@"4", @"5", @"6"],
        @[@"7", @"8", @"9"],
        @[@"CLR", @"0", @"OK"]
    ];
    
    for (NSArray *row in rows) {
        UIStackView *horzStack = [[UIStackView alloc] init];
        horzStack.axis = UILayoutConstraintAxisHorizontal;
        horzStack.distribution = UIStackViewDistributionFillEqually;
        horzStack.spacing = 12;
        
        for (NSString *val in row) {
            UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
            btn.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.07];
            btn.layer.cornerRadius = 14;
            [btn setTitle:val forState:UIControlStateNormal];
            btn.titleLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightBold];
            
            if ([val isEqualToString:@"OK"]) {
                btn.backgroundColor = [[HSBThemeManager shared].currentPalette.primaryColor colorWithAlphaComponent:0.25];
                [btn setTitleColor:[HSBThemeManager shared].currentPalette.primaryColor forState:UIControlStateNormal];
                [btn addTarget:self action:@selector(keypadOK) forControlEvents:UIControlEventTouchUpInside];
            } else if ([val isEqualToString:@"CLR"]) {
                [btn setTitleColor:[UIColor systemRedColor] forState:UIControlStateNormal];
                [btn addTarget:self action:@selector(keypadClearAll) forControlEvents:UIControlEventTouchUpInside];
            } else {
                [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
                [btn addTarget:self action:@selector(keypadDigitPressed:) forControlEvents:UIControlEventTouchUpInside];
            }
            [horzStack addArrangedSubview:btn];
        }
        [vertStack addArrangedSubview:horzStack];
    }
    
    [NSLayoutConstraint activateConstraints:@[
        [self.keypadModeView.topAnchor constraintEqualToAnchor:self.favScrollView.bottomAnchor constant:12],
        [self.keypadModeView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.keypadModeView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.keypadModeView.heightAnchor constraintEqualToConstant:210],
        
        [vertStack.topAnchor constraintEqualToAnchor:displayBox.bottomAnchor constant:8],
        [vertStack.leadingAnchor constraintEqualToAnchor:self.keypadModeView.leadingAnchor constant:24],
        [vertStack.trailingAnchor constraintEqualToAnchor:self.keypadModeView.trailingAnchor constant:-24],
        [vertStack.bottomAnchor constraintEqualToAnchor:self.keypadModeView.bottomAnchor constant:-4]
    ]];
}

- (void)setupBottomControls {
    self.bottomActionStack = [[UIStackView alloc] init];
    self.bottomActionStack.axis = UILayoutConstraintAxisHorizontal;
    self.bottomActionStack.distribution = UIStackViewDistributionFillEqually;
    self.bottomActionStack.spacing = 12;
    self.bottomActionStack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.bottomActionStack];
    
    UIButton *epgBtn = [self createControlButtonWithIcon:@"list.bullet.rectangle" title:L(@"EPG", @"节目单") action:@selector(sendEPG)];
    UIButton *refreshBtn = [self createControlButtonWithIcon:@"arrow.clockwise" title:L(@"Refresh", @"刷新") action:@selector(sendRefresh)];
    
    [self.extraActionBtns addObjectsFromArray:@[epgBtn, refreshBtn]];
    for (UIButton *btn in self.extraActionBtns) {
        btn.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.08];
        btn.tintColor = [UIColor whiteColor];
    }
    
    [self.bottomActionStack addArrangedSubview:epgBtn];
    [self.bottomActionStack addArrangedSubview:refreshBtn];
    
    self.menuBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.menuBtn setTitle:L(@"Menu / Back", @"菜单 / 返回") forState:UIControlStateNormal];
    self.menuBtn.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightBold];
    self.menuBtn.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.08];
    self.menuBtn.layer.cornerRadius = 14;
    [self.menuBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.menuBtn addTarget:self action:@selector(sendMenu) forControlEvents:UIControlEventTouchUpInside];
    self.menuBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.menuBtn];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.bottomActionStack.topAnchor constraintEqualToAnchor:self.dpadModeView.bottomAnchor constant:12],
        [self.bottomActionStack.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:24],
        [self.bottomActionStack.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-24],
        [self.bottomActionStack.heightAnchor constraintEqualToConstant:44],
        
        [self.menuBtn.topAnchor constraintEqualToAnchor:self.bottomActionStack.bottomAnchor constant:10],
        [self.menuBtn.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.menuBtn.widthAnchor constraintEqualToConstant:160],
        [self.menuBtn.heightAnchor constraintEqualToConstant:44]
    ]];
}

#pragma mark - Mode Switch & Search

- (void)modeSegmentChanged:(UISegmentedControl *)seg {
    UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [fb impactOccurred];
    
    BOOL isDpad = (seg.selectedSegmentIndex == 0);
    self.dpadModeView.hidden = !isDpad;
    self.keypadModeView.hidden = isDpad;
}

- (void)toggleSearchBar {
    UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [fb impactOccurred];
    
    self.favSearchBar.hidden = !self.favSearchBar.hidden;
    if (self.favSearchBar.hidden) {
        [self.favSearchBar resignFirstResponder];
        self.favSearchBar.text = @"";
        self.filterKeyword = nil;
        [self reloadFavoritesUI];
    } else {
        [self.favSearchBar becomeFirstResponder];
    }
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    self.filterKeyword = [searchText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    [self reloadFavoritesUI];
}

#pragma mark - Helper Factory

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

- (UIButton *)createControlButtonWithIcon:(NSString *)iconName title:(NSString *)title action:(SEL)selector {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    btn.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.08];
    btn.layer.cornerRadius = 12;
    btn.tintColor = [UIColor whiteColor];
    
    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:15 weight:UIImageSymbolWeightSemibold];
    UIImage *image = [UIImage systemImageNamed:iconName withConfiguration:config];
    [btn setImage:image forState:UIControlStateNormal];
    [btn setTitle:[NSString stringWithFormat:@" %@", title] forState:UIControlStateNormal];
    [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    btn.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightBold];
    [btn addTarget:self action:selector forControlEvents:UIControlEventTouchUpInside];
    btn.translatesAutoresizingMaskIntoConstraints = NO;
    return btn;
}

#pragma mark - Actions

- (void)triggerSimulateAction:(HSBRemoteSimulateAction)action {
    if (self.checkConnectionBlock && !self.checkConnectionBlock()) {
        NSLog(@"[IPTVRemote] TV not connected.");
        return;
    }
    
    UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [feedback impactOccurred];
    
    if (self.sendPayloadBlock) {
        self.sendPayloadBlock(@{HSBRemotePayloadKeyAction: action});
    } else {
        [[HSBTVOSConnectionManager sharedManager] sendSimulateAction:action];
    }
}

- (void)sendUp { [self triggerSimulateAction:HSBRemoteSimulateActionUp]; }
- (void)sendDown { [self triggerSimulateAction:HSBRemoteSimulateActionDown]; }
- (void)sendLeft { [self triggerSimulateAction:HSBRemoteSimulateActionLeft]; }
- (void)sendRight { [self triggerSimulateAction:HSBRemoteSimulateActionRight]; }
- (void)sendSelect { [self triggerSimulateAction:HSBRemoteSimulateActionSelect]; }
- (void)sendMenu { [self triggerSimulateAction:HSBRemoteSimulateActionMenu]; }
- (void)sendEPG { [self triggerSimulateAction:HSBRemoteSimulateActionIPTVEpg]; }
- (void)sendChannels { [self triggerSimulateAction:HSBRemoteSimulateActionIPTVChannels]; }
- (void)sendRefresh { [self triggerSimulateAction:HSBRemoteSimulateActionIPTVRefresh]; }
- (void)sendVolumeUp { [self triggerSimulateAction:HSBRemoteSimulateActionVolumeUp]; }
- (void)sendVolumeDown { [self triggerSimulateAction:HSBRemoteSimulateActionVolumeDown]; }
- (void)sendToggleMute { [self triggerSimulateAction:HSBRemoteSimulateActionToggleMute]; }
- (void)sendChannelUp { [self triggerSimulateAction:HSBRemoteSimulateActionChannelUp]; }
- (void)sendChannelDown { [self triggerSimulateAction:HSBRemoteSimulateActionChannelDown]; }

#pragma mark - Keypad Actions

- (void)keypadDigitPressed:(UIButton *)sender {
    NSString *digit = [sender titleForState:UIControlStateNormal];
    if (!digit) return;
    
    UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [fb impactOccurred];
    
    [self.currentDigits appendString:digit];
    self.keypadDisplayLabel.text = [NSString stringWithFormat:L(@"Channel: %@", @"频道: %@"), self.currentDigits];
    
    if (self.sendPayloadBlock) {
        self.sendPayloadBlock(@{
            HSBRemotePayloadKeyAction: HSBRemoteSimulateActionDigit,
            HSBRemotePayloadKeyDigit: digit
        });
    }
    
    [self.autoCommitTimer invalidate];
    self.autoCommitTimer = [NSTimer scheduledTimerWithTimeInterval:2.0 target:self selector:@selector(keypadOK) userInfo:nil repeats:NO];
}

- (void)keypadBackspace {
    if (self.currentDigits.length > 0) {
        UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
        [fb impactOccurred];
        [self.currentDigits deleteCharactersInRange:NSMakeRange(self.currentDigits.length - 1, 1)];
        if (self.currentDigits.length == 0) {
            self.keypadDisplayLabel.text = L(@"Channel: ---", @"频道: ---");
        } else {
            self.keypadDisplayLabel.text = [NSString stringWithFormat:L(@"Channel: %@", @"频道: %@"), self.currentDigits];
        }
    }
}

- (void)keypadClearAll {
    UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [fb impactOccurred];
    [self.currentDigits setString:@""];
    self.keypadDisplayLabel.text = L(@"Channel: ---", @"频道: ---");
    [self.autoCommitTimer invalidate];
}

- (void)keypadOK {
    [self.autoCommitTimer invalidate];
    if (self.currentDigits.length == 0) return;
    
    UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [fb impactOccurred];
    
    NSString *chan = [self.currentDigits copy];
    [self showToast:[NSString stringWithFormat:L(@"Tuning to Channel %@", @"正在跳台至频道: %@"), chan]];
    
    NSDictionary *payload = @{
        HSBRemotePayloadKeyAction: HSBRemoteSimulateActionIPTVPlayChannel,
        HSBRemotePayloadKeyChannel: chan,
        HSBRemotePayloadKeyId: chan,
        HSBRemotePayloadKeyTimestamp: @([[NSDate date] timeIntervalSince1970])
    };
    
    if (self.sendPayloadBlock) {
        self.sendPayloadBlock(payload);
    } else {
        [[HSBTVOSConnectionManager sharedManager] sendPayload:payload];
    }
    
    [self keypadClearAll];
}

#pragma mark - Favorites Control

- (NSArray<NSDictionary *> *)defaultFavorites {
    return @[
        @{HSBRemotePayloadKeyName: L(@"CCTV-1 General", @"CCTV-1 综合"), HSBRemotePayloadKeyId: @"cctv1"},
        @{HSBRemotePayloadKeyName: L(@"CCTV-5 Sports", @"CCTV-5 体育"), HSBRemotePayloadKeyId: @"cctv5"},
        @{HSBRemotePayloadKeyName: L(@"CCTV-13 News", @"CCTV-13 新闻"), HSBRemotePayloadKeyId: @"cctv13"},
        @{HSBRemotePayloadKeyName: L(@"Hunan TV", @"湖南卫视"), HSBRemotePayloadKeyId: @"hunantv"},
        @{HSBRemotePayloadKeyName: L(@"Dragon TV", @"东方卫视"), HSBRemotePayloadKeyId: @"dongfangtv"},
        @{HSBRemotePayloadKeyName: L(@"Zhejiang TV", @"浙江卫视"), HSBRemotePayloadKeyId: @"zhejiangtv"}
    ];
}

- (void)handleFavoritesUpdated:(NSNotification *)note {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self reloadFavoritesUI];
    });
}

- (void)reloadFavoritesUI {
    if (!self.favContainer) return;
    
    for (UIView *v in self.favContainer.subviews) {
        [v removeFromSuperview];
    }
    
    NSArray *channels = [[NSUserDefaults standardUserDefaults] objectForKey:@"HSBIPTVFavorites"];
    if (!channels || ![channels isKindOfClass:[NSArray class]] || channels.count == 0) {
        channels = [self defaultFavorites];
    }
    
    NSMutableArray *filtered = [NSMutableArray array];
    for (NSDictionary *dict in channels) {
        NSString *name = dict[HSBRemotePayloadKeyName] ?: dict[@"name"] ?: @"";
        if (self.filterKeyword.length > 0) {
            if ([name localizedCaseInsensitiveContainsString:self.filterKeyword]) {
                [filtered addObject:dict];
            }
        } else {
            [filtered addObject:dict];
        }
    }
    
    UIView *lastView = nil;
    for (int i = 0; i < filtered.count; i++) {
        NSDictionary *dict = filtered[i];
        NSString *name = dict[HSBRemotePayloadKeyName] ?: dict[@"name"];
        
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
        btn.backgroundColor = [[HSBThemeManager shared].currentPalette.primaryColor colorWithAlphaComponent:0.12];
        btn.layer.cornerRadius = 12;
        btn.tintColor = [HSBThemeManager shared].currentPalette.primaryColor;
        [btn setTitle:name forState:UIControlStateNormal];
        btn.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
        btn.contentEdgeInsets = UIEdgeInsetsMake(6, 12, 6, 12);
        btn.tag = i;
        [btn addTarget:self action:@selector(channelPressed:) forControlEvents:UIControlEventTouchUpInside];
        
        UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleChannelLongPress:)];
        [btn addGestureRecognizer:longPress];
        
        btn.translatesAutoresizingMaskIntoConstraints = NO;
        [self.favContainer addSubview:btn];
        
        [NSLayoutConstraint activateConstraints:@[
            [btn.centerYAnchor constraintEqualToAnchor:self.favContainer.centerYAnchor],
            [btn.heightAnchor constraintEqualToConstant:28]
        ]];
        
        if (lastView == nil) {
            [btn.leadingAnchor constraintEqualToAnchor:self.favContainer.leadingAnchor constant:20].active = YES;
        } else {
            [btn.leadingAnchor constraintEqualToAnchor:lastView.trailingAnchor constant:8].active = YES;
        }
        lastView = btn;
    }
    if (lastView) {
        [lastView.trailingAnchor constraintEqualToAnchor:self.favContainer.trailingAnchor constant:-20].active = YES;
    }
}

- (void)channelPressed:(UIButton *)sender {
    NSArray *channels = [[NSUserDefaults standardUserDefaults] objectForKey:@"HSBIPTVFavorites"];
    if (!channels || ![channels isKindOfClass:[NSArray class]] || channels.count == 0) {
        channels = [self defaultFavorites];
    }
    
    if (sender.tag < channels.count) {
        NSDictionary *dict = channels[sender.tag];
        NSString *name = dict[HSBRemotePayloadKeyName] ?: dict[@"name"];
        NSString *chanId = dict[HSBRemotePayloadKeyId] ?: dict[@"id"];
        
        UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
        [feedback impactOccurred];
        
        NSDictionary *payload = @{
            HSBRemotePayloadKeyAction: HSBRemoteSimulateActionIPTVPlayChannel,
            HSBRemotePayloadKeyChannel: name ?: @"",
            HSBRemotePayloadKeyId: chanId ?: @"",
            HSBRemotePayloadKeyTimestamp: @([[NSDate date] timeIntervalSince1970])
        };
        
        if (self.sendPayloadBlock) {
            self.sendPayloadBlock(payload);
        } else {
            [[HSBTVOSConnectionManager sharedManager] sendPayload:payload];
        }
        [self showToast:[NSString stringWithFormat:L(@"Switched to: %@", @"已一键跳台至: %@"), name]];
    }
}

- (void)addFavoriteChannelAction {
    UIImpactFeedbackGenerator *hap = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [hap impactOccurred];
    
    [[HSBTVOSConnectionManager sharedManager] sendPayload:@{
        HSBRemotePayloadKeyAction: HSBRemoteSimulateActionIPTVAddFavorite,
        HSBRemotePayloadKeyTimestamp: @([[NSDate date] timeIntervalSince1970])
    }];
    
    [self showToast:L(@"Requesting TV to Add Favorite...", @"已请求电视将当前播放添加至收藏...")];
}

- (void)handleChannelLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        UIButton *btn = (UIButton *)gesture.view;
        NSInteger index = btn.tag;
        
        NSArray *channels = [[NSUserDefaults standardUserDefaults] objectForKey:@"HSBIPTVFavorites"];
        if (!channels || ![channels isKindOfClass:[NSArray class]] || channels.count == 0) {
            channels = [self defaultFavorites];
        }
        
        if (index < channels.count) {
            NSDictionary *dict = channels[index];
            NSString *name = dict[HSBRemotePayloadKeyName] ?: dict[@"name"];
            NSString *chanId = dict[HSBRemotePayloadKeyId] ?: dict[@"id"];
            
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:L(@"Delete Favorite", @"删除收藏")
                                                                            message:[NSString stringWithFormat:L(@"Are you sure you want to delete '%@'?", @"您确定要删除频道“%@”吗？"), name]
                                                                     preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:L(@"Delete", @"删除") style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
                [self deleteFavoriteAtIndex:index channelId:chanId];
            }]];
            [alert addAction:[UIAlertAction actionWithTitle:L(@"Cancel", @"取消") style:UIAlertActionStyleCancel handler:nil]];
            [self presentViewController:alert animated:YES completion:nil];
        }
    }
}

- (void)deleteFavoriteAtIndex:(NSInteger)index channelId:(NSString *)chanId {
    UIImpactFeedbackGenerator *hap = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [hap impactOccurred];
    
    [[HSBTVOSConnectionManager sharedManager] sendPayload:@{
        HSBRemotePayloadKeyAction: HSBRemoteSimulateActionIPTVDeleteFavorite,
        HSBRemotePayloadKeyIndex: @(index),
        HSBRemotePayloadKeyId: chanId ?: @"",
        HSBRemotePayloadKeyTimestamp: @([[NSDate date] timeIntervalSince1970])
    }];
    
    [self showToast:L(@"Requesting TV to Delete Favorite...", @"已请求电视删除此收藏频道...")];
}

- (void)showToast:(NSString *)msg {
    UILabel *toast = [[UILabel alloc] init];
    toast.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.8];
    toast.textColor = [UIColor whiteColor];
    toast.textAlignment = NSTextAlignmentCenter;
    toast.font = [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
    toast.text = msg;
    toast.layer.cornerRadius = 14;
    toast.clipsToBounds = YES;
    toast.alpha = 0.0;
    toast.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:toast];
    
    [NSLayoutConstraint activateConstraints:@[
        [toast.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [toast.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-100],
        [toast.heightAnchor constraintEqualToConstant:32],
        [toast.widthAnchor constraintGreaterThanOrEqualToConstant:160]
    ]];
    
    [UIView animateWithDuration:0.2 animations:^{
        toast.alpha = 1.0;
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.2 delay:1.2 options:0 animations:^{
            toast.alpha = 0.0;
        } completion:^(BOOL finished) {
            [toast removeFromSuperview];
        }];
    }];
}

- (void)applyThemeStyle {
    [super applyThemeStyle];
    HSBThemePalette *palette = [HSBThemeManager shared].currentPalette;
    
    self.modeSegment.selectedSegmentTintColor = palette.primaryColor;
    self.addFavBtn.tintColor = palette.primaryColor;
    self.centerBtn.tintColor = palette.primaryColor;
    self.keypadDisplayLabel.textColor = palette.primaryColor;
    
    [self reloadFavoritesUI];
}

@end
