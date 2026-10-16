//
//  HSBHomeVideoControlCard.h
//  HSBWatchCompanion
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface HSBHomeVideoControlCard : UIView

@property (nonatomic, copy, nullable) void (^onSeekRequested)(NSTimeInterval seekTime);

- (void)updateCurrentTime:(NSTimeInterval)current duration:(NSTimeInterval)duration;
- (void)applyThemePrimaryColor:(UIColor *)color;

@end

NS_ASSUME_NONNULL_END
