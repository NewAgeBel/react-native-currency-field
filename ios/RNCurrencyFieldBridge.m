#import <React/RCTBridgeModule.h>

@interface RCT_EXTERN_MODULE(RNCurrencyField, NSObject)


RCT_EXTERN__BLOCKING_SYNCHRONOUS_METHOD(formatValue:(nonnull NSNumber) value
                                        currency: (nonnull NSString) currency)
RCT_EXTERN__BLOCKING_SYNCHRONOUS_METHOD(extractValue:(nonnull NSString) value
                                        currency: (nonnull NSString) currency)

RCT_EXTERN_METHOD(initializeCurrencyField:(nonnull NSNumber *)reactNode
                  options:(NSDictionary *)option)

@end
