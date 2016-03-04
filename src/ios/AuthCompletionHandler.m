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
#import "SkipAuthEmailViewController.h"
#import "GTMOAuth2ViewControllerTouch.h"
#import "GTMOAuth2SignIn.h"
#import "BEMConstants.h"
#import "LocalNotificationManager.h"

static inline NSString* NSStringFromBOOL(BOOL aBool) {
    return aBool? @"YES" : @"NO";
}

@interface AuthCompletionHandler() {
    NSMutableArray* listeners;
}
@end

@implementation AuthCompletionHandler
static AuthCompletionHandler *sharedInstance;

-(id)init{
    listeners = [NSMutableArray new];
    return [super init];
}

+ (AuthCompletionHandler*)sharedInstance
{
    if (sharedInstance == nil) {
        NSLog(@"creating new AuthCompletionHandler sharedInstance");
        sharedInstance = [AuthCompletionHandler new];
    }
    return sharedInstance;
}

// BEGIN: UI-based sign in methods

/*
 * Note: The objects registered using these callbacks are only invoked
 * when the user signs in via the UI. These are not used for automatic
 * background renewal. In other words, they are invoked from the signIn method
 * but not the getJWT method.
 */

- (void)registerFinishDelegate:(id<AuthCompletionDelegate>) delegate {
    @synchronized(sharedInstance) {
        NSLog(@"About to add delegate, nListeners = %lu", (unsigned long)sharedInstance->listeners.count);
        [sharedInstance->listeners addObject:delegate];
        NSLog(@"After adding delegate, nListeners = %lu", (unsigned long)sharedInstance->listeners.count);
    }
    
}

- (void)unregisterFinishDelegate:(id<AuthCompletionDelegate>) delegate {
    @synchronized(sharedInstance) {
        [sharedInstance->listeners removeObject:delegate];
    }
}

- (void)finishedWithAuth:(GTMOAuth2Authentication *)auth
                   error:(NSError *)error
         usingController:(UIViewController *)viewController {
    // TODO: Improve this by caching copy of the listeners, so that the finishedWithAuth
    // calls, which can involve a remote call, can happen in parallel
    // This is would be a performance optimization
    NSLog(@"AuthCompletionHandler.finishedWithAuth called, nListeners = %lu", (unsigned long)listeners.count);
    @synchronized(self) {
        for (int i = 0; i < listeners.count; i++) {
            NSLog(@"AuthCompletionHandler.finishedWithAuth notifying listener %d", i);
            [listeners[i] finishedWithAuth:auth error:error usingController:viewController];
        }
    }
}

-(UIViewController*)getSigninController {
    if ([[ConnectionSettings sharedInstance] isSkipAuth]) {
        // Display a simple view where you can enter the email address
        SkipAuthEmailViewController* controller = [[SkipAuthEmailViewController alloc] initWithNibName:nil bundle:nil];
        return controller;
    }
    // Display the autentication view.
    SEL finishedSel = @selector(viewController:finishedWithAuth:error:);
    
    GTMOAuth2ViewControllerTouch *viewController;
    viewController.signIn.shouldFetchGoogleUserEmail = YES;
    viewController.signIn.shouldFetchGoogleUserProfile = NO;
    
    viewController = [GTMOAuth2ViewControllerTouch controllerWithScope:self.scope
                                                              clientID:self.clientId
                                                          clientSecret:self.clientSecret
                                                      keychainItemName:kKeychainItemName
                                                              delegate:self
                                                      finishedSelector:finishedSel];
    return viewController;
}

- (void)viewController:(GTMOAuth2ViewControllerTouch *)viewController
      finishedWithAuth:(GTMOAuth2Authentication *)auth
                 error:(NSError *)error {
    if (error != nil) {
        // Authentication failed (perhaps the user denied access, or closed the
        // window before granting access)
        NSLog(@"Authentication error: %@", error);
        NSData *responseData = [[error userInfo] objectForKey:@"data"]; // kGTMHTTPFetcherStatusDataKey
        if ([responseData length] > 0) {
            // show the body of the server's authentication failure response
            NSString *str = [[NSString alloc] initWithData:responseData
                                                  encoding:NSUTF8StringEncoding];
            NSLog(@"%@", str);
        }
        
        self.currAuth = nil;
    } else {
        // Authentication succeeded
        //
        // At this point, we either use the authentication object to explicitly
        // authorize requests, like
        //
        //  [auth authorizeRequest:myNSURLMutableRequest
        //       completionHandler:^(NSError *error) {
        //         if (error == nil) {
        //           // request here has been authorized
        //         }
        //       }];
        //
        // or store the authentication object into a fetcher or a Google API service
        // object like
        ///
        //   [fetcher setAuthorizer:auth];
        
        // save the authentication object
        self.currAuth = auth;
    }
    
    [self finishedWithAuth:auth error:error usingController:viewController];
}

