//
//  HSBHomeBrowserControlCard.h
//  HSBWatchCompanion
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface HSBHomeBrowserControlCard : UIView

@property (nonatomic, copy, nullable) void (^onOpenURLRequested)(NSString *url);
@property (nonatomic, copy, nullable) void (^onOpenRemoteRequested)(void);
@property (nonatomic, copy, nullable) void (^onEditHomeConfigRequested)(void);

- (void)applyThemePrimaryColor:(UIColor *)color;

@end

NS_ASSUME_NONNULL_END
