//
//  IPTVRemoteViewController.h
//  HSBWatchCompanion
//

#import "HSBBaseViewController.h"

NS_ASSUME_NONNULL_BEGIN

@interface IPTVRemoteViewController : HSBBaseViewController

@property (nonatomic, copy) void (^sendPayloadBlock)(NSDictionary *payload);
@property (nonatomic, copy) void (^sendActionBlock)(NSString *actionString);
@property (nonatomic, copy) BOOL (^checkConnectionBlock)(void);

@end

NS_ASSUME_NONNULL_END
