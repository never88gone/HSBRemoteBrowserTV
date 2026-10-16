#import "HSBBaseViewController.h"

NS_ASSUME_NONNULL_BEGIN

@interface HSBLLMTestViewController : HSBBaseViewController

@property (nonatomic, copy, nullable) void (^sendPayloadBlock)(NSDictionary *payload);

@end

NS_ASSUME_NONNULL_END
