//
//  HSBTVOSMessageParser.m
//  HSBWatchCompanion
//

#import "HSBTVOSMessageParser.h"

NSUInteger const HSBMaxIncomingJSONBytes = 1024 * 1024;

@implementation HSBTVOSMessageParser

+ (NSArray<NSData *> *)extractJSONMessagesFromBuffer:(NSMutableData *)buffer {
    if (buffer.length == 0) return @[];

    const uint8_t *bytes = buffer.bytes;
    NSMutableArray<NSData *> *messages = [NSMutableArray array];
    NSUInteger start = NSNotFound;
    NSUInteger consumed = 0;
    NSInteger depth = 0;
    BOOL inString = NO;
    BOOL escaped = NO;

    for (NSUInteger i = 0; i < buffer.length; i++) {
        uint8_t byte = bytes[i];
        if (start == NSNotFound) {
            if (byte == '{' || byte == '[') {
                start = i;
                depth = 1;
                inString = NO;
                escaped = NO;
            } else {
                consumed = i + 1;
            }
            continue;
        }

        if (inString) {
            if (escaped) {
                escaped = NO;
            } else if (byte == '\\') {
                escaped = YES;
            } else if (byte == '"') {
                inString = NO;
            }
            continue;
        }

        if (byte == '"') {
            inString = YES;
        } else if (byte == '{' || byte == '[') {
            depth++;
        } else if (byte == '}' || byte == ']') {
            depth--;
            if (depth == 0) {
                [messages addObject:[buffer subdataWithRange:NSMakeRange(start, i - start + 1)]];
                consumed = i + 1;
                start = NSNotFound;
            }
        }
    }

    if (consumed > 0) {
        [buffer replaceBytesInRange:NSMakeRange(0, consumed) withBytes:NULL length:0];
    }
    return messages;
}

@end
