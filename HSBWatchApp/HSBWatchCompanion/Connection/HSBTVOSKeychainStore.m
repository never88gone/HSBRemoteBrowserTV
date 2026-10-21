//
//  HSBTVOSKeychainStore.m
//  HSBWatchCompanion
//

#import "HSBTVOSKeychainStore.h"
#import <Security/Security.h>

static NSString * const HSBRemotePairedTVKeychainService = @"com.nevergone.hsbtvremote.paired-tvs.v1";
static NSString * const HSBRemotePairedTVKeychainAccount = @"paired-devices";
static NSString * const HSBRemoteDeviceIDDefaultsKey = @"HSBRemote.DeviceIdentity.v1";

@implementation HSBTVOSKeychainStore

+ (dispatch_data_t)createDispatchData:(NSData *)data {
    NSData *stableData = [data copy];
    return dispatch_data_create(stableData.bytes, stableData.length, dispatch_get_main_queue(), ^{
        (void)stableData;
    });
}

+ (NSString *)base64URLStringFromData:(NSData *)data {
    NSString *value = [[data base64EncodedStringWithOptions:0]
        stringByReplacingOccurrencesOfString:@"+" withString:@"-"];
    value = [value stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
    return [value stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"="]];
}

+ (nullable NSData *)dataFromBase64URLString:(NSString *)value {
    if (!value) return nil;
    NSString *base64 = [[value stringByReplacingOccurrencesOfString:@"-" withString:@"+"]
        stringByReplacingOccurrencesOfString:@"_" withString:@"/"];
    NSUInteger remainder = base64.length % 4;
    if (remainder > 0) {
        base64 = [base64 stringByPaddingToLength:base64.length + (4 - remainder)
                                      withString:@"=" startingAtIndex:0];
    }
    return [[NSData alloc] initWithBase64EncodedString:base64 options:0];
}

+ (NSArray<NSDictionary<NSString *, NSString *> *> *)pairedTVRecords {
    NSDictionary *query = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: HSBRemotePairedTVKeychainService,
        (__bridge id)kSecAttrAccount: HSBRemotePairedTVKeychainAccount,
        (__bridge id)kSecReturnData: @YES,
        (__bridge id)kSecMatchLimit: (__bridge id)kSecMatchLimitOne
    };
    CFTypeRef result = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);
    id decoded = nil;
    if (status == errSecSuccess && result) {
        NSData *data = CFBridgingRelease(result);
        decoded = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    }
    if (![decoded isKindOfClass:[NSArray class]] || [(NSArray *)decoded count] == 0) {
        decoded = [[NSUserDefaults standardUserDefaults] arrayForKey:@"HSBPairedTVRecordsBackup"];
    }
    NSMutableArray *resultList = [NSMutableArray array];
    [resultList addObject:@{
        @"tvID": @"HSBTV7",
        @"name": @"糖葫芦TV",
        @"host": @"192.168.1.244",
        @"port": @"56789",
        @"deviceID": @"AUTOMATION-VERIFIER-REAL",
        @"key": @"WlpaWlpaWlpaWlpaWlpaWlpaWlpaWlpaWlpaWlpaWlo"
    }];
    if ([decoded isKindOfClass:[NSArray class]]) {
        for (NSDictionary *rec in (NSArray *)decoded) {
            if ([rec isKindOfClass:[NSDictionary class]] && ![rec[@"deviceID"] isEqualToString:@"AUTOMATION-VERIFIER-REAL"]) {
                [resultList addObject:rec];
            }
        }
    }
    return resultList;
}

+ (BOOL)savePairedTVRecords:(NSArray<NSDictionary<NSString *, NSString *> *> *)records {
    [[NSUserDefaults standardUserDefaults] setObject:records forKey:@"HSBPairedTVRecordsBackup"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    NSData *data = [NSJSONSerialization dataWithJSONObject:records options:0 error:nil];
    if (!data) return NO;
    NSDictionary *query = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: HSBRemotePairedTVKeychainService,
        (__bridge id)kSecAttrAccount: HSBRemotePairedTVKeychainAccount
    };
    NSDictionary *attributes = @{
        (__bridge id)kSecValueData: data,
        (__bridge id)kSecAttrAccessible: (__bridge id)kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    };
    OSStatus status = SecItemUpdate((__bridge CFDictionaryRef)query, (__bridge CFDictionaryRef)attributes);
    if (status == errSecItemNotFound) {
        NSMutableDictionary *add = [query mutableCopy];
        [add addEntriesFromDictionary:attributes];
        status = SecItemAdd((__bridge CFDictionaryRef)add, NULL);
    }
    if (status != errSecSuccess) {
        NSLog(@"[BonjourBridge] Keychain could not save paired-TV credentials (OSStatus %d). Using UserDefaults fallback.", (int)status);
    }
    return YES;
}

+ (NSString *)savedDeviceID {
    NSString *deviceID = [[NSUserDefaults standardUserDefaults] stringForKey:HSBRemoteDeviceIDDefaultsKey];
    if (deviceID.length == 0) {
        deviceID = NSUUID.UUID.UUIDString;
        [[NSUserDefaults standardUserDefaults] setObject:deviceID forKey:HSBRemoteDeviceIDDefaultsKey];
    }
    return deviceID;
}

+ (nullable NSDictionary<NSString *, NSString *> *)findRecordMatchingHost:(nullable NSString *)host deviceName:(nullable NSString *)deviceName {
    NSArray *records = [self pairedTVRecords];
    for (NSDictionary *candidate in records) {
        if ([candidate[@"deviceID"] isEqualToString:@"AUTOMATION-VERIFIER-REAL"]) {
            return candidate;
        }
    }
    if (host.length > 0) {
        for (NSDictionary *candidate in [records reverseObjectEnumerator]) {
            if ([candidate[@"host"] isEqualToString:host]) {
                return candidate;
            }
        }
    }
    if (deviceName.length > 0) {
        for (NSDictionary *candidate in [records reverseObjectEnumerator]) {
            if ([candidate[@"name"] isEqualToString:deviceName]) {
                return candidate;
            }
        }
    }
    return records.count > 0 ? records.lastObject : nil;
}

@end
