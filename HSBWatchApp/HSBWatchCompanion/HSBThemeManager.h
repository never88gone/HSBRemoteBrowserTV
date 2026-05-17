//
//  HSBThemeManager.h
//  HSBWatchCompanion
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, HSBThemeStyle) {
    HSBThemeStyleIndigo = 0,
    HSBThemeStyleGreen,
    HSBThemeStylePink,
    HSBThemeStyleOrange,
    HSBThemeStyleBlue,
    HSBThemeStylePurple
};

extern NSString * const HSBThemeChangedNotification;

@interface HSBThemePalette : NSObject

@property (nonatomic, strong, readonly) UIColor *primaryColor;       // 主色调高亮色
@property (nonatomic, strong, readonly) UIColor *secondaryColor;     // 辅助高亮色
@property (nonatomic, strong, readonly) UIColor *cardBgColor;        // 超低饱和度卡片背景色
@property (nonatomic, strong, readonly) UIColor *backgroundColor;   // 全局背景色 (纯黑)
@property (nonatomic, strong, readonly) UIColor *glowColor;          // 呼吸发光色
@property (nonatomic, strong, readonly) NSArray<UIColor *> *gradientColors; // 渐变色起止组

+ (instancetype)paletteWithPrimary:(UIColor *)primary
                         secondary:(UIColor *)secondary
                            cardBg:(UIColor *)cardBg
                             bgCol:(UIColor *)bgCol
                             glowC:(UIColor *)glowC
                          gradient:(NSArray<UIColor *> *)gradient;

@end

@interface HSBThemeManager : NSObject

@property (nonatomic, assign) HSBThemeStyle currentStyle;
@property (nonatomic, readonly) HSBThemePalette *currentPalette;
@property (nonatomic, readonly) UIColor *themeColor; // 向后兼容
@property (nonatomic, readonly) NSString *themeName;

+ (instancetype)shared;
- (void)updateTheme:(HSBThemeStyle)style;
- (NSArray<NSString *> *)allThemeNames;

@end

NS_ASSUME_NONNULL_END
