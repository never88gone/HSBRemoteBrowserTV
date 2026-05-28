//
//  HSBTVOSConnectionManager.h
//  HSBWatchCompanion
//

#import <Foundation/Foundation.h>
#import <Network/Network.h>

NS_ASSUME_NONNULL_BEGIN

// 通知定义
extern NSString * const HSBTVOSConnectionStateNotification;
extern NSString * const HSBTVOSStateUpdatedNotification;
extern NSString * const HSBIPTVFavoritesUpdatedNotification;

typedef NSString * HSBRemoteSimulateAction NS_TYPED_ENUM;

// -- Unknown --------------------------------------------------------------
extern HSBRemoteSimulateAction const HSBRemoteSimulateActionUnknown;

// -- Category 1: Simulate Remote Button Press -----------------------------
extern HSBRemoteSimulateAction const HSBRemoteSimulateActionUp;
extern HSBRemoteSimulateAction const HSBRemoteSimulateActionDown;
extern HSBRemoteSimulateAction const HSBRemoteSimulateActionLeft;
extern HSBRemoteSimulateAction const HSBRemoteSimulateActionRight;
extern HSBRemoteSimulateAction const HSBRemoteSimulateActionSelect;
extern HSBRemoteSimulateAction const HSBRemoteSimulateActionMenu;
extern HSBRemoteSimulateAction const HSBRemoteSimulateActionPlay;
extern HSBRemoteSimulateAction const HSBRemoteSimulateActionPause;
extern HSBRemoteSimulateAction const HSBRemoteSimulateActionStop;

// -- Category 2: Player Control -------------------------------------------
extern HSBRemoteSimulateAction const HSBRemoteSimulateActionOpenPlayer;
extern HSBRemoteSimulateAction const HSBRemoteSimulateActionClosePlayer;
extern HSBRemoteSimulateAction const HSBRemoteSimulateActionSeekRelative;
extern HSBRemoteSimulateAction const HSBRemoteSimulateActionSeekPercent;
extern HSBRemoteSimulateAction const HSBRemoteSimulateActionSetRate;
extern HSBRemoteSimulateAction const HSBRemoteSimulateActionSeekForward;
extern HSBRemoteSimulateAction const HSBRemoteSimulateActionSeekBackward;
extern HSBRemoteSimulateAction const HSBRemoteSimulateActionSeekAbsolute;
extern HSBRemoteSimulateAction const HSBRemoteSimulateActionToggleSubtitle;
extern HSBRemoteSimulateAction const HSBRemoteSimulateActionVolumeUp;
extern HSBRemoteSimulateAction const HSBRemoteSimulateActionVolumeDown;

// -- Category 3: Page Navigation ------------------------------------------
extern HSBRemoteSimulateAction const HSBRemoteSimulateActionOpenUrl;
extern HSBRemoteSimulateAction const HSBRemoteSimulateActionPageBack;
extern HSBRemoteSimulateAction const HSBRemoteSimulateActionPageForward;
extern HSBRemoteSimulateAction const HSBRemoteSimulateActionPageReload;
extern HSBRemoteSimulateAction const HSBRemoteSimulateActionPageHome;

// -- Category 4: Content & Script Control ---------------------------------
extern HSBRemoteSimulateAction const HSBRemoteSimulateActionUpdateHomeJson;
extern HSBRemoteSimulateAction const HSBRemoteSimulateActionExecuteJS;
extern HSBRemoteSimulateAction const HSBRemoteSimulateActionPdfDraw;

// -- Category 5: Mouse / Trackpad Simulation ------------------------------
extern HSBRemoteSimulateAction const HSBRemoteSimulateActionMacTap;
extern HSBRemoteSimulateAction const HSBRemoteSimulateActionMacPan;
extern HSBRemoteSimulateAction const HSBRemoteSimulateActionMacScroll;
extern HSBRemoteSimulateAction const HSBRemoteSimulateActionMacDrag;

// -- Category 6: IPTV Control & Favorites ---------------------------------
extern HSBRemoteSimulateAction const HSBRemoteSimulateActionIPTVGetFavorites;
extern HSBRemoteSimulateAction const HSBRemoteSimulateActionIPTVPlayChannel;
extern HSBRemoteSimulateAction const HSBRemoteSimulateActionIPTVAddFavorite;
extern HSBRemoteSimulateAction const HSBRemoteSimulateActionIPTVDeleteFavorite;
extern HSBRemoteSimulateAction const HSBRemoteSimulateActionIPTVEpg;
extern HSBRemoteSimulateAction const HSBRemoteSimulateActionIPTVChannels;
extern HSBRemoteSimulateAction const HSBRemoteSimulateActionIPTVRefresh;

// -- Category 7: LLM & Translation ---------------------------------------
extern HSBRemoteSimulateAction const HSBRemoteSimulateActionTranslate;
extern HSBRemoteSimulateAction const HSBRemoteSimulateActionTranslateBlocks;
extern HSBRemoteSimulateAction const HSBRemoteSimulateActionTranslationResult;
extern HSBRemoteSimulateAction const HSBRemoteSimulateActionTranslationBlocksResult;

// -- Category 8: tvOS State Sync -----------------------------------------
extern HSBRemoteSimulateAction const HSBRemoteSimulateActionSyncProgress;
extern HSBRemoteSimulateAction const HSBRemoteSimulateActionSyncFavorites;

@interface HSBTVOSConnectionManager : NSObject

@property (nonatomic, readonly) BOOL isConnected;
@property (nonatomic, strong, readonly, nullable) nw_connection_t connection;
@property (nonatomic, copy, readonly, nullable) NSString *deviceName;
@property (nonatomic, strong, readonly, nullable) nw_endpoint_t currentEndpoint;

+ (instancetype)sharedManager;

- (void)connectToEndpoint:(nw_endpoint_t)endpoint deviceName:(NSString *)deviceName;
- (void)disconnect;

- (void)sendAction:(NSString *)action;
- (void)sendAction:(NSString *)action withValue:(nullable id)value;
- (void)sendSimulateAction:(HSBRemoteSimulateAction)action;
- (void)sendSimulateAction:(HSBRemoteSimulateAction)action withParams:(nullable NSDictionary *)params;
- (void)sendPayload:(NSDictionary *)payload;
- (void)sendJSONConfig:(NSString *)jsonString;

@end

NS_ASSUME_NONNULL_END
