//
//  HSBBrowserSpeechAssistant.h
//  HSBWatchCompanion
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface HSBBrowserSpeechAssistant : NSObject

@property (nonatomic, readonly) UIButton *aiFloatingButton;
@property (nonatomic, copy) void (^onSendAction)(NSString *action);
@property (nonatomic, copy) void (^onSendPayload)(NSDictionary *payload);
@property (nonatomic, copy) void (^onStatusUpdate)(NSString *statusText, BOOL showCancelButton);
@property (nonatomic, copy) void (^onShowToast)(NSString *message);
@property (nonatomic, copy) void (^onPresentAlert)(UIAlertController *alert);

- (instancetype)initWithContainerView:(UIView *)containerView;

- (void)stopAudioIfRunning;
- (void)cancelCurrentAIInference;

@end

NS_ASSUME_NONNULL_END
