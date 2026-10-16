#import "HSBBaseViewController.h"

NS_ASSUME_NONNULL_BEGIN

@interface HomeConfigEditViewController : HSBBaseViewController

@property (nonatomic, copy) NSString *initialJson;
@property (nonatomic, copy) void (^onSaveAndSync)(NSString *jsonString);

@end

NS_ASSUME_NONNULL_END
