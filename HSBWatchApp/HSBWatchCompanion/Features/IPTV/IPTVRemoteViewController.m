//
//  IPTVRemoteViewController.m
//  HSBWatchCompanion
//

#import "IPTVRemoteViewController.h"
#import "HSBThemeManager.h"
#import "HSBTVOSConnectionManager.h"
#import "HSBIPTVFavoritesBarView.h"
#import "HSBIPTVKeypadView.h"
#import "HSBIPTVDPadView.h"

static inline NSString * L(NSString *en, NSString *zh) {
    NSString *language = [[NSLocale preferredLanguages] firstObject];
    if ([language hasPrefix:@"zh"]) {
        return zh ?: en;
    }
    return en;
}

@interface IPTVRemoteViewController ()

@property (nonatomic, strong) UISegmentedControl *modeSegment;
@property (nonatomic, strong) HSBIPTVFavoritesBarView *favoritesBar;
@property (nonatomic, strong) HSBIPTVDPadView *dpadModeView;
@property (nonatomic, strong) HSBIPTVKeypadView *keypadModeView;

// Bottom Action Controls
@property (nonatomic, strong) UIStackView *bottomActionStack;
@property (nonatomic, strong) UIButton *menuBtn;
@property (nonatomic, strong) NSMutableArray<UIButton *> *extraActionBtns;

@end

@implementation IPTVRemoteViewController

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.extraActionBtns = [NSMutableArray array];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleFavoritesUpdated:) name:HSBIPTVFavoritesUpdatedNotification object:nil];
    
    [self setupTopControls];
    [self setupFavoritesArea];
    [self setupDPadModeView];
    [self setupKeypadModeView];
    [self setupBottomControls];
    
    self.dpadModeView.hidden = NO;
    self.keypadModeView.hidden = YES;
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
    self.favoritesBar = [[HSBIPTVFavoritesBarView alloc] initWithFrame:CGRectZero];
    self.favoritesBar.translatesAutoresizingMaskIntoConstraints = NO;
    __weak typeof(self) weakSelf = self;
    self.favoritesBar.onSelectChannelBlock = ^(NSString * _Nonnull name, NSString * _Nonnull channelId) {
        [weakSelf playChannelWithName:name channelId:channelId];
    };
    self.favoritesBar.onRequestAddFavoriteBlock = ^{
        [weakSelf addFavoriteChannelAction];
    };
    self.favoritesBar.onRequestDeleteFavoriteBlock = ^(NSInteger index, NSString * _Nonnull channelId, NSString * _Nonnull channelName) {
        [weakSelf confirmDeleteFavoriteAtIndex:index channelId:channelId channelName:channelName];
    };
    [self.view addSubview:self.favoritesBar];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.favoritesBar.topAnchor constraintEqualToAnchor:self.modeSegment.bottomAnchor constant:8],
        [self.favoritesBar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.favoritesBar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.favoritesBar.heightAnchor constraintEqualToConstant:68]
    ]];
}

- (void)setupDPadModeView {
    self.dpadModeView = [[HSBIPTVDPadView alloc] initWithFrame:CGRectZero];
    self.dpadModeView.translatesAutoresizingMaskIntoConstraints = NO;
    __weak typeof(self) weakSelf = self;
    self.dpadModeView.onActionTriggeredBlock = ^(HSBRemoteSimulateAction  _Nonnull action) {
        [weakSelf triggerSimulateAction:action];
    };
    [self.view addSubview:self.dpadModeView];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.dpadModeView.topAnchor constraintEqualToAnchor:self.favoritesBar.bottomAnchor constant:12],
        [self.dpadModeView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.dpadModeView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.dpadModeView.heightAnchor constraintEqualToConstant:210]
    ]];
}

- (void)setupKeypadModeView {
    self.keypadModeView = [[HSBIPTVKeypadView alloc] initWithFrame:CGRectZero];
    self.keypadModeView.translatesAutoresizingMaskIntoConstraints = NO;
    __weak typeof(self) weakSelf = self;
    self.keypadModeView.onCommitChannelBlock = ^(NSString * _Nonnull channelDigits) {
        [weakSelf tuneToChannelNumber:channelDigits];
    };
    [self.view addSubview:self.keypadModeView];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.keypadModeView.topAnchor constraintEqualToAnchor:self.favoritesBar.bottomAnchor constant:12],
        [self.keypadModeView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.keypadModeView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.keypadModeView.heightAnchor constraintEqualToConstant:210]
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

#pragma mark - Mode Switch

- (void)modeSegmentChanged:(UISegmentedControl *)seg {
    UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [fb impactOccurred];
    
    BOOL isDpad = (seg.selectedSegmentIndex == 0);
    self.dpadModeView.hidden = !isDpad;
    self.keypadModeView.hidden = isDpad;
}

#pragma mark - Helper Factory

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

- (void)sendMenu { [self triggerSimulateAction:HSBRemoteSimulateActionMenu]; }
- (void)sendEPG { [self triggerSimulateAction:HSBRemoteSimulateActionIPTVEpg]; }
- (void)sendRefresh { [self triggerSimulateAction:HSBRemoteSimulateActionIPTVRefresh]; }

#pragma mark - Keypad Channel Tune

- (void)tuneToChannelNumber:(NSString *)chan {
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
}

#pragma mark - Favorites Control

- (void)handleFavoritesUpdated:(NSNotification *)note {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.favoritesBar reloadFavorites];
    });
}

- (void)playChannelWithName:(NSString *)name channelId:(NSString *)chanId {
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

- (void)addFavoriteChannelAction {
    [[HSBTVOSConnectionManager sharedManager] sendPayload:@{
        HSBRemotePayloadKeyAction: HSBRemoteSimulateActionIPTVAddFavorite,
        HSBRemotePayloadKeyTimestamp: @([[NSDate date] timeIntervalSince1970])
    }];
    [self showToast:L(@"Requesting TV to Add Favorite...", @"已请求电视将当前播放添加至收藏...")];
}

- (void)confirmDeleteFavoriteAtIndex:(NSInteger)index channelId:(NSString *)chanId channelName:(NSString *)name {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:L(@"Delete Favorite", @"删除收藏")
                                                                    message:[NSString stringWithFormat:L(@"Are you sure you want to delete '%@'?", @"您确定要删除频道“%@”吗？"), name]
                                                             preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:L(@"Delete", @"删除") style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        [self deleteFavoriteAtIndex:index channelId:chanId];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:L(@"Cancel", @"取消") style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
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
    
    [self.dpadModeView applyThemeStyle];
    [self.favoritesBar applyThemeStyle];
    [self.keypadModeView applyThemeStyle];
}

@end
