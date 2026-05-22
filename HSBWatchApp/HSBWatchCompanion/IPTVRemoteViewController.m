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

@interface IPTVRemoteViewController ()

@property (nonatomic, strong) UIImageView *favHeartIcon;
@property (nonatomic, strong) UILabel *favTitleLabel;
@property (nonatomic, strong) UIButton *addFavBtn;
@property (nonatomic, strong) UIScrollView *favScrollView;
@property (nonatomic, strong) UIView *favContainer;

@property (nonatomic, strong) UIView *dpadContainer;
@property (nonatomic, strong) UIButton *centerBtn;
@property (nonatomic, strong) UIButton *menuBtn;
@property (nonatomic, strong) NSMutableArray<UIButton *> *extraActionBtns;
@property (nonatomic, strong) NSMutableArray<UIButton *> *dpadDirectionBtns;

@end

@implementation IPTVRemoteViewController

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // 监听电视端 IPTV 收藏更新通知
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleFavoritesUpdated:) name:@"HSBIPTVFavoritesUpdatedNotification" object:nil];
    
    // 1. Create Favorites Area
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
    
    self.favScrollView = [[UIScrollView alloc] init];
    self.favScrollView.showsHorizontalScrollIndicator = NO;
    self.favScrollView.alwaysBounceHorizontal = YES;
    self.favScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.favScrollView];
    
    self.favContainer = [[UIView alloc] init];
    self.favContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [self.favScrollView addSubview:self.favContainer];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.favHeartIcon.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:12],
        [self.favHeartIcon.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [self.favHeartIcon.widthAnchor constraintEqualToConstant:14],
        [self.favHeartIcon.heightAnchor constraintEqualToConstant:14],
        
        [self.favTitleLabel.centerYAnchor constraintEqualToAnchor:self.favHeartIcon.centerYAnchor],
        [self.favTitleLabel.leadingAnchor constraintEqualToAnchor:self.favHeartIcon.trailingAnchor constant:6],
        
        [self.addFavBtn.centerYAnchor constraintEqualToAnchor:self.favHeartIcon.centerYAnchor],
        [self.addFavBtn.leadingAnchor constraintEqualToAnchor:self.favTitleLabel.trailingAnchor constant:6],
        [self.addFavBtn.widthAnchor constraintEqualToConstant:18],
        [self.addFavBtn.heightAnchor constraintEqualToConstant:18],
        
        [self.favScrollView.topAnchor constraintEqualToAnchor:self.favTitleLabel.bottomAnchor constant:8],
        [self.favScrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.favScrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.favScrollView.heightAnchor constraintEqualToConstant:40],
        
        [self.favContainer.topAnchor constraintEqualToAnchor:self.favScrollView.topAnchor],
        [self.favContainer.leadingAnchor constraintEqualToAnchor:self.favScrollView.leadingAnchor],
        [self.favContainer.trailingAnchor constraintEqualToAnchor:self.favScrollView.trailingAnchor],
        [self.favContainer.bottomAnchor constraintEqualToAnchor:self.favScrollView.bottomAnchor],
        [self.favContainer.heightAnchor constraintEqualToAnchor:self.favScrollView.heightAnchor]
    ]];
    
    [self reloadFavoritesUI];
    
    self.extraActionBtns = [NSMutableArray array];
    self.dpadDirectionBtns = [NSMutableArray array];
    
    // Create D-Pad Container
    self.dpadContainer = [[UIView alloc] init];
    self.dpadContainer.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.06];
    self.dpadContainer.layer.cornerRadius = 120;
    self.dpadContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.dpadContainer];
    
    // Create D-Pad Buttons
    UIButton *upBtn = [self createDPadButtonWithIcon:@"chevron.up" action:@selector(sendUp)];
    UIButton *downBtn = [self createDPadButtonWithIcon:@"chevron.down" action:@selector(sendDown)];
    UIButton *leftBtn = [self createDPadButtonWithIcon:@"chevron.left" action:@selector(sendLeft)];
    UIButton *rightBtn = [self createDPadButtonWithIcon:@"chevron.right" action:@selector(sendRight)];
    self.centerBtn = [self createDPadButtonWithIcon:@"circle.fill" action:@selector(sendSelect)];
    
    // Make center button pop a bit
    self.centerBtn.tintColor = [HSBThemeManager shared].currentPalette.primaryColor;
    
    [self.dpadDirectionBtns addObject:upBtn];
    [self.dpadDirectionBtns addObject:downBtn];
    [self.dpadDirectionBtns addObject:leftBtn];
    [self.dpadDirectionBtns addObject:rightBtn];
    
    for (UIButton *btn in self.dpadDirectionBtns) {
        btn.tintColor = [UIColor whiteColor];
    }
    
    [self.dpadContainer addSubview:upBtn];
    [self.dpadContainer addSubview:downBtn];
    [self.dpadContainer addSubview:leftBtn];
    [self.dpadContainer addSubview:rightBtn];
    [self.dpadContainer addSubview:self.centerBtn];
    
    // Layout D-Pad
    [NSLayoutConstraint activateConstraints:@[
        [self.dpadContainer.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.dpadContainer.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:-60],
        [self.dpadContainer.widthAnchor constraintEqualToConstant:240],
        [self.dpadContainer.heightAnchor constraintEqualToConstant:240],
        
        [self.centerBtn.centerXAnchor constraintEqualToAnchor:self.dpadContainer.centerXAnchor],
        [self.centerBtn.centerYAnchor constraintEqualToAnchor:self.dpadContainer.centerYAnchor],
        [self.centerBtn.widthAnchor constraintEqualToConstant:60],
        [self.centerBtn.heightAnchor constraintEqualToConstant:60],
        
        [upBtn.centerXAnchor constraintEqualToAnchor:self.dpadContainer.centerXAnchor],
        [upBtn.topAnchor constraintEqualToAnchor:self.dpadContainer.topAnchor constant:10],
        [upBtn.widthAnchor constraintEqualToConstant:60],
        [upBtn.heightAnchor constraintEqualToConstant:60],
        
        [downBtn.centerXAnchor constraintEqualToAnchor:self.dpadContainer.centerXAnchor],
        [downBtn.bottomAnchor constraintEqualToAnchor:self.dpadContainer.bottomAnchor constant:-10],
        [downBtn.widthAnchor constraintEqualToConstant:60],
        [downBtn.heightAnchor constraintEqualToConstant:60],
        
        [leftBtn.centerYAnchor constraintEqualToAnchor:self.dpadContainer.centerYAnchor],
        [leftBtn.leadingAnchor constraintEqualToAnchor:self.dpadContainer.leadingAnchor constant:10],
        [leftBtn.widthAnchor constraintEqualToConstant:60],
        [leftBtn.heightAnchor constraintEqualToConstant:60],
        
        [rightBtn.centerYAnchor constraintEqualToAnchor:self.dpadContainer.centerYAnchor],
        [rightBtn.trailingAnchor constraintEqualToAnchor:self.dpadContainer.trailingAnchor constant:-10],
        [rightBtn.widthAnchor constraintEqualToConstant:60],
        [rightBtn.heightAnchor constraintEqualToConstant:60],
    ]];
    
    // Create IPTV Extra Controls Stack View
    UIStackView *extraControlsStack = [[UIStackView alloc] init];
    extraControlsStack.axis = UILayoutConstraintAxisHorizontal;
    extraControlsStack.distribution = UIStackViewDistributionFillEqually;
    extraControlsStack.spacing = 12;
    extraControlsStack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:extraControlsStack];
    
    UIButton *epgBtn = [self createControlButtonWithIcon:@"list.bullet.rectangle" title:L(@"EPG", @"节目单") action:@selector(sendEPG)];
    UIButton *channelsBtn = [self createControlButtonWithIcon:@"list.bullet" title:L(@"Channels", @"选台") action:@selector(sendChannels)];
    UIButton *refreshBtn = [self createControlButtonWithIcon:@"arrow.clockwise" title:L(@"Refresh", @"刷新") action:@selector(sendRefresh)];
    
    [self.extraActionBtns addObject:epgBtn];
    [self.extraActionBtns addObject:channelsBtn];
    [self.extraActionBtns addObject:refreshBtn];
    
    for (UIButton *btn in self.extraActionBtns) {
        btn.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.08];
        btn.tintColor = [UIColor whiteColor];
    }
    
    [extraControlsStack addArrangedSubview:epgBtn];
    [extraControlsStack addArrangedSubview:channelsBtn];
    [extraControlsStack addArrangedSubview:refreshBtn];
    
    // Create Menu Button
    self.menuBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.menuBtn setTitle:L(@"Menu", @"菜单/返回") forState:UIControlStateNormal];
    self.menuBtn.titleLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightBold];
    self.menuBtn.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.08];
    self.menuBtn.layer.cornerRadius = 16;
    [self.menuBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.menuBtn addTarget:self action:@selector(sendMenu) forControlEvents:UIControlEventTouchUpInside];
    self.menuBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.menuBtn];
    
    // Layout bottom controls
    [NSLayoutConstraint activateConstraints:@[
        [extraControlsStack.topAnchor constraintEqualToAnchor:self.dpadContainer.bottomAnchor constant:30],
        [extraControlsStack.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:24],
        [extraControlsStack.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-24],
        [extraControlsStack.heightAnchor constraintEqualToConstant:48],
        
        [self.menuBtn.topAnchor constraintEqualToAnchor:extraControlsStack.bottomAnchor constant:16],
        [self.menuBtn.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.menuBtn.widthAnchor constraintEqualToConstant:140],
        [self.menuBtn.heightAnchor constraintEqualToConstant:48]
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

- (UIButton *)createControlButtonWithIcon:(NSString *)iconName title:(NSString *)title action:(SEL)selector {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    btn.backgroundColor = [UIColor secondarySystemFillColor];
    btn.layer.cornerRadius = 12;
    btn.tintColor = [UIColor labelColor];
    
    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:16 weight:UIImageSymbolWeightSemibold];
    UIImage *image = [UIImage systemImageNamed:iconName withConfiguration:config];
    [btn setImage:image forState:UIControlStateNormal];
    [btn setTitle:[NSString stringWithFormat:@" %@", title] forState:UIControlStateNormal];
    
    btn.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightBold];
    [btn addTarget:self action:selector forControlEvents:UIControlEventTouchUpInside];
    btn.translatesAutoresizingMaskIntoConstraints = NO;
    
    return btn;
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
    } else {
        [[HSBTVOSConnectionManager sharedManager] sendAction:action];
    }
}

