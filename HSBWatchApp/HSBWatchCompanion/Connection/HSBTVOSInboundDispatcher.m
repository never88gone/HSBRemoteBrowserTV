//
//  HSBTVOSInboundDispatcher.m
//  HSBWatchCompanion
//

#import "HSBTVOSInboundDispatcher.h"
#import "HSBTVOSConnectionConstants.h"
#import "HSBTVOSConnectionManager.h"
#import "HSBLocalLLMManager.h"

@implementation HSBTVOSInboundDispatcher

+ (void)dispatchPayload:(NSDictionary *)json fromManager:(HSBTVOSConnectionManager *)manager {
    if (!json || ![json isKindOfClass:[NSDictionary class]]) return;
    
    NSString *action = json[HSBRemotePayloadKeyAction];
    if (!action) return;

    if ([action isEqualToString:HSBRemoteSimulateActionSyncProgress]) {
        [self handleSyncProgress:json fromManager:manager];
    } else if ([action isEqualToString:HSBRemoteSimulateActionSyncFavorites]) {
        [self handleSyncFavorites:json fromManager:manager];
    } else if ([action isEqualToString:@"iptv_catalog"]) {
        [self postNotification:HSBIPTVCatalogUpdatedNotification json:json fromManager:manager];
    } else if ([action isEqualToString:@"iptv_state"]) {
        [self postNotification:HSBIPTVStateUpdatedNotification json:json fromManager:manager];
    } else if ([action isEqualToString:@"iptv_import_result"]) {
        [self postNotification:HSBIPTVImportResultUpdatedNotification json:json fromManager:manager];
    } else if ([action isEqualToString:@"iptv_sources"]) {
        if ([json[HSBRemotePayloadKeyChannels] isKindOfClass:[NSArray class]]) {
            [self postNotification:HSBIPTVSourcesUpdatedNotification json:json fromManager:manager];
        }
    } else if ([action isEqualToString:@"iptv_epg_bindings"]) {
        [self postNotification:HSBIPTVEPGBindingsUpdatedNotification json:json fromManager:manager];
    } else if ([action isEqualToString:@"iptv_epg_candidates"]) {
        [self postNotification:HSBIPTVEPGCandidatesUpdatedNotification json:json fromManager:manager];
    } else if ([action isEqualToString:HSBRemoteSimulateActionTranslate]) {
        [self handleSingleTranslation:json fromManager:manager];
    } else if ([action isEqualToString:HSBRemoteSimulateActionTranslateBlocks]) {
        [self handleBlocksTranslation:json fromManager:manager];
    }
}

+ (void)handleSyncProgress:(NSDictionary *)json fromManager:(HSBTVOSConnectionManager *)manager {
    NSNumber *currentTime = json[HSBRemotePayloadKeyCurrentTime];
    NSNumber *duration = json[HSBRemotePayloadKeyDuration];
    NSNumber *hiddenObj = json[HSBRemotePayloadKeyHidden];
    NSNumber *playbackState = json[HSBRemotePayloadKeyPlaybackState];
    NSNumber *volume = json[HSBRemotePayloadKeyVolume];
    NSNumber *muted = json[HSBRemotePayloadKeyMuted];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:HSBTVOSStateUpdatedNotification 
                                                            object:manager 
                                                          userInfo:@{HSBRemotePayloadKeyCurrentTime: currentTime ?: @(0), 
                                                                     HSBRemotePayloadKeyDuration: duration ?: @(0), 
                                                                     HSBRemotePayloadKeyHidden: hiddenObj ?: @(NO),
                                                                     HSBRemotePayloadKeyPlaybackState: playbackState ?: @(NO),
                                                                     HSBRemotePayloadKeyVolume: volume ?: @(1.0),
                                                                     HSBRemotePayloadKeyMuted: muted ?: @(NO)}];
    });
}

