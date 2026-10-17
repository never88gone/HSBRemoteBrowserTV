//
//  HSBLLMInputPanel.h
//  HSBWatchCompanion
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface HSBLLMInputPanel : UIView

@property (nonatomic, copy, nullable) void (^onStartGenerateRequested)(NSString *text);
@property (nonatomic, copy, nullable) void (^onQuickTagSelected)(NSInteger index);

@property (nonatomic, strong, readonly) UITextView *inputTextView;
@property (nonatomic, strong, readonly) UIButton *testBtn;

- (void)updatePlaceholder:(NSString *)placeholder;
- (void)setQuickPromptTags:(NSArray<NSString *> *)tags primaryColor:(UIColor *)primaryColor;
- (void)setGeneratingState:(BOOL)isGenerating;
- (void)setInputText:(NSString *)text;
- (void)applyThemePrimaryColor:(UIColor *)primaryColor;

@end

NS_ASSUME_NONNULL_END
