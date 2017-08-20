//
//  AuthCompletionHandler.m
//  E-Mission
//
//  Created by Kalyanaraman Shankari on 4/3/14.
//  Copyright (c) 2014 Kalyanaraman Shankari. All rights reserved.
//

/*
 * Shared sign-in instance only allows us to have a single delegate. But we may want multiple auths - for screen, for background jobs, for multiple background jobs running in parallel...
     So we go to our familiar listener pattern
 */

#import "AuthCompletionHandler.h"
#import "BEMConnectionSettings.h"
#import "BEMConstants.h"
#import "LocalNotificationManager.h"
#import <Cordova/CDV.h>
#import <GoogleSignIn/GoogleSignIn.h>


typedef void (^AuthCompletionCallback)(GIDGoogleUser *,NSError*);
typedef NSString* (^ProfileRetValue)(GIDGoogleUser *);

#define NOT_SIGNED_IN_CODE 1000

@interface AuthCompletionHandler () <GIDSignInDelegate, GIDSignInUIDelegate>
    @property (atomic, retain) CDVPlugin* mPlugin;
@end

@implementation AuthCompletionHandler

static AuthCompletionHandler *sharedInstance;
NSString* const STATUS_KEY = @"success";
NSString* const BEMJWTAuthComplete = @"BEMJWTAuthComplete";

+ (AuthCompletionHandler*)sharedInstance
{
    if (sharedInstance == nil) {
        NSLog(@"creating new AuthCompletionHandler sharedInstance");
        sharedInstance = [AuthCompletionHandler new];

        GIDSignIn* signIn = [GIDSignIn sharedInstance];
        signIn.clientID = [[ConnectionSettings sharedInstance] getClientID];
        // client secret is no longer required for this client
        // signIn.serverClientID = [[ConnectionSettings sharedInstance] getGoogleiOSClientSecret];
        signIn.delegate = sharedInstance;
        signIn.uiDelegate = sharedInstance;
        [LocalNotificationManager addNotification:[NSString stringWithFormat:@"Finished setting clientId = %@ and serverClientID = %@", signIn.clientID, signIn.serverClientID]];
        [LocalNotificationManager addNotification:[NSString stringWithFormat:@"Finished setting delegate = %@ and uiDelegate = %@", signIn.delegate, signIn.uiDelegate]];
    }
    return sharedInstance;
}

/*
 * Returns a valid auth, including refreshing the access token if necessary.
 * Does not present the sign in screen to the user again, but returns an error
 * that the client can use to show the sign in screen.
 */

- (void) getValidAuth:(AuthCompletionCallback) authCompletionCallback
{
    [self registerCallback:authCompletionCallback];
    [[GIDSignIn sharedInstance] signInSilently];
}

- (void) registerCallback:(AuthCompletionCallback)authCompletionCallback
{
    // pattern from `addObserverForName` docs
    // https://developer.apple.com/reference/foundation/nsnotificationcenter/1411723-addobserverforname
    NSNotificationCenter * __weak center = [NSNotificationCenter defaultCenter];
    id __block token = [[NSNotificationCenter defaultCenter] addObserverForName:BEMJWTAuthComplete
                                                      object:nil
                                                       queue:nil
                                                  usingBlock:^(NSNotification *note) {
                                                      if([note.userInfo[STATUS_KEY] isEqual:@YES]) {
                                                          authCompletionCallback(note.object, NULL);
        } else {
                                                          authCompletionCallback(NULL, note.object);
}
                                                      [center removeObserver:token];
                                                  }];
}

-(void)signIn:(GIDSignIn*)signIn didSignInForUser:(GIDGoogleUser *)user
    withError:(NSError *)error
{
    if (error == NULL) {
        [[NSNotificationCenter defaultCenter] postNotificationName:BEMJWTAuthComplete
                                                            object:user userInfo:@{STATUS_KEY: @YES}];
    } else {
        [[NSNotificationCenter defaultCenter] postNotificationName:BEMJWTAuthComplete
                                                            object:error userInfo:@{STATUS_KEY: @NO}];
    }
}

-(void)handleNotification:(NSNotification *)notification
{
    NSURL* url = [notification object];
    NSDictionary* options = [notification userInfo];
    
    [[GIDSignIn sharedInstance] handleURL:url
                        sourceApplication:options[UIApplicationOpenURLOptionsSourceApplicationKey]
                               annotation:options[UIApplicationOpenURLOptionsAnnotationKey]];
}

// END: Silent auth methods

// BEGIN: callbacks for extracting value from the auth completion

- (void) getEmail:(AuthResultCallback) authResultCallback
{
    GIDGoogleUser* currUser = [GIDSignIn sharedInstance].currentUser;
    if (currUser != NULL) {
        authResultCallback(currUser.profile.email, NULL);
    } else {
        NSError* error = [NSError errorWithDomain:@"BEMAuthError"
                                             code:NOT_SIGNED_IN_CODE
                                         userInfo:NULL];
        authResultCallback(NULL, error);
    }
}

- (void) getJWT:(AuthResultCallback)authResultCallback
{
    [self getValidAuth:[self getRedirectedCallback:authResultCallback withRetValue:^NSString *(GIDGoogleUser *user) {
        return user.authentication.idToken;
    }]];
}

- (void) getExpirationDate:(AuthResultCallback)authResultCallback
{
    [self getValidAuth:[self getRedirectedCallback:authResultCallback withRetValue:^NSString *(GIDGoogleUser *user) {
        return user.authentication.idTokenExpirationDate.description;
    }]];
}

-(AuthCompletionCallback) getRedirectedCallback:(AuthResultCallback)redirCallback withRetValue:(ProfileRetValue) retValueFunctor
{
    return ^(GIDGoogleUser *user, NSError *error) {
        if (error == NULL) {
            NSString* resultStr = retValueFunctor(user);
            redirCallback(resultStr, NULL);
        } else {
            redirCallback(NULL, error);
        }
    };
}

// END: callbacks for extracting value from the auth completion

// BEGIN: UI interaction

- (void) uiSignIn:(AuthResultCallback)authResultCallback withPlugin:(CDVPlugin*) plugin
{
    self.mPlugin = plugin;
    [self registerCallback:[self getRedirectedCallback:authResultCallback
                                          withRetValue:^NSString *(GIDGoogleUser *user) {
                                              return user.profile.email;
    }]];
    [[GIDSignIn sharedInstance] signIn];
}

-(void) signIn:(GIDSignIn*)signIn presentViewController:(UIViewController *)loginScreen
{
    [self.mPlugin.viewController presentViewController:loginScreen animated:YES completion:NULL];
}

-(void) signIn:(GIDSignIn*)signIn dismissViewController:(UIViewController *)loginScreen
{
    [self.mPlugin.viewController dismissViewControllerAnimated:YES completion:NULL];
}
// END: UI interaction

@end
