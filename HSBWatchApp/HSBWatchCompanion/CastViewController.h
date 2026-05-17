//
//  CastViewController.h
//  HSBWatchCompanion
//

#import "HSBBaseViewController.h"

NS_ASSUME_NONNULL_BEGIN

@interface CastViewController : HSBBaseViewController
@property (nonatomic, copy) void (^sendPayloadBlock)(NSDictionary *payload);
@end

NS_ASSUME_NONNULL_END
