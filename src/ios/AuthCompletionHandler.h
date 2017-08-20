//
//  AuthCompletionHandler.h
//  E-Mission
//
//  Created by Kalyanaraman Shankari on 4/3/14.
//  Copyright (c) 2014 Kalyanaraman Shankari. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AuthTokenCreator.h"

@interface AuthCompletionHandler : NSObject <AuthTokenCreator>

+(AuthCompletionHandler*) sharedInstance;

/*
// Background refresh (no UI)
// This is commented out because we want people to call the methods that
// return results directly, so that we can mock them for easier development
// - (void) getValidAuth:(AuthCompletionCallback) authCompletionCallback;

// Handle the notification callback to complete the authentication
- (void) handleNotification:(NSNotification*) notification;

// Register callback (either for 
// - (void) registerCallback:(AuthCompletionCallback) authCompletionCallback;

// Get token
- (void) getEmail:(AuthResultCallback)authResultCallback;
- (void) getJWT:(AuthResultCallback)authResultCallback;
- (void) getExpirationDate:(AuthResultCallback)authResultCallback;
- (void) uiSignIn:(AuthResultCallback)authResultCallback;

// Background refresh (no UI)
*/

@end