- (void)triggerSimulateAction:(HSBRemoteSimulateAction)action {
    if (self.checkConnectionBlock && !self.checkConnectionBlock()) {
        NSLog(@"[IPTVRemote] TV not connected.");
        return;
    }
    
    UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [feedback impactOccurred];
    
    if (self.sendPayloadBlock) {
        self.sendPayloadBlock(@{@"action": action});
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
- (void)sendEPG { [self triggerAction:@"iptv_epg"]; }
- (void)sendChannels { [self triggerAction:@"iptv_channels"]; }
- (void)sendRefresh { [self triggerAction:@"iptv_refresh"]; }

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (self.sendPayloadBlock) {
        self.sendPayloadBlock(@{
            @"action": @"get_favorites",
            @"timestamp": @([[NSDate date] timeIntervalSince1970])
        });
    }
}

#pragma mark - Favorites Control

- (NSArray<NSDictionary *> *)defaultFavorites {
    return @[
        @{@"name": L(@"CCTV-1 General", @"CCTV-1 综合"), @"id": @"cctv1"},
        @{@"name": L(@"CCTV-5 Sports", @"CCTV-5 体育"), @"id": @"cctv5"},
        @{@"name": L(@"CCTV-13 News", @"CCTV-13 新闻"), @"id": @"cctv13"},
        @{@"name": L(@"Hunan TV", @"湖南卫视"), @"id": @"hunantv"},
        @{@"name": L(@"Dragon TV", @"东方卫视"), @"id": @"dongfangtv"},
        @{@"name": L(@"Zhejiang TV", @"浙江卫视"), @"id": @"zhejiangtv"}
    ];
}

- (void)handleFavoritesUpdated:(NSNotification *)note {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self reloadFavoritesUI];
    });
}

