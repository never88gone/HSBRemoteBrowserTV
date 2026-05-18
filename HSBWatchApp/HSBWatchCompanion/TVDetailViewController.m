//
//  TVDetailViewController.m
//  HSBWatchCompanion
//

#import "TVDetailViewController.h"
#import "CastViewController.h"
#import "VideoControlViewController.h"
#import "BrowserControlViewController.h"
#import "IPTVRemoteViewController.h"
#import "PDFControlViewController.h"

static inline NSString * L(NSString *en, NSString *zh) {
    NSString *language = [[NSLocale preferredLanguages] firstObject];
    if ([language hasPrefix:@"zh"]) {
        return zh ?: en;
    }
    return en;
}

@interface TVDetailViewController ()
@property (nonatomic, strong) UISegmentedControl *segmentControl;
@property (nonatomic, strong) UIView *containerView;
@property (nonatomic, strong) NSArray<UIViewController *> *childControllers;
@property (nonatomic, assign) NSInteger currentIndex;
// Redeclare blocks here to avoid old-header caching issues
@end

@implementation TVDetailViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = L(@"TV Control Center", @"电视遥控中枢");
    
    // 动态构建子控制器和 Segment Control 选项卡
    [self setupChildControllersAndItems];
    
    // Container View
    self.containerView = [[UIView alloc] init];
    self.containerView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.containerView];
    
    // Layout
    [NSLayoutConstraint activateConstraints:@[
        [self.segmentControl.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:12],
        [self.segmentControl.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [self.segmentControl.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        [self.segmentControl.heightAnchor constraintEqualToConstant:32],
        
        [self.containerView.topAnchor constraintEqualToAnchor:self.segmentControl.bottomAnchor constant:8],
        [self.containerView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.containerView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.containerView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
    
    // 默认展示动态加载出的第 0 个选项卡页面
    self.currentIndex = -1;
    [self switchToIndex:0];
    
    [self applyThemeStyle];
}

- (void)setupChildControllersAndItems {
    NSString *lowerName = self.deviceName ? [self.deviceName lowercaseString] : @"";
    
    // 1. Cast
    CastViewController *castVC = [[CastViewController alloc] init];
    castVC.sendPayloadBlock = self.sendPayloadBlock;
    
    // 2. Video
    VideoControlViewController *videoVC = [[VideoControlViewController alloc] init];
    videoVC.sendPayloadBlock = self.sendPayloadBlock;
    
    // 3. Browser
    BrowserControlViewController *browserVC = [[BrowserControlViewController alloc] init];
    browserVC.sendPayloadBlock = self.sendPayloadBlock;
    browserVC.sendActionBlock = self.sendActionBlock;
    browserVC.checkConnectionBlock = self.checkConnectionBlock;
    browserVC.editHomeBlock = self.editHomeBlock;
    
    // 4. IPTV
    IPTVRemoteViewController *iptvVC = [[IPTVRemoteViewController alloc] init];
    iptvVC.sendPayloadBlock = self.sendPayloadBlock;
    iptvVC.sendActionBlock = self.sendActionBlock;
    iptvVC.checkConnectionBlock = self.checkConnectionBlock;
    
    // 5. PDF
    PDFControlViewController *pdfVC = [[PDFControlViewController alloc] init];
    pdfVC.sendPayloadBlock = self.sendPayloadBlock;

    NSMutableArray<NSString *> *items = [NSMutableArray array];
    NSMutableArray<UIViewController *> *controllers = [NSMutableArray array];

    if ([lowerName containsString:@"pdf"] || [lowerName containsString:@"doc"] || [lowerName containsString:@"reader"] || [lowerName containsString:@"糖葫芦pdf"]) {
        // 糖葫芦PDF：显示 PDF、视频、浏览器
        [items addObject:L(@"PDF", @"PDF")];
        [controllers addObject:pdfVC];
        
        [items addObject:L(@"Video", @"视频")];
        [controllers addObject:videoVC];
        
        [items addObject:L(@"Browser", @"浏览器")];
        [controllers addObject:browserVC];
        
    } else if ([lowerName containsString:@"cast"] || [lowerName containsString:@"投屏"] || [lowerName containsString:@"糖葫芦投屏"]) {
        // 糖葫芦投屏：显示 投屏、视频、浏览器
        [items addObject:L(@"Cast", @"投屏")];
        [controllers addObject:castVC];
        
        [items addObject:L(@"Video", @"视频")];
        [controllers addObject:videoVC];
        
        [items addObject:L(@"Browser", @"浏览器")];
        [controllers addObject:browserVC];
        
    } else if ([lowerName containsString:@"browser"] || [lowerName containsString:@"web"] || [lowerName containsString:@"safari"] || [lowerName containsString:@"chrome"] || [lowerName containsString:@"浏览器"] || [lowerName containsString:@"糖葫芦浏览器"]) {
        // 糖葫芦浏览器：显示 视频、浏览器
        [items addObject:L(@"Video", @"视频")];
        [controllers addObject:videoVC];
        
        [items addObject:L(@"Browser", @"浏览器")];
        [controllers addObject:browserVC];
        
    } else if ([lowerName containsString:@"tv"] || [lowerName containsString:@"iptv"] || [lowerName containsString:@"糖葫芦tv"] || [lowerName containsString:@"糖葫芦"]) {
        // 糖葫芦TV：显示 视频、浏览器、IPTV
        [items addObject:L(@"Video", @"视频")];
        [controllers addObject:videoVC];
        
        [items addObject:L(@"Browser", @"浏览器")];
        [controllers addObject:browserVC];
        
        [items addObject:L(@"IPTV", @"IPTV")];
        [controllers addObject:iptvVC];
        
    } else {
        // 兜底（Fallback）：全部显示
        [items addObject:L(@"Cast", @"投屏")];
        [controllers addObject:castVC];
        
        [items addObject:L(@"Video", @"视频")];
        [controllers addObject:videoVC];
        
        [items addObject:L(@"Browser", @"浏览器")];
        [controllers addObject:browserVC];
        
        [items addObject:L(@"IPTV", @"IPTV")];
        [controllers addObject:iptvVC];
        
        [items addObject:L(@"PDF", @"PDF")];
        [controllers addObject:pdfVC];
    }

    self.childControllers = [controllers copy];
    
    self.segmentControl = [[UISegmentedControl alloc] initWithItems:items];
    self.segmentControl.selectedSegmentIndex = 0;
    [self.segmentControl addTarget:self action:@selector(segmentChanged:) forControlEvents:UIControlEventValueChanged];
    self.segmentControl.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.segmentControl];
}

- (void)switchToIndex:(NSInteger)index {
    if (index == self.currentIndex) return;
    if (index < 0 || index >= (NSInteger)self.childControllers.count) return;
    
    // Remove old
    if (self.currentIndex >= 0 && self.currentIndex < (NSInteger)self.childControllers.count) {
        UIViewController *oldVC = self.childControllers[self.currentIndex];
        [oldVC willMoveToParentViewController:nil];
        [oldVC.view removeFromSuperview];
        [oldVC removeFromParentViewController];
    }
    
    // Add new
    UIViewController *newVC = self.childControllers[index];
    [self addChildViewController:newVC];
    newVC.view.frame = self.containerView.bounds;
    newVC.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.containerView addSubview:newVC.view];
    [newVC didMoveToParentViewController:self];
    
    self.currentIndex = index;
}

- (void)segmentChanged:(UISegmentedControl *)seg {
    [self switchToIndex:seg.selectedSegmentIndex];
}

- (void)applyThemeStyle {
    [super applyThemeStyle];
    HSBThemePalette *palette = [HSBThemeManager shared].currentPalette;
    
    if (self.segmentControl) {
        self.segmentControl.selectedSegmentTintColor = palette.primaryColor;
        if (@available(iOS 13.0, *)) {
            [self.segmentControl setTitleTextAttributes:@{NSForegroundColorAttributeName: [[UIColor whiteColor] colorWithAlphaComponent:0.6]} forState:UIControlStateNormal];
            [self.segmentControl setTitleTextAttributes:@{NSForegroundColorAttributeName: [UIColor whiteColor]} forState:UIControlStateSelected];
        }
    }
    
    for (UIViewController *child in self.childControllers) {
        if ([child isKindOfClass:[HSBBaseViewController class]]) {
            [(HSBBaseViewController *)child applyThemeStyle];
        }
    }
}

- (void)dismissSelf {
    [self.navigationController popViewControllerAnimated:YES];
}

@end
