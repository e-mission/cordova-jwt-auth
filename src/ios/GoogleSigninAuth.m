//
//  GoogleSigninAuth.m
//  E-Mission
//
//  Created by Kalyanaraman Shankari on 4/3/14.
//  Copyright (c) 2014 Kalyanaraman Shankari. All rights reserved.
//

/*
 * Shared sign-in instance only allows us to have a single delegate. But we may want multiple auths - for screen, for background jobs, for multiple background jobs running in parallel...
     So we go to our familiar listener pattern
 */

#import "GoogleSigninAuth.h"
#import "BEMConnectionSettings.h"
#import "BEMConstants.h"
#import "LocalNotificationManager.h"
#import <Cordova/CDV.h>
#import <GoogleSignIn/GoogleSignIn.h>


typedef void (^GoogleSigninCallback)(GIDGoogleUser *,NSError*);
typedef NSString* (^ProfileRetValue)(GIDGoogleUser *);

#define NOT_SIGNED_IN_CODE 1000

@interface GoogleSigninAuth () <GIDSignInDelegate>
    @property (atomic, retain) CDVPlugin* mPlugin;
@end

@implementation GoogleSigninAuth

static GoogleSigninAuth *sharedInstance;
NSString* const STATUS_KEY = @"success";
NSString* const BEMJWTAuthComplete = @"BEMJWTAuthComplete";

+ (GoogleSigninAuth*)sharedInstance
{
    if (sharedInstance == nil) {
        NSLog(@"creating new GoogleSigninAuth sharedInstance");
        sharedInstance = [GoogleSigninAuth new];

        GIDSignIn* signIn = [GIDSignIn sharedInstance];
        signIn.clientID = [[ConnectionSettings sharedInstance] authValueForKey:@"clientID"];
        // client secret is no longer required for this client
        // signIn.serverClientID = [[ConnectionSettings sharedInstance] getGoogleiOSClientSecret];
        signIn.delegate = sharedInstance;
        [LocalNotificationManager addNotification:[NSString stringWithFormat:@"Finished setting clientId = %@ and serverClientID = %@", signIn.clientID, signIn.serverClientID]];
        [LocalNotificationManager addNotification:[NSString stringWithFormat:@"Finished setting delegate = %@", signIn.delegate]];
    }
    return sharedInstance;
}

/*
 * Returns a valid auth, including refreshing the access token if necessary.
 * Does not present the sign in screen to the user again, but returns an error
 * that the client can use to show the sign in screen.
 */

- (void) getValidAuth:(GoogleSigninCallback) authCompletionCallback
{
    [self registerCallback:authCompletionCallback];
    [[GIDSignIn sharedInstance] restorePreviousSignIn];
}

- (void) registerCallback:(GoogleSigninCallback)authCompletionCallback
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
    
    [[GIDSignIn sharedInstance] handleURL:url];
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

-(GoogleSigninCallback) getRedirectedCallback:(AuthResultCallback)redirCallback withRetValue:(ProfileRetValue) retValueFunctor
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
    [GIDSignIn sharedInstance].presentingViewController = self.mPlugin.viewController;
    [self registerCallback:[self getRedirectedCallback:authResultCallback
                                          withRetValue:^NSString *(GIDGoogleUser *user) {
                                              return user.profile.email;
    }]];
}
// END: UI interaction

@end
