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

- (HSBThemePalette *)currentPalette {
    UIColor *bg = [UIColor blackColor]; // 纯黑 OLED 极黑背景
    switch (self.currentStyle) {
        case HSBThemeStyleGreen:
            return [HSBThemePalette paletteWithPrimary:[UIColor systemGreenColor]
                                             secondary:[UIColor systemTealColor]
                                                cardBg:[UIColor colorWithRed:0.03 green:0.06 blue:0.04 alpha:1.0]
                                                 bgCol:bg
                                                 glowC:[[UIColor systemGreenColor] colorWithAlphaComponent:0.5]
                                              gradient:@[[UIColor systemGreenColor], [UIColor systemTealColor]]];
        case HSBThemeStylePink:
            return [HSBThemePalette paletteWithPrimary:[UIColor systemPinkColor]
                                             secondary:[UIColor systemOrangeColor]
                                                cardBg:[UIColor colorWithRed:0.07 green:0.04 blue:0.05 alpha:1.0]
                                                 bgCol:bg
                                                 glowC:[[UIColor systemPinkColor] colorWithAlphaComponent:0.5]
                                              gradient:@[[UIColor systemPinkColor], [UIColor systemOrangeColor]]];
        case HSBThemeStyleOrange:
            return [HSBThemePalette paletteWithPrimary:[UIColor systemOrangeColor]
                                             secondary:[UIColor systemYellowColor]
                                                cardBg:[UIColor colorWithRed:0.07 green:0.05 blue:0.03 alpha:1.0]
                                                 bgCol:bg
                                                 glowC:[[UIColor systemOrangeColor] colorWithAlphaComponent:0.5]
                                              gradient:@[[UIColor systemOrangeColor], [UIColor systemYellowColor]]];
        case HSBThemeStyleBlue:
            return [HSBThemePalette paletteWithPrimary:[UIColor systemBlueColor]
                                             secondary:[UIColor systemTealColor]
                                                cardBg:[UIColor colorWithRed:0.03 green:0.05 blue:0.08 alpha:1.0]
                                                 bgCol:bg
                                                 glowC:[[UIColor systemBlueColor] colorWithAlphaComponent:0.5]
                                              gradient:@[[UIColor systemBlueColor], [UIColor systemTealColor]]];
        case HSBThemeStylePurple:
            return [HSBThemePalette paletteWithPrimary:[UIColor systemPurpleColor]
                                             secondary:[UIColor systemPinkColor]
                                                cardBg:[UIColor colorWithRed:0.06 green:0.04 blue:0.08 alpha:1.0]
                                                 bgCol:bg
                                                 glowC:[[UIColor systemPurpleColor] colorWithAlphaComponent:0.5]
                                              gradient:@[[UIColor systemPurpleColor], [UIColor systemPinkColor]]];
        case HSBThemeStyleIndigo:
        default:
            return [HSBThemePalette paletteWithPrimary:[UIColor systemIndigoColor]
                                             secondary:[UIColor systemPurpleColor]
                                                cardBg:[UIColor colorWithRed:0.04 green:0.04 blue:0.08 alpha:1.0]
                                                 bgCol:bg
                                                 glowC:[[UIColor systemIndigoColor] colorWithAlphaComponent:0.5]
                                              gradient:@[[UIColor systemIndigoColor], [UIColor systemPurpleColor]]];
    }
}

- (UIColor *)themeColor {
    return self.currentPalette.primaryColor;
}

- (NSString *)themeName {
    return [self nameForStyle:self.currentStyle];
}

- (NSString *)nameForStyle:(HSBThemeStyle)style {
    NSString *language = [[NSLocale preferredLanguages] firstObject];
    BOOL isZh = [language hasPrefix:@"zh"];
    switch (style) {
        case HSBThemeStyleGreen:
            return isZh ? @"翡翠傲绿" : @"Emerald Green";
        case HSBThemeStylePink:
            return isZh ? @"落樱仙粉" : @"Sakura Pink";
        case HSBThemeStyleOrange:
            return isZh ? @"暖阳暖橙" : @"Warm Orange";
        case HSBThemeStyleBlue:
            return isZh ? @"深邃蔚蓝" : @"Ocean Blue";
        case HSBThemeStylePurple:
            return isZh ? @"极客魔紫" : @"Geeky Purple";
        case HSBThemeStyleIndigo:
        default:
            return isZh ? @"经典靛蓝" : @"Classic Indigo";
    }
}

- (NSArray<NSString *> *)allThemeNames {
    return @[
        [self nameForStyle:HSBThemeStyleIndigo],
        [self nameForStyle:HSBThemeStyleGreen],
        [self nameForStyle:HSBThemeStylePink],
        [self nameForStyle:HSBThemeStyleOrange],
        [self nameForStyle:HSBThemeStyleBlue],
        [self nameForStyle:HSBThemeStylePurple]
    ];
}

@end
