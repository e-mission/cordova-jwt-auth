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

@implementation AuthCompletionHandler

static AuthCompletionHandler *sharedInstance;
NSString* const STATUS_KEY = @"success";
NSString* const BEMJWTAuthComplete = @"BEMJWTAuthComplete";

+ (AuthCompletionHandler*)sharedInstance
{
    if (sharedInstance == nil) {
        NSLog(@"creating new AuthCompletionHandler sharedInstance");
        sharedInstance = [AuthCompletionHandler new];
        [GIDSignIn sharedInstance].delegate = sharedInstance;
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

// END: Silent auth methods


@end
