#import <UIKit/UIKit.h>
#import "HSBTVOSConnectionManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface HSBIPTVDPadView : UIView

@property (nonatomic, copy, nullable) void (^onActionTriggeredBlock)(HSBRemoteSimulateAction action);

- (void)applyThemeStyle;

@end

NS_ASSUME_NONNULL_END
