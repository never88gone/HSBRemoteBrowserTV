//
//  TVDetailViewController.m
//  HSBWatchCompanion
//

#import "TVDetailViewController.h"
#import "CastViewController.h"
#import "VideoControlViewController.h"
#import "BrowserControlViewController.h"
#import "IPTVRemoteViewController.h"

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
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    self.title = L(@"TV Control Center", @"电视遥控中枢");
    

    // Segment Control
    self.segmentControl = [[UISegmentedControl alloc] initWithItems:@[
        L(@"Cast", @"投屏"),
        L(@"Video", @"视频"),
        L(@"Browser", @"浏览器"),
        L(@"IPTV", @"IPTV")
    ]];
    self.segmentControl.selectedSegmentIndex = 3; // Default: IPTV
    [self.segmentControl addTarget:self action:@selector(segmentChanged:) forControlEvents:UIControlEventValueChanged];
    self.segmentControl.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.segmentControl];
    
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
    
    // Build child controllers
    [self setupChildControllers];
    
    // Show default (IPTV)
    self.currentIndex = -1;
    [self switchToIndex:3];
}

- (void)setupChildControllers {
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
    
    self.childControllers = @[castVC, videoVC, browserVC, iptvVC];
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

- (void)dismissSelf {
    [self.navigationController popViewControllerAnimated:YES];
}

@end
