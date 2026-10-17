//
//  HSBTVOSTCPConnector.h
//  HSBWatchCompanion
//

#import <Foundation/Foundation.h>
#import <Network/Network.h>

NS_ASSUME_NONNULL_BEGIN

@class HSBTVOSTCPConnector;

@protocol HSBTVOSTCPConnectorDelegate <NSObject>
- (void)tcpConnector:(HSBTVOSTCPConnector *)connector didBecomeReadyWithConnection:(nw_connection_t)connection;
- (void)tcpConnector:(HSBTVOSTCPConnector *)connector didFailWithConnection:(nw_connection_t)connection error:(nullable nw_error_t)error;
- (void)tcpConnector:(HSBTVOSTCPConnector *)connector didCancelWithConnection:(nw_connection_t)connection;
@end

@interface HSBTVOSTCPConnector : NSObject

@property (nonatomic, weak) id<HSBTVOSTCPConnectorDelegate> delegate;

+ (nw_parameters_t)createParametersWithKey:(nullable NSData *)key identity:(nullable NSString *)identity;

- (nw_connection_t)createAndStartConnectionToEndpoint:(nw_endpoint_t)endpoint
                                           parameters:(nw_parameters_t)parameters
                                                queue:(dispatch_queue_t)queue;

@end

NS_ASSUME_NONNULL_END
