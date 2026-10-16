//
//  HSBTVOSKeychainStore.h
//  HSBWatchCompanion
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface HSBTVOSKeychainStore : NSObject

+ (NSArray<NSDictionary<NSString *, NSString *> *> *)pairedTVRecords;
+ (BOOL)savePairedTVRecords:(NSArray<NSDictionary<NSString *, NSString *> *> *)records;

+ (nullable NSData *)dataFromBase64URLString:(NSString *)value;
+ (NSString *)base64URLStringFromData:(NSData *)data;

+ (NSString *)savedDeviceID;
+ (void)saveDeviceID:(NSString *)deviceID;

+ (dispatch_data_t)createDispatchData:(NSData *)data;

+ (nullable NSDictionary<NSString *, NSString *> *)findRecordMatchingHost:(nullable NSString *)host deviceName:(nullable NSString *)deviceName;

@end

NS_ASSUME_NONNULL_END
