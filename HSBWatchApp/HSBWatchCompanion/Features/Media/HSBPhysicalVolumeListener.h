//
//  HSBPhysicalVolumeListener.h
//  HSBWatchCompanion
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface HSBPhysicalVolumeListener : NSObject

@property (nonatomic, copy, nullable) void (^onVolumeUp)(void);
@property (nonatomic, copy, nullable) void (^onVolumeDown)(void);
@property (nonatomic, readonly) BOOL isListening;

+ (instancetype)sharedListener;
- (void)startListening;
- (void)stopListening;

@end

NS_ASSUME_NONNULL_END
