//
//  HSBBrowserAIEngine.m
//  HSBWatchCompanion
//

#import "HSBBrowserAIEngine.h"
#import "HSBLocalLLMManager.h"
#import "HSBTVOSConnectionConstants.h"

@implementation HSBBrowserAIEngine

+ (void)processAIRequest:(NSString *)text
                    type:(NSInteger)type
          onStreamUpdate:(void (^)(NSString *partialText))onStreamUpdate
              completion:(void (^)(NSDictionary *payload, NSString *rawResponse, BOOL isTranslation))completion {
    if (text.length == 0) return;
    
    NSString *systemPrompt = @"";
    NSString *enhancedUserPrompt = @"";
    
    if (type == 1) {
        systemPrompt = @"你是一个精准的翻译助手。只输出最终的翻译结果，不要任何多余的解释、Markdown 或标注。";
        NSString *sourceLang = [[NSUserDefaults standardUserDefaults] stringForKey:@"HSBTranslationSourceLanguage"] ?: @"Auto";
        NSString *targetLang = [[NSUserDefaults standardUserDefaults] stringForKey:@"HSBTranslationTargetLanguage"] ?: @"Chinese";
        NSDictionary *map = @{
            @"Auto": @"自动识别语言",
            @"Chinese": @"中文",
            @"English": @"英文",
            @"Japanese": @"日文",
            @"Korean": @"韩文",
            @"French": @"法文",
            @"German": @"德文",
            @"Spanish": @"西班牙文",
            @"Russian": @"俄文"
        };
        NSString *sourceStr = map[sourceLang] ?: @"自动识别语言";
        NSString *targetStr = map[targetLang] ?: @"中文";
        enhancedUserPrompt = [NSString stringWithFormat:@"请将下面这句话从【%@】翻译成【%@】：\n%@", sourceStr, targetStr, text];
    } else {
        systemPrompt = @"You are a browser automation assistant. Generate ONLY executable browser JavaScript code based on the user's request. Keep the code extremely simple and solid.\n\n"
                       "RULES:\n"
                       "1. Output ONLY executable browser JavaScript code. No explanations, no markdown formatting (DO NOT use ``` or ```javascript), no HTML tags, no intro/outro.\n"
                       "2. The code must be immediately executable by browser eval().\n"
                       "3. Do NOT output HTML like '<div>'. If changing background, use DOM style APIs.\n\n"
                       "EXAMPLES:\n"
                       "Request: \"让网页背景变黑\"\n"
                       "Output: document.body.style.backgroundColor = 'black';\n\n"
                       "Request: \"把背景变成绿色\"\n"
                       "Output: document.body.style.backgroundColor = 'green';\n\n"
                       "Request: \"滚动到最底部\"\n"
                       "Output: window.scrollTo({ top: document.body.scrollHeight, behavior: 'smooth' });\n\n"
                       "Request: \"将所有字体变大\"\n"
                       "Output: document.querySelectorAll('*').forEach(el => { el.style.fontSize = '1.2em'; });";
                       
        enhancedUserPrompt = [NSString stringWithFormat:@"Request: \"%@\"\nOutput: ", text];
    }
    
    [[HSBLocalLLMManager shared] processMessage:enhancedUserPrompt systemPrompt:systemPrompt type:type completion:^(NSString * _Nonnull response, BOOL isFinished) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!isFinished) {
                if (onStreamUpdate) {
                    onStreamUpdate(response);
                }
                return;
            }
            
            NSString *cleanResponse = [self sanitizeResponse:response];
            
            NSDictionary *payload = @{
                HSBRemotePayloadKeyAction: (type == 1 ? HSBRemoteSimulateActionTranslationResult : HSBRemoteSimulateActionExecuteJS),
                HSBRemotePayloadKeyContent: cleanResponse,
                HSBRemotePayloadKeyTimestamp: @([[NSDate date] timeIntervalSince1970]),
                HSBRemotePayloadKeyRequestId: [[NSUUID UUID] UUIDString]
            };
            
            if (type != 1) {
                NSMutableDictionary *jsPayload = [payload mutableCopy];
                jsPayload[HSBRemotePayloadKeyScript] = response;
                payload = jsPayload;
            }
            
            if (completion) {
                completion(payload, response, type == 1);
            }
        });
    }];
}

+ (NSString *)sanitizeResponse:(NSString *)response {
    NSString *cleanResponse = [response stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([cleanResponse hasPrefix:@"```javascript"]) {
        cleanResponse = [cleanResponse substringFromIndex:13];
    } else if ([cleanResponse hasPrefix:@"```js"]) {
        cleanResponse = [cleanResponse substringFromIndex:5];
    } else if ([cleanResponse hasPrefix:@"```"]) {
        cleanResponse = [cleanResponse substringFromIndex:3];
    }
    if ([cleanResponse hasSuffix:@"```"]) {
        cleanResponse = [cleanResponse substringToIndex:cleanResponse.length - 3];
    }
    cleanResponse = [cleanResponse stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([cleanResponse hasPrefix:@"Output:"]) {
        cleanResponse = [cleanResponse substringFromIndex:7];
        cleanResponse = [cleanResponse stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    } else if ([cleanResponse hasPrefix:@"Output: "]) {
        cleanResponse = [cleanResponse substringFromIndex:8];
        cleanResponse = [cleanResponse stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    }
    return cleanResponse;
}

@end
