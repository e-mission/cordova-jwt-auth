#import "BEMJWTAuth.h"
#import "LocalNotificationManager.h"
#import "BEMConnectionSettings.h"
#import "AuthCompletionHandler.h"
#import "BEMBuiltinUserCache.h"

@interface BEMJWTAuth () <GIDSignInUIDelegate>
@property (nonatomic, retain) CDVInvokedUrlCommand* command;
@end

@implementation BEMJWTAuth: CDVPlugin
typedef NSString* (^ProfileRetValue)(GIDGoogleUser *);

- (void)pluginInitialize
{
    [LocalNotificationManager addNotification:@"BEMJWTAuth:pluginInitialize singleton -> initialize completion handler"];
    GIDSignIn* signIn = [GIDSignIn sharedInstance];
    signIn.clientID = [[ConnectionSettings sharedInstance] getGoogleiOSClientID];
    // signIn.serverClientID = [[ConnectionSettings sharedInstance] getGoogleiOSClientSecret];
    signIn.uiDelegate = self;
    [[AuthCompletionHandler sharedInstance] getValidAuth:^(GIDGoogleUser *user, NSError *error) {
        if (user == NULL) {
            NSDictionary* introDoneResult = [[BuiltinUserCache database] getLocalStorage:@"intro_done" withMetadata:NO];
            [LocalNotificationManager addNotification:[NSString stringWithFormat:@"intro_done result = %@", introDoneResult]];
            if (introDoneResult != NULL) {

                // TODO: Refactor this into a utility function once I have a better sense of the
                // structure. Also maybe the base notification should be configurable using javascript
                NSDictionary* notifyOptions = @{@"id": @7356446, // RELOGIN on a phone keypad,
                                                @"title": @"Please login to continue server communication",
                                                @"autoclear": @TRUE,
                                                @"at": @([NSDate date].timeIntervalSince1970 + 60), // now + 60 secs
                                                @"data": @{@"redirectTo": @"root.main.control"}
                                                };
                [LocalNotificationManager showNotificationAfterSecs:@"Please login to continue server communication"
                                                       withUserInfo:notifyOptions secsLater:60];
            }
        }
    }];
    [LocalNotificationManager addNotification:[NSString stringWithFormat:@"Finished setting clientId = %@ and serverClientID = %@", signIn.clientID, signIn.serverClientID]];
    [LocalNotificationManager addNotification:[NSString stringWithFormat:@"Finished setting delegate = %@ and uiDelegate = %@", signIn.delegate, signIn.uiDelegate]];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationLaunchedWithUrl:) name:CDVPluginHandleOpenURLNotification object:nil];
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
        [[AuthCompletionHandler sharedInstance] registerCallback:[self getCallback:^NSString *(GIDGoogleUser *user) {
            return user.profile.email;
        } forCommand:command]];
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
        [[AuthCompletionHandler sharedInstance] getValidAuth:[self getCallback:^NSString *(GIDGoogleUser *user) {
            return user.authentication.idToken;
        } forCommand:command]];
        }
        @catch (NSException *exception) {
            NSString* msg = [NSString stringWithFormat: @"While getting user email, error %@", exception];
        CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                       messageAsString:msg];
        [self.commandDelegate sendPluginResult:result callbackId:[command callbackId]];
        }

}

-(AuthCompletionCallback) getCallback:(ProfileRetValue) retValueFunctor forCommand:(CDVInvokedUrlCommand*)command
{
    return ^(GIDGoogleUser *user, NSError *error) {
    if (error == NULL) {
            NSString* resultStr = retValueFunctor(user);
            CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                   messageAsString:resultStr];
        [self.commandDelegate sendPluginResult:result
                                        callbackId:command.callbackId];
    } else {
            NSString* msg = [NSString stringWithFormat: @"While signing in, error %@", error];
            CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                               messageAsString:msg];
        [self.commandDelegate sendPluginResult:result
                                        callbackId:command.callbackId];
    }
    };
}

-(void) signIn:(GIDSignIn*)signIn presentViewController:(UIViewController *)loginScreen
{
    [self.viewController presentViewController:loginScreen animated:YES completion:NULL];
}

-(void) signIn:(GIDSignIn*)signIn dismissViewController:(UIViewController *)loginScreen
{
    [self.viewController dismissViewControllerAnimated:YES completion:NULL];
}

- (void)applicationLaunchedWithUrl:(NSNotification*)notification
{
    NSURL* url = [notification object];
    NSDictionary* options = [notification userInfo];

    [[GIDSignIn sharedInstance] handleURL:url
                        sourceApplication:options[UIApplicationOpenURLOptionsSourceApplicationKey]
                               annotation:options[UIApplicationOpenURLOptionsAnnotationKey]];
}

@end
