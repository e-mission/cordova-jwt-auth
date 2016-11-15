#import "BEMJWTAuth.h"
#import "AuthCompletionHandler.h"
#import "LocalNotificationManager.h"

@interface BEMJWTAuth () <AuthCompletionDelegate>
@property (nonatomic, retain) CDVInvokedUrlCommand* command;
@end

@implementation BEMJWTAuth: CDVPlugin

- (void)pluginInitialize
{
    [LocalNotificationManager addNotification:@"BEMJWTAuth:pluginInitialize singleton -> initialize completion handler"];
    [LocalNotificationManager addNotification:[NSString stringWithFormat:@"Auth handler is %@", [AuthCompletionHandler sharedInstance]]];
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
        NSString* msg = [NSString stringWithFormat: @"While getting user email, error %@", exception];
        CDVPluginResult* result = [CDVPluginResult
                                   resultWithStatus:CDVCommandStatus_ERROR
                                   messageAsString:msg];
        [self.commandDelegate sendPluginResult:result callbackId:callbackId];
    }
}


- (void)signIn:(CDVInvokedUrlCommand*)command
{
    _command = command;
        [self presentSigninController];
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
            [[AuthCompletionHandler sharedInstance] getValidAuth:^(GTMOAuth2Authentication* auth, NSError* error) {
                if (error == NULL) {
                    NSString* token = [[AuthCompletionHandler sharedInstance] getIdToken];
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
            } forceRefresh:FALSE];
        }
        @catch (NSException *exception) {
            NSString* msg = [NSString stringWithFormat: @"While getting user email, error %@", exception];
            CDVPluginResult* result = [CDVPluginResult
                                       resultWithStatus:CDVCommandStatus_ERROR
                                       messageAsString:msg];
            [self.commandDelegate sendPluginResult:result callbackId:callbackId];
        }
    }];
}

-(void) presentSigninController {
    AuthCompletionHandler *signIn = [AuthCompletionHandler sharedInstance];
    signIn.scope = @"https://www.googleapis.com/auth/plus.me";
    [signIn registerFinishDelegate:self];
    UIViewController* loginScreen = [[AuthCompletionHandler sharedInstance] getSigninController];
    [self.viewController presentViewController:loginScreen
                                      animated:YES
                                    completion:NULL];
}

- (void)finishedWithAuth:(GTMOAuth2Authentication *)auth
                   error:(NSError *)error
                    usingController:(UIViewController *)viewController {
    NSLog(@"SignInViewController.finishedWithAuth called with auth = %@ and error = %@", auth, error);
    [[AuthCompletionHandler sharedInstance] unregisterFinishDelegate:self];
    [viewController dismissViewControllerAnimated:YES completion:nil];
    if (error == NULL) {
        CDVPluginResult* result = [CDVPluginResult
                                   resultWithStatus:CDVCommandStatus_OK
                               messageAsString:auth.userEmail];
        [self.commandDelegate sendPluginResult:result
                                    callbackId:self.command.callbackId];
    } else {
        NSString* msg = [NSString stringWithFormat: @"While getting auth token, error %@", error];
        CDVPluginResult* result = [CDVPluginResult
                                   resultWithStatus:CDVCommandStatus_ERROR
                               messageAsString:msg];
        [self.commandDelegate sendPluginResult:result
                                    callbackId:_command.callbackId];
    }
}

@end
