#import <Cordova/CDV.h>
#import "AuthCompletionHandler.h" 

@interface BEMJWTAuth: CDVPlugin <AuthCompletionDelegate>

- (void) getUserEmail:(CDVInvokedUrlCommand*)command;
- (void) signIn:(CDVInvokedUrlCommand*)command;
- (void) getJWT:(CDVInvokedUrlCommand*)command;

@end