// END: UI-based sign in methods

// BEGIN: Silent auth methods

/*
 * Read the current auth from the keychain. You can
 */

- (void) populateCurrAuth {
    if (self.currAuth == NULL) {
        [LocalNotificationManager addNotification:[NSString stringWithFormat:
                                                   @"currAuth = null, reading the current value from the keychain"]];

        GTMOAuth2Authentication* tempAuth = [GTMOAuth2ViewControllerTouch authForGoogleFromKeychainForName:kKeychainItemName
                                                                                                  clientID:self.clientId
                                                                                              clientSecret:self.clientSecret];
        @synchronized(self.currAuth) {
            self.currAuth = tempAuth;
        }
        } else {
        [LocalNotificationManager addNotification:[NSString stringWithFormat:
                                                   @"currAuth != null, nothing to do"]];
    }
}

- (void) refreshToken:(AuthCompletionCallback) authCompletionCallback {
    assert(self.currAuth != NULL);
    GTMOAuth2Authentication* oldAuth = self.currAuth;
    [LocalNotificationManager addNotification:[NSString stringWithFormat:
                                               @"beginning refresh of token expiring at %@", oldAuth.expirationDate] showUI:FALSE];
    [oldAuth authorizeRequest:NULL completionHandler:^(NSError *error) {
        GTMOAuth2Authentication* newAuth = self.currAuth;
                    if (error != NULL) {
            [LocalNotificationManager addNotification:[NSString stringWithFormat:
                                                       @"Error %@ while refreshing token, need to retry", error] showUI:TRUE];
                        // modify some kind of error count and notify that user needs to sign in again
                        authCompletionCallback(NULL, error);
                    } else {
            [LocalNotificationManager addNotification:[NSString stringWithFormat:
                                                       @"Refresh completion block called, refreshed token expires at %@", newAuth.expirationDate] showUI:FALSE];
            BOOL stillExpired = ([newAuth.expirationDate compare:[NSDate date]] == NSOrderedAscending);
                        if (stillExpired) {
                            // Although we called refresh, the token is still expired. Let's try to call a different
                            // refresh method
                [LocalNotificationManager addNotification:[NSString stringWithFormat:
                                                           @"Auth token %@ still expired after first refresh attempt (expiry date = %@, now = %@), notifying user",
                                                           newAuth, newAuth.expirationDate, [NSDate date]] showUI:TRUE];
                            NSDictionary *userInfo = @{
                                           NSLocalizedDescriptionKey: NSLocalizedString(@"Refresh token still expired", nil),
                                                       NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"Unknown.", nil),
                                                       NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"Sign out and Sign in again.", nil)
                                                       };
                            // TODO: Make a domain and error class
                            NSError *refreshError = [NSError errorWithDomain:errorDomain code:authFailedNeedUserInput userInfo:userInfo];
                            authCompletionCallback(NULL, refreshError);
                        } else {
                [LocalNotificationManager addNotification:[NSString stringWithFormat:
                                                           @"Refresh is really done, returning refreshed token"] showUI:FALSE];
                authCompletionCallback(newAuth, NULL);
            } // end: stillExpired
        } // end: error != NULL
    }]; // end completion block
} // end: method

/*
 * Returns a valid auth, including refreshing the access token if necessary.
 * Does not present the sign in screen to the user again, but returns an error
 * that the client can use to show the sign in screen.
 */

