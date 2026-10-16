#import "HSBIPTVFavoritesBarView.h"
#import "HSBThemeManager.h"
#import "HSBTVOSConnectionManager.h"

static inline NSString * L(NSString *en, NSString *zh) {
    NSString *language = [[NSLocale preferredLanguages] firstObject];
    if ([language hasPrefix:@"zh"]) {
        return zh ?: en;
    }
    return en;
}

@interface HSBIPTVFavoritesBarView () <UISearchBarDelegate>

@property (nonatomic, strong) UIImageView *favHeartIcon;
@property (nonatomic, strong) UILabel *favTitleLabel;
@property (nonatomic, strong) UIButton *addFavBtn;
@property (nonatomic, strong) UIButton *searchToggleBtn;
@property (nonatomic, strong) UISearchBar *favSearchBar;
@property (nonatomic, strong) UIScrollView *favScrollView;
@property (nonatomic, strong) UIView *favContainer;
@property (nonatomic, copy) NSString *filterKeyword;

@end

@implementation HSBIPTVFavoritesBarView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupUI];
    }
    return self;
}

- (void)setupUI {
    self.favHeartIcon = [[UIImageView alloc] init];
    self.favHeartIcon.image = [UIImage systemImageNamed:@"heart.fill"];
    self.favHeartIcon.tintColor = [UIColor systemPinkColor];
    self.favHeartIcon.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.favHeartIcon];
    
    self.favTitleLabel = [[UILabel alloc] init];
    self.favTitleLabel.text = L(@"Favorite Channels", @"我的收藏频道");
    self.favTitleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
    self.favTitleLabel.textColor = [UIColor secondaryLabelColor];
    self.favTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.favTitleLabel];
    
    self.addFavBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.addFavBtn setImage:[UIImage systemImageNamed:@"plus.circle.fill" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightSemibold]] forState:UIControlStateNormal];
    self.addFavBtn.tintColor = [HSBThemeManager shared].currentPalette.primaryColor;
    [self.addFavBtn addTarget:self action:@selector(addFavoriteChannelAction) forControlEvents:UIControlEventTouchUpInside];
    self.addFavBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.addFavBtn];
    
    self.searchToggleBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.searchToggleBtn setImage:[UIImage systemImageNamed:@"magnifyingglass" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:13 weight:UIImageSymbolWeightSemibold]] forState:UIControlStateNormal];
    self.searchToggleBtn.tintColor = [UIColor secondaryLabelColor];
    [self.searchToggleBtn addTarget:self action:@selector(toggleSearchBar) forControlEvents:UIControlEventTouchUpInside];
    self.searchToggleBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.searchToggleBtn];
    
    self.favSearchBar = [[UISearchBar alloc] init];
    self.favSearchBar.placeholder = L(@"Filter favorites...", @"搜索收藏频道");
    self.favSearchBar.searchBarStyle = UISearchBarStyleMinimal;
    self.favSearchBar.delegate = self;
    self.favSearchBar.hidden = YES;
    self.favSearchBar.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.favSearchBar];
    
    self.favScrollView = [[UIScrollView alloc] init];
    self.favScrollView.showsHorizontalScrollIndicator = NO;
    self.favScrollView.alwaysBounceHorizontal = YES;
    self.favScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.favScrollView];
    
    self.favContainer = [[UIView alloc] init];
    self.favContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [self.favScrollView addSubview:self.favContainer];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.favHeartIcon.topAnchor constraintEqualToAnchor:self.topAnchor constant:4],
        [self.favHeartIcon.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:20],
        [self.favHeartIcon.widthAnchor constraintEqualToConstant:14],
        [self.favHeartIcon.heightAnchor constraintEqualToConstant:14],
        
        [self.favTitleLabel.centerYAnchor constraintEqualToAnchor:self.favHeartIcon.centerYAnchor],
        [self.favTitleLabel.leadingAnchor constraintEqualToAnchor:self.favHeartIcon.trailingAnchor constant:6],
        
        [self.addFavBtn.centerYAnchor constraintEqualToAnchor:self.favHeartIcon.centerYAnchor],
        [self.addFavBtn.leadingAnchor constraintEqualToAnchor:self.favTitleLabel.trailingAnchor constant:6],
        [self.addFavBtn.widthAnchor constraintEqualToConstant:18],
        [self.addFavBtn.heightAnchor constraintEqualToConstant:18],
        
        [self.searchToggleBtn.centerYAnchor constraintEqualToAnchor:self.favHeartIcon.centerYAnchor],
        [self.searchToggleBtn.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-20],
        [self.searchToggleBtn.widthAnchor constraintEqualToConstant:24],
        [self.searchToggleBtn.heightAnchor constraintEqualToConstant:24],
        
        [self.favSearchBar.topAnchor constraintEqualToAnchor:self.favTitleLabel.bottomAnchor constant:4],
        [self.favSearchBar.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:12],
        [self.favSearchBar.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-12],
        [self.favSearchBar.heightAnchor constraintEqualToConstant:36],
        
        [self.favScrollView.topAnchor constraintEqualToAnchor:self.favTitleLabel.bottomAnchor constant:8],
        [self.favScrollView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [self.favScrollView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [self.favScrollView.heightAnchor constraintEqualToConstant:36],
        [self.favScrollView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
        
        [self.favContainer.topAnchor constraintEqualToAnchor:self.favScrollView.topAnchor],
        [self.favContainer.leadingAnchor constraintEqualToAnchor:self.favScrollView.leadingAnchor],
        [self.favContainer.trailingAnchor constraintEqualToAnchor:self.favScrollView.trailingAnchor],
        [self.favContainer.bottomAnchor constraintEqualToAnchor:self.favScrollView.bottomAnchor],
        [self.favContainer.heightAnchor constraintEqualToAnchor:self.favScrollView.heightAnchor]
    ]];
    
    [self reloadFavorites];
}

