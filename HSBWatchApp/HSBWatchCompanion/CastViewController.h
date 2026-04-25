//
//  CastViewController.h
//  HSBWatchCompanion
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface CastViewController : UIViewController
@property (nonatomic, copy) void (^sendPayloadBlock)(NSDictionary *payload);
@end

NS_ASSUME_NONNULL_END
