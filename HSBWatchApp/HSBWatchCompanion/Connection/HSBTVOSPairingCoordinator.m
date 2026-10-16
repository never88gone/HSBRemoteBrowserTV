//
//  HSBTVOSPairingCoordinator.m
//  HSBWatchCompanion
//

#import "HSBTVOSPairingCoordinator.h"
#import "HSBTVOSKeychainStore.h"
#import "HSBTVOSConnectionConstants.h"
#import <UIKit/UIKit.h>
#import <Security/Security.h>

@implementation HSBTVOSPairingCoordinator

- (BOOL)isPairingTokenActive {
    return self.pairingToken.length > 0 &&
           self.pairingExpirationDate &&
           self.pairingExpirationDate.timeIntervalSinceNow > 0;
}

- (void)clearPairingSession {
    self.pairingToken = nil;
    self.pairingExpirationDate = nil;
    self.pairingTVID = nil;
    self.pairingHost = nil;
    self.pairingPort = nil;
    self.pairingName = nil;
    self.deviceKey = nil;
    self.isAuthenticating = NO;
}

- (BOOL)handlePairingURL:(NSURL *)pairingURL {
    NSURLComponents *components = [NSURLComponents componentsWithURL:pairingURL resolvingAgainstBaseURL:NO];
    if (![components.scheme isEqualToString:@"hsbremote"] ||
        ![components.host isEqualToString:@"pair"]) {
        return NO;
    }
    
    NSMutableDictionary<NSString *, NSString *> *values = [NSMutableDictionary dictionary];
    for (NSURLQueryItem *item in components.queryItems) {
        if (item.name && item.value) {
            values[item.name] = item.value;
        }
    }
    
    NSString *tvID = values[@"tv"];
    NSString *name = values[@"name"];
    NSString *host = values[@"host"];
    NSString *token = values[@"token"];
    NSInteger port = values[@"port"].integerValue;
    NSTimeInterval expiry = values[@"expires"].doubleValue;
    NSTimeInterval now = NSDate.date.timeIntervalSince1970;
#if DEBUG
    NSTimeInterval maxWindow = 86400.0;
#else
    NSTimeInterval maxWindow = 300.0;
#endif

    NSData *tokenData = [HSBTVOSKeychainStore dataFromBase64URLString:token ?: @""];
    if (tvID.length == 0 || name.length == 0 || host.length == 0 || port < 1024 || port > 65535 ||
        tokenData.length != 32 || expiry <= now || expiry > now + maxWindow) {
        NSLog(@"[BonjourBridge] Pairing URL validation failed: tvID=%@, host=%@, port=%ld, tokenLen=%lu, expiryDiff=%f (maxWindow=%f)",
              tvID, host, (long)port, (unsigned long)tokenData.length, expiry - now, maxWindow);
        return NO;
    }
    NSLog(@"[BonjourBridge] Pairing URL validated successfully for TV: %@ (%@:%ld)", name, host, (long)port);

    NSMutableData *randomKey = [NSMutableData dataWithLength:32];
    if (SecRandomCopyBytes(kSecRandomDefault, randomKey.length, randomKey.mutableBytes) != errSecSuccess) {
        return NO;
    }
    
    NSString *deviceID = [HSBTVOSKeychainStore savedDeviceID];
    self.pairingTVID = tvID;
    self.pairingName = name;
    self.pairingHost = host;
    self.pairingPort = values[@"port"] ?: [@(port) stringValue];
    self.pairingToken = token;
    self.pairingExpirationDate = [NSDate dateWithTimeIntervalSince1970:expiry];
    self.deviceID = deviceID;
    self.deviceKey = [HSBTVOSKeychainStore base64URLStringFromData:randomKey];
    self.pairedTVRecord = nil;

    nw_endpoint_t endpoint = nw_endpoint_create_host(host.UTF8String, [@(port) stringValue].UTF8String);
    if ([self.delegate respondsToSelector:@selector(pairingCoordinator:didRequestConnectEndpoint:deviceName:)]) {
        [self.delegate pairingCoordinator:self didRequestConnectEndpoint:endpoint deviceName:name];
    }
    return YES;
}

- (void)sendRemoteHelloOnConnection:(nw_connection_t)connection {
    if (!connection || !self.deviceID || !self.deviceKey) return;
    NSMutableDictionary *hello = [@{
        HSBRemotePayloadKeyAction: @"remote_hello",
        @"deviceID": self.deviceID,
        @"deviceName": UIDevice.currentDevice.name ?: @"iPhone",
        @"deviceKey": self.deviceKey,
        @"protocolVersion": @1,
        @"capabilities": @[@"remote-control", @"iptv", @"epg", @"playback"]
    } mutableCopy];
    if (self.pairingToken.length > 0) {
        hello[@"pairingToken"] = self.pairingToken;
    }
    
    NSData *data = [NSJSONSerialization dataWithJSONObject:hello options:0 error:nil];
    if (!data) return;
    
    nw_connection_send(connection, [HSBTVOSKeychainStore createDispatchData:data], NW_CONNECTION_DEFAULT_MESSAGE_CONTEXT, true, ^(nw_error_t error) {
        if (error) {
            NSLog(@"[BonjourBridge] TLS device hello failed: %@", error);
        }
    });
}

