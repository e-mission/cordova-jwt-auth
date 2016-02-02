//
//  AuthCompletionHandler.h
//  E-Mission
//
//  Created by Kalyanaraman Shankari on 4/3/14.
//  Copyright (c) 2014 Kalyanaraman Shankari. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <GoogleOpenSource/GoogleOpenSource.h>

typedef void (^AuthCompletionCallback)(GTMOAuth2Authentication *,NSError*);

@protocol AuthCompletionDelegate
// The authorization has finished and is successful if |error| is |nil|.
- (void)finishedWithAuth:(GTMOAuth2Authentication *)auth
                   error:(NSError *)error
         usingController:(UIViewController *)viewController;
// Finished disconnecting user from the app.
// The operation was successful if |error| is |nil|.
@optional
- (void)didDisconnectWithError:(NSError *)error;

@end

// static NSString *const kKeychainItemName = @"OAuth: Google Email";
#define kKeychainItemName @"OAuth: Google Email"

@interface AuthCompletionHandler : NSObject<AuthCompletionDelegate>

@property GTMOAuth2Authentication* currAuth;
@property NSMutableArray* errorArray;
@property(nonatomic, copy) NSString* scope;
@property(nonatomic, copy) NSString* clientId;
@property(nonatomic, copy) NSString* clientSecret;

+(AuthCompletionHandler*) sharedInstance;
+ (GTMOAuth2Authentication*) createFakeAuth:(NSString*) userEmail;

/*
 * Note: The objects registered using these callbacks are only invoked
 * when the user signs in via the UI. These are not used for automatic
 * background renewal. In other words, they are invoked from the signIn method
 * but not the getJWT method.
 */

-(void)registerFinishDelegate:(id<AuthCompletionDelegate>) delegate;
-(void)unregisterFinishDelegate:(id<AuthCompletionDelegate>) delegate;

-(BOOL)trySilentAuthentication;
-(UIViewController*)getSigninController;
-(void)signOut;

- (NSString*)getIdToken;
- (void) getValidAuth:(AuthCompletionCallback) authCompletionCallback;

- (void)viewController:(UIViewController *)viewController
      finishedWithAuth:(GTMOAuth2Authentication *)auth
                 error:(NSError *)error;


/*
 * Both the refresh token methods will call all registered listeners with the new token
 */


/*
-(bool)isTokenExpired;

-(void)refreshToken;
-(void)refreshTokenIfExpired;
*/

@end
