//
//  IPTVRemoteViewController.h
//  HSBWatchCompanion
//

#import "HSBBaseViewController.h"
#import "HSBTVOSConnectionManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface IPTVRemoteViewController : HSBBaseViewController

@property (nonatomic, copy) void (^sendPayloadBlock)(NSDictionary *payload);
@property (nonatomic, copy) void (^sendActionBlock)(HSBRemoteSimulateAction action);
@property (nonatomic, copy) BOOL (^checkConnectionBlock)(void);

@end

NS_ASSUME_NONNULL_END
