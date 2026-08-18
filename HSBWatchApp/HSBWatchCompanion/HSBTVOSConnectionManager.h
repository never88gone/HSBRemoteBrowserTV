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
extern HSBRemoteSimulateAction const HSBRemoteSimulateActionSetVolume;
extern HSBRemoteSimulateAction const HSBRemoteSimulateActionToggleMute;
extern HSBRemoteSimulateAction const HSBRemoteSimulateActionSwitchAudioTrack;

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
extern HSBRemoteSimulateAction const HSBRemoteSimulateActionChannelUp;
extern HSBRemoteSimulateAction const HSBRemoteSimulateActionChannelDown;
extern HSBRemoteSimulateAction const HSBRemoteSimulateActionDigit;

// -- Category 7: LLM & Translation ---------------------------------------
extern HSBRemoteSimulateAction const HSBRemoteSimulateActionTranslate;
extern HSBRemoteSimulateAction const HSBRemoteSimulateActionTranslateBlocks;
extern HSBRemoteSimulateAction const HSBRemoteSimulateActionTranslationResult;
extern HSBRemoteSimulateAction const HSBRemoteSimulateActionTranslationBlocksResult;

// -- Category 8: tvOS State Sync -----------------------------------------
extern HSBRemoteSimulateAction const HSBRemoteSimulateActionSyncProgress;
extern HSBRemoteSimulateAction const HSBRemoteSimulateActionSyncFavorites;

// -- Payload Keys ---------------------------------------------------------
extern NSString * const HSBRemotePayloadKeyAction;
extern NSString * const HSBRemotePayloadKeyValue;
extern NSString * const HSBRemotePayloadKeySeconds;
extern NSString * const HSBRemotePayloadKeyVolume;
extern NSString * const HSBRemotePayloadKeyMuted;
extern NSString * const HSBRemotePayloadKeyDigit;
extern NSString * const HSBRemotePayloadKeyTrackIndex;
extern NSString * const HSBRemotePayloadKeyDx;
extern NSString * const HSBRemotePayloadKeyDy;
extern NSString * const HSBRemotePayloadKeyMode;
extern NSString * const HSBRemotePayloadKeyState;
extern NSString * const HSBRemotePayloadKeyUrl;
extern NSString * const HSBRemotePayloadKeyScript;
extern NSString * const HSBRemotePayloadKeyType;
extern NSString * const HSBRemotePayloadKeyX;
extern NSString * const HSBRemotePayloadKeyY;
extern NSString * const HSBRemotePayloadKeyColor;
extern NSString * const HSBRemotePayloadKeyWidth;
extern NSString * const HSBRemotePayloadKeyPayload;
extern NSString * const HSBRemotePayloadKeyChannel;
extern NSString * const HSBRemotePayloadKeyId;
extern NSString * const HSBRemotePayloadKeyIndex;
extern NSString * const HSBRemotePayloadKeyTimestamp;
extern NSString * const HSBRemotePayloadKeyRequestId;
extern NSString * const HSBRemotePayloadKeyResult;
extern NSString * const HSBRemotePayloadKeyBlocks;
extern NSString * const HSBRemotePayloadKeyTranslationMap;
extern NSString * const HSBRemotePayloadKeyChannels;
extern NSString * const HSBRemotePayloadKeyCurrentTime;
extern NSString * const HSBRemotePayloadKeyDuration;
extern NSString * const HSBRemotePayloadKeyHidden;
extern NSString * const HSBRemotePayloadKeyPlaybackState;
extern NSString * const HSBRemotePayloadKeyTitle;
extern NSString * const HSBRemotePayloadKeyContent;
extern NSString * const HSBRemotePayloadKeyCode;
extern NSString * const HSBRemotePayloadKeyMessage;
extern NSString * const HSBRemotePayloadKeyError;
extern NSString * const HSBRemotePayloadKeyText;
extern NSString * const HSBRemotePayloadKeySourceLanguage;
extern NSString * const HSBRemotePayloadKeyTargetLanguage;
extern NSString * const HSBRemotePayloadKeyRemoteAction;
extern NSString * const HSBRemotePayloadKeyPressType;
extern NSString * const HSBRemotePayloadKeyName;
extern NSString * const HSBRemotePayloadKeyStream;
extern NSString * const HSBRemotePayloadKeyLogo;
extern NSString * const HSBRemotePayloadKeyGroup;

// -- PDF & Drawing Constants ---------------------------------------------
extern NSString * const HSBRemoteDrawTypeClear;
extern NSString * const HSBRemoteDrawTypeUndo;
extern NSString * const HSBRemoteDrawTypeEraser;
extern NSString * const HSBRemoteDrawTypeBegan;
extern NSString * const HSBRemoteDrawTypeMoved;
extern NSString * const HSBRemoteDrawTypeChanged;
extern NSString * const HSBRemoteDrawTypeEnded;
extern NSString * const HSBRemoteDrawColorRed;
extern NSString * const HSBRemoteDrawColorBlue;
extern NSString * const HSBRemoteDrawColorGreen;
extern NSString * const HSBRemoteDrawColorYellow;
extern NSString * const HSBRemoteDrawColorWhite;
extern NSString * const HSBRemoteDrawColorBlack;

// -- Notification UserInfo Keys ------------------------------------------
extern NSString * const HSBConnectionStateKeyMessage;
extern NSString * const HSBConnectionStateKeyState;

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
