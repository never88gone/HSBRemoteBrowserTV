#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface HomeConfigEditViewController : UIViewController

@property (nonatomic, copy) NSString *initialJson;
@property (nonatomic, copy) void (^onSaveAndSync)(NSString *jsonString);

@end

NS_ASSUME_NONNULL_END
