//
//  HSBBaseViewController.h
//  HSBWatchCompanion
//

#import <UIKit/UIKit.h>
#import "HSBThemeManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface HSBBaseViewController : UIViewController

/**
 子类重写此方法以在其中应用自己特化的主题元素（卡片背景、特定图标等）。
 基类会自动在 viewDidLoad、viewWillAppear 以及主题发生变更通知时调用此方法。
 */
- (void)applyThemeStyle NS_REQUIRES_SUPER;

@end

NS_ASSUME_NONNULL_END
