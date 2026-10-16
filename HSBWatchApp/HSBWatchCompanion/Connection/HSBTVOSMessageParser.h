//
//  HSBTVOSMessageParser.h
//  HSBWatchCompanion
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSUInteger const HSBMaxIncomingJSONBytes;

@interface HSBTVOSMessageParser : NSObject

/// 从 TCP 接收持久缓冲区中解析并提取完整的 JSON 报文（兼容拆包与粘包）
/// 成功提取的报文会从 buffer 前部移除
+ (NSArray<NSData *> *)extractJSONMessagesFromBuffer:(NSMutableData *)buffer;

@end

NS_ASSUME_NONNULL_END
