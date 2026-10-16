#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface SettingsViewController : UITableViewController

@property (nonatomic, copy, nullable) void (^sendPayloadBlock)(NSDictionary *payload);

@end

NS_ASSUME_NONNULL_END
