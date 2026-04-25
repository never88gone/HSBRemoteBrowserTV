//
//  VideoControlViewController.h
//  HSBWatchCompanion
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface VideoControlViewController : UIViewController
@property (nonatomic, copy) void (^sendPayloadBlock)(NSDictionary *payload);
@end

NS_ASSUME_NONNULL_END
