//
//  HSBBrowserVideoControlPanel.h
//  HSBWatchCompanion
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface HSBBrowserVideoControlPanel : UIView

@property (nonatomic, copy) void (^onOpenPlayer)(void);
@property (nonatomic, copy) void (^onClosePlayer)(void);
@property (nonatomic, copy) void (^onSeekPercent)(CGFloat percent);

- (void)applyThemeStyle;

@end

NS_ASSUME_NONNULL_END
