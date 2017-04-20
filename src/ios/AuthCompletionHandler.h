//
//  AuthCompletionHandler.h
//  E-Mission
//
//  Created by Kalyanaraman Shankari on 4/3/14.
//  Copyright (c) 2014 Kalyanaraman Shankari. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <GoogleSignIn/GoogleSignIn.h>

typedef void (^AuthCompletionCallback)(GIDGoogleUser *,NSError*);

// static NSString *const kKeychainItemName = @"OAuth: Google Email";
#define kKeychainItemName @"OAuth: Google Email"

@interface AuthCompletionHandler : NSObject<GIDSignInDelegate>

+(AuthCompletionHandler*) sharedInstance;

// Background refresh (no UI)
- (void) getValidAuth:(AuthCompletionCallback) authCompletionCallback;

// Register callback (either for 
- (void) registerCallback:(AuthCompletionCallback) authCompletionCallback;

// Background refresh (no UI)


@end
