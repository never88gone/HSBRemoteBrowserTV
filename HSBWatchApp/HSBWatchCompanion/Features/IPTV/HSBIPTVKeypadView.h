#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface HSBIPTVKeypadView : UIView

@property (nonatomic, copy, nullable) void (^onCommitChannelBlock)(NSString *channelDigits);

- (void)clearAll;
- (void)applyThemeStyle;

@end

NS_ASSUME_NONNULL_END
