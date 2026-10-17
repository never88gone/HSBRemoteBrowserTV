//
//  HSBHomeStatusCardsView.h
//  HSBWatchCompanion
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface HSBHomeStatusCardsView : UIView

@property (nonatomic, copy, nullable) void (^onWatchSyncChanged)(BOOL enabled);
@property (nonatomic, copy, nullable) void (^onTVScanChanged)(BOOL enabled);
@property (nonatomic, copy, nullable) void (^onTVCardTapped)(void);

@property (nonatomic, strong, readonly) UISwitch *watchSyncSwitch;
@property (nonatomic, strong, readonly) UISwitch *tvScanSwitch;
@property (nonatomic, strong, readonly) NSArray<UIView *> *cardViews;

- (void)updateWatchStatusText:(NSString *)text color:(nullable UIColor *)color;
- (void)updateTVStatusText:(NSString *)text color:(nullable UIColor *)color;
- (void)updateActionLogText:(NSString *)text;
- (void)applyThemePrimaryColor:(UIColor *)primaryColor;

@end

NS_ASSUME_NONNULL_END
