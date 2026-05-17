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

@interface HSBTVOSConnectionManager : NSObject

@property (nonatomic, readonly) BOOL isConnected;
@property (nonatomic, strong, readonly, nullable) nw_connection_t connection;
@property (nonatomic, copy, readonly, nullable) NSString *deviceName;
@property (nonatomic, strong, readonly, nullable) nw_endpoint_t currentEndpoint;

+ (instancetype)sharedManager;

- (void)connectToEndpoint:(nw_endpoint_t)endpoint deviceName:(NSString *)deviceName;
- (void)disconnect;

- (void)sendAction:(NSString *)action;
- (void)sendAction:(NSString *)action withValue:(nullable NSString *)value;
- (void)sendPayload:(NSDictionary *)payload;
- (void)sendJSONConfig:(NSString *)jsonString;

@end

NS_ASSUME_NONNULL_END
