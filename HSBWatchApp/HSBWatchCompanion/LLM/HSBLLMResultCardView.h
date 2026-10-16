#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface HSBLLMResultCardView : UIView

@property (nonatomic, strong, readonly) UITextView *resultTextView;
@property (nonatomic, strong, readonly) UIButton *clipboardBtn;
@property (nonatomic, copy, nullable) void (^onCopyResultRequested)(NSString *text);
@property (nonatomic, copy, nullable) void (^onRunOnTvRequested)(NSString *script);

- (void)updateWithResultText:(NSString *)text isFinished:(BOOL)isFinished showRunOnTv:(BOOL)showRunOnTv;
- (void)clearAndHide;
- (void)applyThemeStyle;

@end

NS_ASSUME_NONNULL_END
