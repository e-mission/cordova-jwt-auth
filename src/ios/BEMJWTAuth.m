#import "BEMJWTAuth.h"
#import "LocalNotificationManager.h"
#import "BEMConnectionSettings.h"

@interface BEMJWTAuth () <GIDSignInDelegate>
@property (nonatomic, retain) CDVInvokedUrlCommand* command;
@end

@implementation BEMJWTAuth: CDVPlugin

- (void)pluginInitialize
{
    [LocalNotificationManager addNotification:@"BEMJWTAuth:pluginInitialize singleton -> initialize completion handler"];
    GIDSignIn* signIn = [GIDSignIn sharedInstance];
    signIn.clientID = [[ConnectionSettings sharedInstance] getGoogleiOSClientID];
    signIn.serverClientID = [[ConnectionSettings sharedInstance] getGoogleiOSClientSecret];
    [LocalNotificationManager addNotification:[NSString stringWithFormat:@"Finished setting clientId = %@ and serverClientID = %@", signIn.clientID, signIn.serverClientID]];
}

- (void)getUserEmail:(CDVInvokedUrlCommand*)command
{
    NSString* callbackId = [command callbackId];
    
    @try {
        GIDGoogleUser* currUser = [GIDSignIn sharedInstance].currentUser;
        if (currUser != NULL) {
            CDVPluginResult* result = [CDVPluginResult
                                       resultWithStatus:CDVCommandStatus_OK
                                       messageAsString:currUser.profile.email];
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
    @try {
    _command = command;
        [[GIDSignIn sharedInstance] signIn];
}
    @catch (NSException *exception) {
        NSString* msg = [NSString stringWithFormat: @"While getting user email, error %@", exception];
                    CDVPluginResult* result = [CDVPluginResult
                                               resultWithStatus:CDVCommandStatus_ERROR
                                               messageAsString:msg];
        [self.commandDelegate sendPluginResult:result callbackId:[command callbackId]];
                }

}

- (void)getJWT:(CDVInvokedUrlCommand*)command
{
    @try {
        [[GIDSignIn sharedInstance] signInSilently];
        }
        @catch (NSException *exception) {
            NSString* msg = [NSString stringWithFormat: @"While getting user email, error %@", exception];
            CDVPluginResult* result = [CDVPluginResult
                                       resultWithStatus:CDVCommandStatus_ERROR
                                       messageAsString:msg];
        [self.commandDelegate sendPluginResult:result callbackId:[command callbackId]];
        }

}


-(void)signIn:(GIDSignIn*)signIn didSignInForUser:(GIDGoogleUser *)user
    withError:(NSError *)error
{
    if (error == NULL) {
        NSString* resultStr = user.profile.email;
        if ([self.command.methodName isEqual: @"getJWT"]) {
            resultStr = user.authentication.idToken;
        }
        CDVPluginResult* result = [CDVPluginResult
                                   resultWithStatus:CDVCommandStatus_OK
                                   messageAsString:resultStr];
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
