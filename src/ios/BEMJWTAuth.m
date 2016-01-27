#import "BEMJWTAuth.h"
#import "AuthCompletionHandler.h"

@interface BEMJWTAuth () <AuthCompletionDelegate>
@property (nonatomic, retain) CDVInvokedUrlCommand* command;
@end

@implementation BEMConnectionSettings

- (void)pluginInitialize
{
    // Handle google+ sign on
    [AuthCompletionHandler sharedInstance].clientId = [[ConnectionSettings sharedInstance] getGoogleiOSClientID];
    [AuthCompletionHandler sharedInstance].clientSecret = [[ConnectionSettings sharedInstance] getGoogleiOSClientSecret];
}

- (void)getUserEmail:(CDVInvokedUrlCommand*)command
{
    NSString* callbackId = [command callbackId];
    
    @try {
        GTMOAuth2Authentication* currAuth = [AuthCompletionHandler sharedInstance].currAuth;
        if (currAuth != NULL) {
            CDVPluginResult* result = [CDVPluginResult
                                       resultWithStatus:CDVCommandStatus_OK
                                       messageAsString:currAuth.userEmail];
            [self.commandDelegate sendPluginResult:result callbackId:callbackId];
        } else {
            CDVPluginResult* result = [CDVPluginResult
                                       resultWithStatus:CDVCommandStatus_OK
                                       messageAsString:NULL];
            [self.commandDelegate sendPluginResult:result callbackId:callbackId];
        }
    }
    @catch (NSException *exception) {
        NSString* msg = [NSString stringWithFormat: @"While getting user email, error %@", e];
        CDVPluginResult* result = [CDVPluginResult
                                   resultWithStatus:CDVCommandStatus_ERROR
                                   messageAsString:msg];
        [self.commandDelegate sendPluginResult:result callbackId:callbackId];
    }
}


- (void)signIn:(CDVInvokedUrlCommand*)command
{
    NSString* callbackId = [command callbackId];
    _command = command;

    [self.commandDelegate runInBackground:^{
        [self presentSigninController];
    };
}

- (void)getJWT:(CDVInvokedUrlCommand*)command
{
    NSString* callbackId = [command callbackId];

    [self.commandDelegate runInBackground:^{
        @try {
            /* 
             * We don't just want to return the current value of the stored token,
             * because it might have expired, and then we need to refresh. Instead, we
             * call the special method just for this.
             */
            [AuthCompletionHandler getValidAuth:^((GTMOAuth2Authentication*)auth error:(NSError*)error) {
                if (error == NULL) {
                    NSString* token = [AuthCompletionHandler getIdToken];
                    CDVPluginResult* result = [CDVPluginResult
                                               resultWithStatus:CDVCommandStatus_OK
                                               messageAsString:token];
                    [self.commandDelegate sendPluginResult:result callbackId:callbackId];
                } else {
                    NSString* msg = [NSString stringWithFormat: @"While getting auth token, error %@", error];
                    CDVPluginResult* result = [CDVPluginResult
                                               resultWithStatus:CDVCommandStatus_ERROR
                                               messageAsString:msg];
                    [self.commandDelegate sendPluginResult:result callbackId:callbackId];
                }
            }];
        }
        @catch (NSException *exception) {
            NSString* msg = [NSString stringWithFormat: @"While getting user email, error %@", e];
            CDVPluginResult* result = [CDVPluginResult
                                       resultWithStatus:CDVCommandStatus_ERROR
                                       messageAsString:msg];
            [self.commandDelegate sendPluginResult:result callbackId:callbackId];
        }
    }];
}

-(void) presentSigninController {
    [[AuthCompletionHandle sharedInstance] registerFinishDelegate:self];
    UIViewController* loginScreen = [[AuthCompletionHandler sharedInstance] getSigninController];
    [self.viewController presentViewController:loginScreen
                                      animated:YES
                                    completion:NULL];
}

- (void)finishedWithAuth:(GTMOAuth2Authentication *)auth
                   error:(NSError *)error {
    NSLog(@"SignInViewController.finishedWithAuth called with auth = %@ and error = %@", auth, error);
    if (error == NULL) {
        [self.commandDelegate sendPluginResult:CDVCommandStatus_OK
                                    callbackId:_command.callbackId];
    } else {
        NSString* msg = [NSString stringWithFormat: @"While getting auth token, error %@", error];
        [self.commandDelegate sendPluginResult:CDVCommandStatus_ERROR 
                                    callbackId:_command.callbackId
                               messageAsString:msg];
    }
    [[AuthCompletionHandle sharedInstance] unregisterFinishDelegate:self];
}

@end
