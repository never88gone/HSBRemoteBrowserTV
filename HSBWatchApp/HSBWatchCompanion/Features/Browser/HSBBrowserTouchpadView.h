//
//  HSBBrowserTouchpadView.h
//  HSBWatchCompanion
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface HSBBrowserTouchpadView : UIView

@property (nonatomic, copy) void (^onPan)(CGFloat dx, CGFloat dy);
@property (nonatomic, copy) void (^onScroll)(CGFloat dx, CGFloat dy);
@property (nonatomic, copy) void (^onTap)(NSInteger mode);
@property (nonatomic, copy) void (^onDrag)(NSString *state, CGFloat dx, CGFloat dy);
@property (nonatomic, copy) void (^onCancelAI)(void);
@property (nonatomic, copy) BOOL (^checkConnection)(void);

- (void)setStatusText:(NSString *)text;
- (void)setStatusText:(NSString *)text restoreReadyAfter:(NSTimeInterval)delay;
- (void)setAICancelButtonHidden:(BOOL)hidden;
- (NSString *)currentStatusText;

@end

NS_ASSUME_NONNULL_END