- (void)reloadFavoritesUI {
    if (!self.favContainer) return;
    
    // 移除已有频道卡片
    for (UIView *v in self.favContainer.subviews) {
        [v removeFromSuperview];
    }
    
    NSArray *channels = [[NSUserDefaults standardUserDefaults] objectForKey:@"HSBIPTVFavorites"];
    if (!channels || ![channels isKindOfClass:[NSArray class]] || channels.count == 0) {
        channels = [self defaultFavorites];
    }
    
    UIView *lastView = nil;
    for (int i = 0; i < channels.count; i++) {
        NSDictionary *dict = channels[i];
        NSString *name = dict[@"name"];
        
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

- (void)applyThemeStyle {
    [super applyThemeStyle];
    HSBThemePalette *palette = [HSBThemeManager shared].currentPalette;
    
    self.favTitleLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.6];
    self.dpadContainer.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.06];
    self.centerBtn.tintColor = palette.primaryColor;
    
    self.menuBtn.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.08];
    [self.menuBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    
    for (UIButton *btn in self.dpadDirectionBtns) {
        btn.tintColor = [UIColor whiteColor];
    }
    
    for (UIButton *btn in self.extraActionBtns) {
        btn.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.08];
        btn.tintColor = [UIColor whiteColor];
    }
    
    [self reloadFavoritesUI];
}

