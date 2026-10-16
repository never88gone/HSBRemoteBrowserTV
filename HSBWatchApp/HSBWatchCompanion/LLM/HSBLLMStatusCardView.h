#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface HSBLLMStatusCardView : UIView

@property (nonatomic, copy, nullable) void (^onActionBtnClicked)(void);

- (void)updateStatus;
- (void)applyThemeStyle;

@end

NS_ASSUME_NONNULL_END
