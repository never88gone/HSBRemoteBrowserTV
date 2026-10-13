//
//  HSBThemeManager.m
//  HSBWatchCompanion
//

#import "HSBThemeManager.h"

NSString * const HSBThemeChangedNotification = @"HSBThemeChangedNotification";

@implementation HSBThemePalette

+ (instancetype)paletteWithPrimary:(UIColor *)primary
                         secondary:(UIColor *)secondary
                            cardBg:(UIColor *)cardBg
                             bgCol:(UIColor *)bgCol
                             glowC:(UIColor *)glowC
                          gradient:(NSArray<UIColor *> *)gradient {
    HSBThemePalette *p = [[HSBThemePalette alloc] init];
    p->_primaryColor = primary;
    p->_secondaryColor = secondary;
    p->_cardBgColor = cardBg;
    p->_backgroundColor = bgCol;
    p->_glowColor = glowC;
    p->_gradientColors = gradient;
    return p;
}

@end

@implementation HSBThemeManager

+ (instancetype)shared {
    static HSBThemeManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[HSBThemeManager alloc] init];
        [instance loadSavedTheme];
    });
    return instance;
}

- (void)loadSavedTheme {
    NSInteger savedStyle = [[NSUserDefaults standardUserDefaults] integerForKey:@"HSBAppThemeStyle"];
    _currentStyle = savedStyle;
}

- (void)updateTheme:(HSBThemeStyle)style {
    _currentStyle = style;
    [[NSUserDefaults standardUserDefaults] setInteger:style forKey:@"HSBAppThemeStyle"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:HSBThemeChangedNotification object:nil];
    });
}

+ (UIColor *)tanghuluBrandColor {
    // 糖葫芦官方新版图标同源品牌朱砂红 / 红宝石色 (#E02438)
    return [UIColor colorWithRed:224.0/255.0 green:36.0/255.0 blue:56.0/255.0 alpha:1.0];
}

+ (NSArray<UIColor *> *)brandGradientColors {
    // 糖葫芦深炭黑微光极简背景渐变色组：
    // 顶部起始：深炭黑微光 (#25262B)
    // 中部过渡：沉稳炭黑 (#1C1D21)
    // 底部结束：纯粹暗夜黑 (#141416)
    return @[
        [UIColor colorWithRed:37.0/255.0 green:38.0/255.0 blue:43.0/255.0 alpha:1.0],
        [UIColor colorWithRed:28.0/255.0 green:29.0/255.0 blue:33.0/255.0 alpha:1.0],
        [UIColor colorWithRed:20.0/255.0 green:20.0/255.0 blue:22.0/255.0 alpha:1.0]
    ];
}

+ (CAGradientLayer *)createBrandGradientLayerWithBounds:(CGRect)bounds {
    CAGradientLayer *gradient = [CAGradientLayer layer];
    gradient.frame = bounds;
    NSMutableArray *cgColors = [NSMutableArray array];
    for (UIColor *color in [self brandGradientColors]) {
        [cgColors addObject:(id)color.CGColor];
    }
    gradient.colors = cgColors;
    gradient.locations = @[@(0.0), @(0.5), @(1.0)];
    gradient.startPoint = CGPointMake(0.0, 0.0);
    gradient.endPoint = CGPointMake(1.0, 1.0);
    return gradient;
}

- (HSBThemePalette *)currentPalette {
    UIColor *bg = [UIColor colorWithRed:20.0/255.0 green:20.0/255.0 blue:22.0/255.0 alpha:1.0];
    UIColor *brandRed = [HSBThemeManager tanghuluBrandColor];
    UIColor *secondaryRed = [UIColor colorWithRed:245.0/255.0 green:75.0/255.0 blue:90.0/255.0 alpha:1.0];
    // 卡片背景：深炭黑磨砂半透明质感
    UIColor *cardBg = [UIColor colorWithRed:36.0/255.0 green:37.0/255.0 blue:42.0/255.0 alpha:0.75];
    return [HSBThemePalette paletteWithPrimary:brandRed
                                     secondary:secondaryRed
                                        cardBg:cardBg
                                         bgCol:bg
                                         glowC:[brandRed colorWithAlphaComponent:0.25]
                                      gradient:[HSBThemeManager brandGradientColors]];
}

- (UIColor *)themeColor {
    return self.currentPalette.primaryColor;
}

- (NSString *)themeName {
    NSString *language = [[NSLocale preferredLanguages] firstObject];
    BOOL isZh = [language hasPrefix:@"zh"];
    return isZh ? @"系统默认" : @"System Default";
}

- (NSString *)nameForStyle:(HSBThemeStyle)style {
    return self.themeName;
}

- (NSArray<NSString *> *)allThemeNames {
    return @[self.themeName];
}

@end