- (void)channelPressed:(UIButton *)sender {
    NSArray *channels = [[NSUserDefaults standardUserDefaults] objectForKey:@"HSBIPTVFavorites"];
    if (!channels || ![channels isKindOfClass:[NSArray class]] || channels.count == 0) {
        channels = [self defaultFavorites];
    }
    
    if (sender.tag < channels.count) {
        NSDictionary *dict = channels[sender.tag];
        NSString *name = dict[@"name"];
        NSString *chanId = dict[@"id"];
        
        UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
        [feedback impactOccurred];
        
        NSDictionary *payload = @{
            @"action": @"play_channel",
            @"channel": name,
            @"id": chanId ?: @"",
            @"timestamp": @([[NSDate date] timeIntervalSince1970])
        };
        
        if (self.sendPayloadBlock) {
            self.sendPayloadBlock(payload);
        } else {
            [[HSBTVOSConnectionManager sharedManager] sendPayload:payload];
        }
        [self showToast:[NSString stringWithFormat:L(@"Switched to: %@", @"已一键跳台至: %@"), name]];
    }
}

- (void)showToast:(NSString *)msg {
    UILabel *toast = [[UILabel alloc] init];
    toast.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.75];
    toast.textColor = [UIColor whiteColor];
    toast.textAlignment = NSTextAlignmentCenter;
    toast.font = [UIFont systemFontOfSize:12 weight:UIFontWeightBold];
    toast.text = msg;
    toast.layer.cornerRadius = 14;
    toast.clipsToBounds = YES;
    toast.alpha = 0.0;
    toast.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:toast];
    
    [NSLayoutConstraint activateConstraints:@[
        [toast.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [toast.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-120],
        [toast.heightAnchor constraintEqualToConstant:28],
        [toast.widthAnchor constraintGreaterThanOrEqualToConstant:140]
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

#pragma mark - Custom Favorites Actions (Sync via TVOS)

- (void)addFavoriteChannelAction {
    UIImpactFeedbackGenerator *hap = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [hap impactOccurred];
    
    // 向电视端下发 add_favorite 命令，由电视端进行真正的收藏并回传新数组
    [[HSBTVOSConnectionManager sharedManager] sendPayload:@{
        @"action": @"add_favorite",
        @"timestamp": @([[NSDate date] timeIntervalSince1970])
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
            NSString *name = dict[@"name"];
            NSString *chanId = dict[@"id"];
            
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
    
    // 向电视端下发 delete_favorite 消息，由电视端处理并同步回最新的收藏列表
    [[HSBTVOSConnectionManager sharedManager] sendPayload:@{
        @"action": @"delete_favorite",
        @"index": @(index),
        @"id": chanId ?: @"",
        @"timestamp": @([[NSDate date] timeIntervalSince1970])
    }];
    
    [self showToast:L(@"Requesting TV to Delete Favorite...", @"已请求电视删除此收藏频道...")];
}

@end