+ (void)handleSyncFavorites:(NSDictionary *)json fromManager:(HSBTVOSConnectionManager *)manager {
    NSArray *favorites = json[HSBRemotePayloadKeyChannels];
    if (favorites && [favorites isKindOfClass:[NSArray class]]) {
        [[NSUserDefaults standardUserDefaults] setObject:favorites forKey:@"HSBIPTVFavorites"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:HSBIPTVFavoritesUpdatedNotification 
                                                                object:manager 
                                                              userInfo:@{HSBRemotePayloadKeyChannels: favorites}];
        });
    }
}

+ (void)postNotification:(NSString *)name json:(NSDictionary *)json fromManager:(HSBTVOSConnectionManager *)manager {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:name
                                                            object:manager
                                                          userInfo:json];
    });
}

+ (void)handleSingleTranslation:(NSDictionary *)json fromManager:(HSBTVOSConnectionManager *)manager {
    NSString *requestId = json[HSBRemotePayloadKeyRequestId];
    NSString *text = json[HSBRemotePayloadKeyText];
    NSString *sourceLanguage = json[HSBRemotePayloadKeySourceLanguage];
    NSString *targetLanguage = json[HSBRemotePayloadKeyTargetLanguage];
    if (requestId && text.length > 0) {
        NSString *systemPrompt = [HSBLocalLLMManager translationSystemPromptWithSource:sourceLanguage target:targetLanguage];
        __weak typeof(manager) weakManager = manager;
        [[HSBLocalLLMManager shared] processMessage:text systemPrompt:systemPrompt type:1 completion:^(NSString * _Nullable response, BOOL isFinished) {
            if (isFinished) {
                [weakManager sendPayload:@{
                    HSBRemotePayloadKeyAction: HSBRemoteSimulateActionTranslationResult,
                    HSBRemotePayloadKeyRequestId: requestId,
                    HSBRemotePayloadKeyResult: response ?: @""
                }];
            }
        }];
    }
}

+ (void)handleBlocksTranslation:(NSDictionary *)json fromManager:(HSBTVOSConnectionManager *)manager {
    NSString *requestId = json[HSBRemotePayloadKeyRequestId];
    NSArray *blocks = json[HSBRemotePayloadKeyBlocks];
    NSString *sourceLanguage = json[HSBRemotePayloadKeySourceLanguage];
    NSString *targetLanguage = json[HSBRemotePayloadKeyTargetLanguage];
    if (requestId && blocks.count > 0) {
        NSMutableDictionary *translationMap = [NSMutableDictionary dictionary];
        dispatch_group_t group = dispatch_group_create();
        NSString *systemPrompt = [HSBLocalLLMManager translationSystemPromptWithSource:sourceLanguage target:targetLanguage];
        
        for (NSDictionary *block in blocks) {
            id rawBlockId = block[HSBRemotePayloadKeyId];
            NSString *blockId = rawBlockId ? [NSString stringWithFormat:@"%@", rawBlockId] : nil;
            NSString *text = block[HSBRemotePayloadKeyText];
            if (blockId && text.length > 0) {
                dispatch_group_enter(group);
                
                [[HSBLocalLLMManager shared] processMessage:text systemPrompt:systemPrompt type:1 completion:^(NSString * _Nullable response, BOOL isFinished) {
                    if (isFinished) {
                        if (response) {
                            @synchronized (translationMap) {
                                translationMap[blockId] = response;
                            }
                        }
                        dispatch_group_leave(group);
                    }
                }];
            }
        }
        
        __weak typeof(manager) weakManager = manager;
        dispatch_group_notify(group, dispatch_get_main_queue(), ^{
            [weakManager sendPayload:@{
                HSBRemotePayloadKeyAction: HSBRemoteSimulateActionTranslationBlocksResult,
                HSBRemotePayloadKeyRequestId: requestId,
                HSBRemotePayloadKeyTranslationMap: translationMap
            }];
        });
    }
}

@end
