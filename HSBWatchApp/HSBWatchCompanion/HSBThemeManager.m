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
    // 统一为现代 Apple 原生系统默认质感调色板：
    // - 主色调：纯正 Apple System Blue
    // - 辅助色：优雅 Apple System Indigo
    // - 卡片背景：标准 Apple 深色分组背景色 #1C1C1E (rgb: 0.11, 0.11, 0.12)
    // - 纯净微光，去除高饱和杂暗色
    return [HSBThemePalette paletteWithPrimary:[UIColor systemBlueColor]
                                     secondary:[UIColor systemIndigoColor]
                                        cardBg:[UIColor colorWithRed:0.11 green:0.11 blue:0.12 alpha:1.0]
                                         bgCol:bg
                                         glowC:[[UIColor systemBlueColor] colorWithAlphaComponent:0.25]
                                      gradient:@[[UIColor systemBlueColor], [UIColor systemIndigoColor]]];
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
