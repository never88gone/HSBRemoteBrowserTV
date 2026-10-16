//
//  HSBTVOSPairingCoordinator.h
//  HSBWatchCompanion
//

#import <Foundation/Foundation.h>
#import <Network/Network.h>

NS_ASSUME_NONNULL_BEGIN

@class HSBTVOSPairingCoordinator;

@protocol HSBTVOSPairingCoordinatorDelegate <NSObject>
- (void)pairingCoordinator:(HSBTVOSPairingCoordinator *)coordinator
 didRequestConnectEndpoint:(nw_endpoint_t)endpoint
                deviceName:(NSString *)deviceName;
- (void)pairingCoordinator:(HSBTVOSPairingCoordinator *)coordinator
didCompleteSecurePairingWithRecord:(NSDictionary<NSString *, NSString *> *)record
                  endpoint:(nw_endpoint_t)endpoint;
- (void)pairingCoordinator:(HSBTVOSPairingCoordinator *)coordinator
          didFailWithError:(NSString *)errorMessage;
- (void)pairingCoordinator:(HSBTVOSPairingCoordinator *)coordinator
 didAuthenticateConnection:(nw_connection_t)connection
                   message:(NSString *)message;
@end

@interface HSBTVOSPairingCoordinator : NSObject

@property (nonatomic, weak) id<HSBTVOSPairingCoordinatorDelegate> delegate;

@property (nonatomic, copy, nullable) NSString *pairingToken;
@property (nonatomic, copy, nullable) NSString *pairingTVID;
@property (nonatomic, copy, nullable) NSString *pairingHost;
@property (nonatomic, copy, nullable) NSString *pairingPort;
@property (nonatomic, copy, nullable) NSString *pairingName;
@property (nonatomic, strong, nullable) NSDate *pairingExpirationDate;
@property (nonatomic, copy, nullable) NSString *deviceID;
@property (nonatomic, copy, nullable) NSString *deviceKey;
@property (nonatomic, copy, nullable) NSDictionary<NSString *, NSString *> *pairedTVRecord;
@property (nonatomic, assign) BOOL isAuthenticating;

- (BOOL)isPairingTokenActive;
- (void)clearPairingSession;
- (BOOL)handlePairingURL:(NSURL *)pairingURL;
- (void)sendRemoteHelloOnConnection:(nw_connection_t)connection;
- (void)handleSecureHandshakeResponse:(NSDictionary *)json
                       fromConnection:(nw_connection_t)connection
                      currentEndpoint:(nullable nw_endpoint_t)endpoint;

@end

NS_ASSUME_NONNULL_END
