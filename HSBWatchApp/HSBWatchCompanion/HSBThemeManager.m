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
    // 糖葫芦官方应用图标同源品牌天蓝 / 冰魄蓝 (#1C7BF9)
    return [UIColor colorWithRed:28.0/255.0 green:123.0/255.0 blue:249.0/255.0 alpha:1.0];
}

+ (NSArray<UIColor *> *)brandGradientColors {
    // 糖葫芦深空极光天蓝渐变色组：
    // 顶部起始：深邃极光冰蓝 (#0A1C38)
    // 中部过渡：神秘午夜深蓝 (#060F22)
    // 底部结束：沉稳暗夜蓝黑 (#02050E)
    return @[
        [UIColor colorWithRed:10.0/255.0 green:28.0/255.0 blue:56.0/255.0 alpha:1.0],
        [UIColor colorWithRed:6.0/255.0 green:15.0/255.0 blue:34.0/255.0 alpha:1.0],
        [UIColor colorWithRed:2.0/255.0 green:5.0/255.0 blue:14.0/255.0 alpha:1.0]
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
    gradient.locations = @[@(0.0), @(0.45), @(1.0)];
    gradient.startPoint = CGPointMake(0.0, 0.0);
    gradient.endPoint = CGPointMake(1.0, 1.0);
    return gradient;
}

- (HSBThemePalette *)currentPalette {
    UIColor *bg = [UIColor colorWithRed:6.0/255.0 green:15.0/255.0 blue:34.0/255.0 alpha:1.0];
    UIColor *brandBlue = [HSBThemeManager tanghuluBrandColor];
    UIColor *secondaryBlue = [UIColor colorWithRed:10.0/255.0 green:90.0/255.0 blue:210.0/255.0 alpha:1.0];
    // 卡片背景：深蓝磨砂半透明质感
    UIColor *cardBg = [UIColor colorWithRed:14.0/255.0 green:25.0/255.0 blue:48.0/255.0 alpha:0.65];
    return [HSBThemePalette paletteWithPrimary:brandBlue
                                     secondary:secondaryBlue
                                        cardBg:cardBg
                                         bgCol:bg
                                         glowC:[brandBlue colorWithAlphaComponent:0.25]
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
