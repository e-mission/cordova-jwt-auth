#import "BEMOPCode.h"
#import "LocalNotificationManager.h"
#import "AuthTokenCreationFactory.h"
#import "AuthTokenCreator.h"
#import "BEMBuiltinUserCache.h"

@interface BEMOPCode ()
@property (nonatomic, retain) CDVInvokedUrlCommand* command;
@property id<AuthTokenCreator> token_creator;
@end

@implementation BEMOPCode: CDVPlugin


- (void)pluginInitialize
{
    [LocalNotificationManager addNotification:@"BEMJWTAuth:pluginInitialize singleton -> initialize completion handler"];
    
    NSDictionary* introDoneResult = [[BuiltinUserCache database] getLocalStorage:@"intro_done" withMetadata:NO];
    [LocalNotificationManager addNotification:[NSString stringWithFormat:@"intro_done result = %@", introDoneResult]];
    if (introDoneResult != NULL) {
        id<AuthTokenCreator> authHandler = [AuthTokenCreationFactory getInstance];
        [authHandler getJWT:^(NSString *token, NSError *error) {
            if (token == NULL) {
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
        }];
    }
}

- (void)getOPCode:(CDVInvokedUrlCommand*)command
{
    NSString* callbackId = [command callbackId];
    
    @try {
        // Ideally, we would re-use getCallbackForCommand here, but that would return
        // an error if the user did not exist. But the existing behavior is that it returns the
        // message OK with result = NULL if the user does not exist.
        // Maintaining that backwards compatible behavior for now...
        _token_creator = [AuthTokenCreationFactory getInstance];
        [_token_creator getOPCode:^(NSString *userEmail, NSError *error) {
            if (userEmail != NULL) {
                CDVPluginResult* result = [CDVPluginResult
                                           resultWithStatus:CDVCommandStatus_OK
                                           messageAsString:userEmail];
                [self.commandDelegate sendPluginResult:result callbackId:callbackId];
            } else {
                CDVPluginResult* result = [CDVPluginResult
                                           resultWithStatus:CDVCommandStatus_OK
                                           messageAsString:NULL];
                [self.commandDelegate sendPluginResult:result callbackId:callbackId];
            }
        }];
    }
    @catch (NSException *exception) {
        NSString* msg = [NSString stringWithFormat: @"While getting user email, error %@", exception];
        CDVPluginResult* result = [CDVPluginResult
                                   resultWithStatus:CDVCommandStatus_ERROR
                                   messageAsString:msg];
        [self.commandDelegate sendPluginResult:result callbackId:callbackId];
    }
}

- (void)setOPCode:(CDVInvokedUrlCommand*)command
{
    @try {
        _token_creator = [AuthTokenCreationFactory getInstance];
        NSString* opcode = [[command arguments] objectAtIndex:0];
        [_token_creator setOPCode:opcode];
        [self getCallbackForCommand:command](opcode, NULL);
    }
    @catch (NSException *exception) {
            NSString* msg = [NSString stringWithFormat: @"While setting programmatic token, error %@", exception];
        CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                       messageAsString:msg];
        [self.commandDelegate sendPluginResult:result callbackId:[command callbackId]];
    }
}




-(AuthResultCallback) getCallbackForCommand:(CDVInvokedUrlCommand*)command
{
    return ^(NSString *resultStr, NSError *error) {
    if (error == NULL) {
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

@end
