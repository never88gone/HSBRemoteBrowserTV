//
//  HSBTVOSTCPConnector.m
//  HSBWatchCompanion
//

#import "HSBTVOSTCPConnector.h"
#import "HSBTVOSKeychainStore.h"

@implementation HSBTVOSTCPConnector

+ (nw_parameters_t)createParametersWithKey:(nullable NSData *)key identity:(nullable NSString *)identity {
    nw_parameters_t parameters = nw_parameters_create_secure_tcp(^(nw_protocol_options_t tlsOptions) {
        sec_protocol_options_t securityOptions = nw_tls_copy_sec_protocol_options(tlsOptions);
        sec_protocol_options_set_min_tls_protocol_version(securityOptions, tls_protocol_version_TLSv12);
        if (key.length == 32 && identity.length > 0) {
            sec_protocol_options_add_pre_shared_key(securityOptions,
                [HSBTVOSKeychainStore createDispatchData:key],
                [HSBTVOSKeychainStore createDispatchData:[identity dataUsingEncoding:NSUTF8StringEncoding]]);
        }
    }, ^(nw_protocol_options_t tcpOptions) {
        nw_tcp_options_set_enable_keepalive(tcpOptions, true);
        nw_tcp_options_set_keepalive_idle_time(tcpOptions, 15);
        nw_tcp_options_set_keepalive_interval(tcpOptions, 5);
        nw_tcp_options_set_keepalive_count(tcpOptions, 3);
    });
    nw_parameters_set_include_peer_to_peer(parameters, true);
    return parameters;
}

- (nw_connection_t)createAndStartConnectionToEndpoint:(nw_endpoint_t)endpoint
                                           parameters:(nw_parameters_t)parameters
                                                queue:(dispatch_queue_t)queue {
    nw_connection_t connection = nw_connection_create(endpoint, parameters);
    nw_connection_set_queue(connection, queue);
    
    __weak typeof(self) weakSelf = self;
    nw_connection_set_state_changed_handler(connection, ^(nw_connection_state_t state, nw_error_t error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        
        switch (state) {
            case nw_connection_state_ready:
                [strongSelf.delegate tcpConnector:strongSelf didBecomeReadyWithConnection:connection];
                break;
            case nw_connection_state_failed:
                [strongSelf.delegate tcpConnector:strongSelf didFailWithConnection:connection error:error];
                break;
            case nw_connection_state_cancelled:
                [strongSelf.delegate tcpConnector:strongSelf didCancelWithConnection:connection];
                break;
            default:
                break;
        }
    });
    
    nw_connection_start(connection);
    return connection;
}

@end
