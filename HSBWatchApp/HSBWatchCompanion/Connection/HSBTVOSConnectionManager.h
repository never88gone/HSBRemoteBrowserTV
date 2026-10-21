//
//  HSBTVOSConnectionManager.h
//  HSBWatchCompanion
//

#import <Foundation/Foundation.h>
#import <Network/Network.h>
#import "HSBTVOSConnectionConstants.h"

NS_ASSUME_NONNULL_BEGIN

@interface HSBTVOSConnectionManager : NSObject

@property (nonatomic, readonly) BOOL isConnected;
@property (nonatomic, strong, readonly, nullable) nw_connection_t connection;
@property (nonatomic, copy, readonly, nullable) NSString *deviceName;
@property (nonatomic, strong, readonly, nullable) nw_endpoint_t currentEndpoint;
@property (nonatomic, readonly) BOOL isAppInBackground;
@property (nonatomic, readonly) BOOL isReconnecting;

+ (instancetype)sharedManager;
+ (NSArray<NSDictionary<NSString *, NSString *> *> *)pairedTVRecords;

- (void)connectToEndpoint:(nw_endpoint_t)endpoint deviceName:(NSString *)deviceName;
- (void)connectToPairingURL:(NSURL *)pairingURL;
- (BOOL)connectToLastPairedTV;
- (void)disconnect;
- (void)clearPairedTVRecords;

/// 应用回到前台唤起时调用：检测连接健康，僵尸连接秒级自愈并快速重连
- (void)handleAppWillEnterForeground;

/// 应用退到后台时调用：暂停心跳及重连轮询，保存状态
- (void)handleAppDidEnterBackground;

/// 立即触发一次自动重连（0延迟），优先重连最后配对或当前设备
- (void)triggerImmediateReconnect;

- (void)sendAction:(NSString *)action;
- (void)sendAction:(NSString *)action withValue:(nullable id)value;
- (void)sendSimulateAction:(HSBRemoteSimulateAction)action;
- (void)sendSimulateAction:(HSBRemoteSimulateAction)action withParams:(nullable NSDictionary *)params;
- (void)sendPayload:(NSDictionary *)payload;
- (void)sendJSONConfig:(NSString *)jsonString;

@end

NS_ASSUME_NONNULL_END
