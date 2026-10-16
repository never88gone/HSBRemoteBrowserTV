//
//  HSBBaseViewController.m
//  HSBWatchCompanion
//

#import "HSBBaseViewController.h"

@interface HSBBaseViewController ()
@property (nonatomic, strong, readwrite, nullable) CAGradientLayer *backgroundGradientLayer;
@end

@implementation HSBBaseViewController

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // 设置深空极光自然渐变背景层
    self.view.backgroundColor = [UIColor clearColor];
    if (!self.backgroundGradientLayer) {
        self.backgroundGradientLayer = [HSBThemeManager createBrandGradientLayerWithBounds:self.view.bounds];
        [self.view.layer insertSublayer:self.backgroundGradientLayer atIndex:0];
    }
    
    // 监听全局主题变更通知
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleThemeChangedNotification:)
                                                 name:HSBThemeChangedNotification
                                               object:nil];
    
    [self applyThemeStyle];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    if (self.backgroundGradientLayer) {
        self.backgroundGradientLayer.frame = self.view.bounds;
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self applyThemeStyle];
}

- (void)handleThemeChangedNotification:(NSNotification *)note {
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        [weakSelf applyThemeStyle];
    });
}

- (void)applyThemeStyle {
    if (@available(iOS 13.0, *)) {
        self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    }
    
    HSBThemePalette *palette = [HSBThemeManager shared].currentPalette;
    
    self.view.backgroundColor = [UIColor clearColor];
    if (self.backgroundGradientLayer) {
        self.backgroundGradientLayer.frame = self.view.bounds;
        NSMutableArray *cgColors = [NSMutableArray array];
        for (UIColor *color in palette.gradientColors) {
            [cgColors addObject:(id)color.CGColor];
        }
        self.backgroundGradientLayer.colors = cgColors;
    }
    
    // 自动配置导航栏风格与 Tint 颜色
    if (self.navigationController) {
        self.navigationController.navigationBar.barStyle = UIBarStyleBlack;
        self.navigationController.navigationBar.tintColor = palette.primaryColor;
        
        // 配置导航栏字体颜色，确保在深空极光背景下高清晰高亮显示
        NSMutableDictionary *titleAttrs = [NSMutableDictionary dictionary];
        titleAttrs[NSForegroundColorAttributeName] = [UIColor whiteColor];
        
        self.navigationController.navigationBar.titleTextAttributes = titleAttrs;
        if (@available(iOS 11.0, *)) {
            self.navigationController.navigationBar.largeTitleTextAttributes = titleAttrs;
        }
    }
    
    // 强制触发状态栏刷新
    [self setNeedsStatusBarAppearanceUpdate];
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    // 采用高雅的白字状态栏，适配深空极光渐变体系
    return UIStatusBarStyleLightContent;
}

@end
