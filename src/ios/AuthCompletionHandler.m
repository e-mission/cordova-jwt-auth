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
#import <GoogleOpenSource/GoogleOpenSource.h>
#import <GoogleOpenSource/GTMOAuth2ViewControllerTouch.h>

// #define errorDomain @"e-mission-domain"
NSString* const errorDomain = @"e-mission-domain";
NSString* const BackgroundRefreshNewData = @"BackgroundRefreshNewData";
int const authFailedNeedUserInput = -100;

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

- (void)finishedWithAuth:(GTMOAuth2Authentication *)auth error:(NSError *)error {
    // TODO: Improve this by caching copy of the listeners, so that the finishedWithAuth
    // calls, which can involve a remote call, can happen in parallel
    // This is would be a performance optimization
    NSLog(@"AuthCompletionHandler.finishedWithAuth called, nListeners = %lu", (unsigned long)listeners.count);
    @synchronized(self) {
        for (int i = 0; i < listeners.count; i++) {
            NSLog(@"AuthCompletionHandler.finishedWithAuth notifying listener %d", i);
            [listeners[i] finishedWithAuth:auth error:error];
        }
    }
}

/*
 * Returns a valid auth, including refreshing the access token if necessary.
 * Does not present the sign in screen to the user again, but returns an error
 * that the client can use to show the sign in screen.
 */

- (void) getValidAuth:(AuthCompletionCallback) authCompletionCallback {
    // Next, we need to check whether the user is logged in. If not, we need to re-login
    // This will call the finishedWithAuth callback
    GTMOAuth2Authentication* currAuth = self.currAuth;
    if (currAuth == NULL) {
        [self tryToAuthenticate:authCompletionCallback];
    } else {
        BOOL expired = ([currAuth.expirationDate compare:[NSDate date]] == NSOrderedAscending);
        // The access token may not have expired, but the id token may not be available because the app has been restarted,
        // so it is not in memory, and the ID token is not stored in the keychain. It is a real pain to store the ID token
        // in the keychain through subclassing, so let's just try to refresh the token anyway
        expired = expired || ([AuthCompletionHandler sharedInstance].getIdToken == NULL);
        NSLog(@"currAuth = %@, canAuthorize = %@, expiresIn = %@, expirationDate = %@, expired = %@",
              currAuth, NSStringFromBOOL(currAuth.canAuthorize), currAuth.expiresIn, currAuth.expirationDate,
              NSStringFromBOOL(expired));
        if (currAuth.canAuthorize != YES) {
            NSLog(@"Unable to refresh token, trying to re-authenticate");
            // Not sure why we would get canAuthorize be null, but I assume that we re-login in that case
            [self tryToAuthenticate:authCompletionCallback];
        } else {
            if (expired) {
                NSLog(@"Existing auth token expired, refreshing...");
                // Need to refresh the token
                [currAuth authorizeRequest:NULL completionHandler:^(NSError *error) {
                    if (error != NULL) {
                        // modify some kind of error count and notify that user needs to sign in again
                        NSLog(@"Error while refreshing token, need to modify error count");
                        authCompletionCallback(NULL, error);
                    } else {
                        NSLog(@"Refresh completion block called, refreshed token is %@", currAuth);
                        BOOL stillExpired = ([currAuth.expirationDate compare:[NSDate date]] == NSOrderedAscending);
                        if (stillExpired) {
                            // Although we called refresh, the token is still expired. Let's try to call a different
                            // refresh method
                            NSLog(@"Existing auth token still expired after first refresh attempt, trying different attempt...");
                            /*
                            [currAuth authorizeRequest:NULL
                                              delegate:self
                                     didFinishSelector:@selector(finishRefreshSelector:)];
                             */
                            NSDictionary *userInfo = @{
                                                       NSLocalizedDescriptionKey: NSLocalizedString(@"Refresh token still expired.", nil),
                                                       NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"Unknown.", nil),
                                                       NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"Sign out and Sign in again.", nil)
                                                       };
                            // TODO: Make a domain and error class
                            NSError *refreshError = [NSError errorWithDomain:errorDomain code:authFailedNeedUserInput userInfo:userInfo];
                            authCompletionCallback(NULL, refreshError);
                        } else {
                            NSLog(@"Refresh is really done, posting to host");
                            assert(error == NULL);
                            authCompletionCallback(self.currAuth, NULL);
                        }
                    }
                }];
            } else {
                NSLog(@"Existing auth token not expired, posting to host");
                assert(expired == FALSE);
                authCompletionCallback(self.currAuth, NULL);
            }
        }
    }
}

- (void)tryToAuthenticate:(AuthCompletionCallback)authCompletionCallback {
    NSLog(@"tryToAuthenticate called");
    BOOL silentAuthResult = [self trySilentAuthentication];
    if (silentAuthResult == NO) {
        NSLog(@"Need user input for authentication, need to signal user somehow");
        NSDictionary *userInfo = @{
                                   NSLocalizedDescriptionKey: NSLocalizedString(@"User authentication failed.", nil),
                                   NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"User information not available in keychain.", nil),
                                   NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"Need to login and authorize access to email address.", nil)
                                   };
        // TODO: Make a domain and error class
        NSError *authError = [NSError errorWithDomain:errorDomain code:authFailedNeedUserInput userInfo:userInfo];
        authCompletionCallback(NULL, authError);
    } else {
        NSLog(@"callback should be called, we will deal with it there");
        // So far, callback has not taken a long time...
        // But callback may take a long time. In that case, we may want to return early.
        // Also, callback will invoke mCompletionHandler in a separate thread, which won't
        // work because all callbacks have to be in the main thread for this to succeed
        // So we say that we are done here with no data
        // However, in the callback handler, we set the backgroundFetchInterval to 10 mins
        // So we will be called again, and won't have to invoke this call then
        // mCompletionHandler(NULL, NULL, NULL);
    }
}


/*
 * trySilentAuthentication can be called from both the background and UI views. So it will not
 * popup the sign in view automatically. Instead, it will just return false if there is no authentication
 * token stored in the keystore.
 */

- (BOOL)trySilentAuthentication {
    if (self.currAuth == NULL) {
        GTMOAuth2Authentication* tempAuth = [GTMOAuth2ViewControllerTouch authForGoogleFromKeychainForName:kKeychainItemName
                                                                              clientID:self.clientId
                                                                          clientSecret:self.clientSecret];
        if(tempAuth.canAuthorize) {
            self.currAuth = tempAuth;
        } else {
            NSLog(@"Authentication %@ stored in keychain is no longer valid", tempAuth);
        }
    }
    if (self.currAuth.canAuthorize) {
        // We are currently signed in
        return YES;
    }
    
    // We are not currently signed in
    // TODO: Consider folding in the checks for expired tokens and
    return NO;
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
    retAuth.parameters = [[NSMutableDictionary alloc] initWithDictionary:@{@"id_token" : retAuth.userEmail,
                                                                           @"refresh_token" : retAuth.refreshToken,
                                                                           @"access_token" : retAuth.accessToken,
                                                                           @"email": retAuth.userEmail,
                                                                           }];
    return retAuth;
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
    
    [self finishedWithAuth:auth error:error];
}

-(NSString*)getIdToken {
    if (self.currAuth != NULL) {
        if (self.currAuth.canAuthorize) {
            return [self.currAuth.parameters valueForKey:@"id_token"];
        }
    }
    return NULL;
}

@end