- (void)toggleSearchBar {
    UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [fb impactOccurred];
    
    self.favSearchBar.hidden = !self.favSearchBar.hidden;
    if (self.favSearchBar.hidden) {
        [self.favSearchBar resignFirstResponder];
        self.favSearchBar.text = @"";
        self.filterKeyword = nil;
        [self reloadFavorites];
    } else {
        [self.favSearchBar becomeFirstResponder];
    }
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    self.filterKeyword = [searchText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    [self reloadFavorites];
}

- (void)reloadFavorites {
    if (!self.favContainer) return;
    
    for (UIView *v in self.favContainer.subviews) {
        [v removeFromSuperview];
    }
    
    NSArray *channels = [[NSUserDefaults standardUserDefaults] objectForKey:@"HSBIPTVFavorites"];
    if (![channels isKindOfClass:[NSArray class]]) channels = @[];
    
    NSMutableArray<NSNumber *> *filteredIndices = [NSMutableArray array];
    for (NSUInteger index = 0; index < channels.count; index++) {
        NSDictionary *dict = channels[index];
        if (![dict isKindOfClass:[NSDictionary class]]) continue;
        NSString *name = dict[HSBRemotePayloadKeyName] ?: dict[@"name"] ?: @"";
        if (self.filterKeyword.length > 0) {
            if ([name localizedCaseInsensitiveContainsString:self.filterKeyword]) {
                [filteredIndices addObject:@(index)];
            }
        } else {
            [filteredIndices addObject:@(index)];
        }
    }
    
    UIView *lastView = nil;
    for (NSNumber *originalIndex in filteredIndices) {
        NSDictionary *dict = channels[originalIndex.unsignedIntegerValue];
        NSString *name = dict[HSBRemotePayloadKeyName] ?: dict[@"name"];
        
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
        btn.backgroundColor = [[HSBThemeManager shared].currentPalette.primaryColor colorWithAlphaComponent:0.12];
        btn.layer.cornerRadius = 12;
        btn.tintColor = [HSBThemeManager shared].currentPalette.primaryColor;
        [btn setTitle:name forState:UIControlStateNormal];
        btn.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
        btn.contentEdgeInsets = UIEdgeInsetsMake(6, 12, 6, 12);
        btn.tag = originalIndex.integerValue;
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
    if (![channels isKindOfClass:[NSArray class]]) return;
    
    if (sender.tag >= 0 && sender.tag < channels.count) {
        NSDictionary *dict = channels[sender.tag];
        if (![dict isKindOfClass:[NSDictionary class]]) return;
        NSString *name = dict[HSBRemotePayloadKeyName] ?: dict[@"name"];
        NSString *chanId = dict[HSBRemotePayloadKeyId] ?: dict[@"id"];
        
        UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
        [feedback impactOccurred];
        
        if (self.onSelectChannelBlock) {
            self.onSelectChannelBlock(name ?: @"", chanId ?: @"");
        }
    }
}

- (void)addFavoriteChannelAction {
    UIImpactFeedbackGenerator *hap = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [hap impactOccurred];
    if (self.onRequestAddFavoriteBlock) {
        self.onRequestAddFavoriteBlock();
    }
}

- (void)handleChannelLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        UIButton *btn = (UIButton *)gesture.view;
        NSInteger index = btn.tag;
        
        NSArray *channels = [[NSUserDefaults standardUserDefaults] objectForKey:@"HSBIPTVFavorites"];
        if (![channels isKindOfClass:[NSArray class]]) return;
        
        if (index >= 0 && index < channels.count) {
            NSDictionary *dict = channels[index];
            if (![dict isKindOfClass:[NSDictionary class]]) return;
            NSString *name = dict[HSBRemotePayloadKeyName] ?: dict[@"name"];
            NSString *chanId = dict[HSBRemotePayloadKeyId] ?: dict[@"id"];
            
            if (self.onRequestDeleteFavoriteBlock) {
                self.onRequestDeleteFavoriteBlock(index, chanId ?: @"", name ?: @"");
            }
        }
    }
}

- (void)applyThemeStyle {
    self.addFavBtn.tintColor = [HSBThemeManager shared].currentPalette.primaryColor;
    [self reloadFavorites];
}

@end
