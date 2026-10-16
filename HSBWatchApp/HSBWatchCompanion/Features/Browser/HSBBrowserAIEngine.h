//
//  HSBBrowserAIEngine.h
//  HSBWatchCompanion
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface HSBBrowserAIEngine : NSObject

+ (void)processAIRequest:(NSString *)text
                    type:(NSInteger)type
          onStreamUpdate:(void (^)(NSString *partialText))onStreamUpdate
              completion:(void (^)(NSDictionary *payload, NSString *rawResponse, BOOL isTranslation))completion;

@end

NS_ASSUME_NONNULL_END