- (void) getValidAuth:(AuthCompletionCallback) authCompletionCallback forceRefresh:(BOOL)forceRefresh {
    [self populateCurrAuth];
    assert(self.currAuth != NULL);

    // Let's make a local copy that we can muck with until we are ready to save it back
    GTMOAuth2Authentication* currAuth = self.currAuth;
   
    if (currAuth.canAuthorize == NO) {
        // The current JWT does not have an access token or a refresh token, need to have the user sign in again.
        [LocalNotificationManager addNotification:[NSString stringWithFormat:
                                                   @"currAuth.canAuthorize = NO, accessToken = %@, refreshToken = %@, user needs to sign in again", currAuth.accessToken, currAuth.refreshToken] showUI:TRUE];
        NSDictionary *userInfo = @{
                                   NSLocalizedDescriptionKey: NSLocalizedString(@"currAuth.canAuthorize = NO", nil),
                                   NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"currAuth.canAuthorize = NO", nil),
                                   NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"Need to login and authorize access to email address.", nil)
                                   };
        // TODO: Make a domain and error class
        NSError *authError = [NSError errorWithDomain:errorDomain code:authFailedNeedUserInput userInfo:userInfo];
        authCompletionCallback(NULL, authError);
    } else {
        [self checkAndRefreshToken:currAuth completionHandler:authCompletionCallback
                      forceRefresh:forceRefresh];
    }
}

- (void) checkAndRefreshToken:(GTMOAuth2Authentication*)currAuth completionHandler:(AuthCompletionCallback)authCompletionCallback forceRefresh:(BOOL)forceRefresh {

    assert(currAuth.canAuthorize == YES);
    BOOL expired = ([currAuth.expirationDate compare:[NSDate date]] == NSOrderedAscending);
    // The access token may not have expired, but the id token may not be available because the app has been restarted,
    // so it is not in memory, and the ID token is not stored in the keychain. It is a real pain to store the ID token
    // in the keychain through subclassing, so let's just try to refresh the token anyway
    expired = expired || ([AuthCompletionHandler sharedInstance].getIdToken == NULL);
    [LocalNotificationManager addNotification:[NSString stringWithFormat:
                                               @"currAuth = %@, canAuthorize = %@, expiresIn = %@, expirationDate = %@, expired = %@",
                                               currAuth, NSStringFromBOOL(currAuth.canAuthorize), currAuth.expiresIn, currAuth.expirationDate,
                                               NSStringFromBOOL(expired)] showUI:FALSE];
    if (expired == YES) {
        [LocalNotificationManager addNotification:[NSString stringWithFormat:
                                                   @"token has expired, refreshing it"] showUI:FALSE];
        [self refreshToken:authCompletionCallback];
        } else {
        if (forceRefresh == YES) {
            [LocalNotificationManager addNotification:[NSString stringWithFormat:
                                                       @"forceRefresh has been requested, refreshing token"] showUI:FALSE];
            [self refreshToken:authCompletionCallback];
}
        [LocalNotificationManager addNotification:[NSString stringWithFormat:
                                                   @"token is valid, returning it"] showUI:FALSE];
        authCompletionCallback(currAuth, NULL);
    }
}

// END: Silent auth methods

- (void)signOut {
    if ([self.currAuth.serviceProvider isEqual:kGTMOAuth2ServiceProviderGoogle]) {
        // remove the token from Google's servers
        [GTMOAuth2ViewControllerTouch revokeTokenForGoogleAuthentication:self.currAuth];
    }
    
    // remove the stored Google authentication from the keychain, if any
    [GTMOAuth2ViewControllerTouch removeAuthFromKeychainForName:kKeychainItemName];
    
    // remove the stored DailyMotion authentication from the keychain, if any
    [GTMOAuth2ViewControllerTouch removeAuthFromKeychainForName:kKeychainItemName];
    
    // Discard our retained authentication object.
    self.currAuth = nil;
}

+ (GTMOAuth2Authentication*) createFakeAuth:(NSString*) userEmail {
    GTMOAuth2Authentication* retAuth = [[GTMOAuth2Authentication alloc] init];
    retAuth.userEmail = userEmail;
    retAuth.refreshToken = userEmail;
    retAuth.accessToken = userEmail;
    // Make sure that it expires way in the future
    retAuth.expirationDate = [NSDate dateWithTimeIntervalSinceNow:3600 * 365];
    return retAuth;
}

-(NSString*)getIdToken {
    if ([[ConnectionSettings sharedInstance] isSkipAuth]) {
        if (self.currAuth != NULL) {
            return self.currAuth.userEmail;
    }
}
    // else, the real version
    if (self.currAuth != NULL) {
        if (self.currAuth.canAuthorize) {
            return [self.currAuth.parameters valueForKey:@"id_token"];
        }
    }
    return NULL;
}

// END: Silent auth methods

@end
