#import <Cordova/CDV.h>

@interface BEMJWTAuth: CDVPlugin

- (void) getOPCode:(CDVInvokedUrlCommand*)command;
- (void) setOPCode:(CDVInvokedUrlCommand*)command;

@end
