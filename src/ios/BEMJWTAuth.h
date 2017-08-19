#import <Cordova/CDV.h>

@interface BEMJWTAuth: CDVPlugin

- (void) getUserEmail:(CDVInvokedUrlCommand*)command;
- (void) signIn:(CDVInvokedUrlCommand*)command;
- (void) getJWT:(CDVInvokedUrlCommand*)command;

@end
