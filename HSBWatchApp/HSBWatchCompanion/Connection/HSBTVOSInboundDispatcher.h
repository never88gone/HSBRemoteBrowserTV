//
//  HSBTVOSInboundDispatcher.h
//  HSBWatchCompanion
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class HSBTVOSConnectionManager;

@interface HSBTVOSInboundDispatcher : NSObject

/// 处理已认证通道上接收到的 TV 业务报文（IPTV 状态、播放进度同步、LLM 翻译桥接等）
+ (void)dispatchPayload:(NSDictionary *)json fromManager:(HSBTVOSConnectionManager *)manager;

@end

NS_ASSUME_NONNULL_END