- (void)handleSecureHandshakeResponse:(NSDictionary *)json
                       fromConnection:(nw_connection_t)connection
                      currentEndpoint:(nullable nw_endpoint_t)endpoint {
    NSString *action = [json[HSBRemotePayloadKeyAction] isKindOfClass:[NSString class]] ? json[HSBRemotePayloadKeyAction] : @"";
    if (([action isEqualToString:@"remote_hello_ack"] || [action isEqualToString:@"remote_pairing_complete"]) &&
        [json[@"protocolVersion"] integerValue] != 1) {
        NSLog(@"[BonjourBridge] TV remote protocol version is unsupported.");
        nw_connection_cancel(connection);
        self.isAuthenticating = NO;
        if ([self.delegate respondsToSelector:@selector(pairingCoordinator:didFailWithError:)]) {
            [self.delegate pairingCoordinator:self didFailWithError:@"Update the TV app to connect securely."];
        }
        return;
    }
    
    if ([action isEqualToString:@"remote_hello_ack"] || [action isEqualToString:@"remote_pairing_complete"]) {
        NSString *expectedTVID = self.pairingTVID ?: self.pairedTVRecord[@"tvID"];
        NSString *actualTVID = [json[@"tvID"] isKindOfClass:[NSString class]] ? json[@"tvID"] : @"";
        NSArray *capabilities = [json[@"capabilities"] isKindOfClass:[NSArray class]] ? json[@"capabilities"] : @[];
        NSSet *negotiated = [NSSet setWithArray:capabilities];
        NSMutableSet *missingCapabilities = [NSMutableSet setWithArray:@[@"remote-control", @"iptv", @"epg", @"playback"]];
        [missingCapabilities minusSet:negotiated];
        if (expectedTVID.length == 0 || ![expectedTVID isEqualToString:actualTVID] || missingCapabilities.count > 0) {
            NSLog(@"[BonjourBridge] TV identity or iPTV capabilities do not match the paired remote.");
            nw_connection_cancel(connection);
            self.isAuthenticating = NO;
            if ([self.delegate respondsToSelector:@selector(pairingCoordinator:didFailWithError:)]) {
                [self.delegate pairingCoordinator:self didFailWithError:@"Update the TV app to enable secure iPTV control."];
            }
            return;
        }
    }
    
    if ([action isEqualToString:@"remote_hello_ack"]) {
        if ([self.delegate respondsToSelector:@selector(pairingCoordinator:didAuthenticateConnection:message:)]) {
            [self.delegate pairingCoordinator:self didAuthenticateConnection:connection message:@"🟢 Securely connected to TV"];
        }
    } else if ([action isEqualToString:@"remote_pairing_complete"]) {
        [self completeSecurePairingWithEndpoint:endpoint connection:connection];
    } else if ([action isEqualToString:@"remote_pairing_failed"]) {
        [self clearPairingSession];
        nw_connection_cancel(connection);
        if ([self.delegate respondsToSelector:@selector(pairingCoordinator:didFailWithError:)]) {
            [self.delegate pairingCoordinator:self didFailWithError:@"Pairing expired. Scan the TV QR code again."];
        }
    }
}

- (void)completeSecurePairingWithEndpoint:(nullable nw_endpoint_t)endpoint connection:(nw_connection_t)connection {
    NSDictionary *record = @{
        @"tvID": self.pairingTVID ?: @"",
        @"name": self.pairingName ?: @"Apple TV",
        @"host": self.pairingHost ?: @"",
        @"port": self.pairingPort ?: @"56789",
        @"deviceID": self.deviceID ?: @"",
        @"key": self.deviceKey ?: @""
    };
    
    NSMutableArray *records = [[HSBTVOSKeychainStore pairedTVRecords] mutableCopy];
    NSIndexSet *existing = [records indexesOfObjectsPassingTest:^BOOL(NSDictionary *item, NSUInteger idx, BOOL *stop) {
        return [item[@"tvID"] isEqualToString:record[@"tvID"]];
    }];
    [records removeObjectsAtIndexes:existing];
    [records addObject:record];
    
    if (![HSBTVOSKeychainStore savePairedTVRecords:records]) {
        NSLog(@"[BonjourBridge] Could not save paired-TV key in Keychain.");
        [self clearPairingSession];
        nw_connection_cancel(connection);
        if ([self.delegate respondsToSelector:@selector(pairingCoordinator:didFailWithError:)]) {
            [self.delegate pairingCoordinator:self didFailWithError:@"Could not save secure pairing. Scan the TV code again."];
        }
        return;
    }
    
    self.pairedTVRecord = record;
    self.pairingToken = nil;
    self.pairingExpirationDate = nil;
    self.isAuthenticating = NO;
    
    if (endpoint && [self.delegate respondsToSelector:@selector(pairingCoordinator:didCompleteSecurePairingWithRecord:endpoint:)]) {
        [self.delegate pairingCoordinator:self didCompleteSecurePairingWithRecord:record endpoint:endpoint];
    }
}

@end
