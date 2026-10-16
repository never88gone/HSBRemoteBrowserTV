//
//  HSBBrowserScriptsBarView.h
//  HSBWatchCompanion
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface HSBBrowserScriptsBarView : UIView

@property (nonatomic, copy) void (^onExecuteScript)(NSString *scriptName, NSString *jsContent);

- (void)applyThemeStyle;

@end

NS_ASSUME_NONNULL_END
