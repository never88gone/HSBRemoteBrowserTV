#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface HSBIPTVFavoritesBarView : UIView

@property (nonatomic, copy, nullable) void (^onSelectChannelBlock)(NSString *name, NSString *channelId);
@property (nonatomic, copy, nullable) void (^onRequestAddFavoriteBlock)(void);
@property (nonatomic, copy, nullable) void (^onRequestDeleteFavoriteBlock)(NSInteger index, NSString *channelId, NSString *channelName);

- (void)reloadFavorites;
- (void)applyThemeStyle;

@end

NS_ASSUME_NONNULL_END
