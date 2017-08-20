//
//  AuthTokenCreationFactory.m
//  emission
//
//  Created by Kalyanaraman Shankari on 8/19/17.
//
//

#import "AuthTokenCreationFactory.h"
#import "BEMConnectionSettings.h"
#import "GoogleSigninAuth.h"

@implementation AuthTokenCreationFactory

+(id<AuthTokenCreator>) getInstance
{
    ConnectionSettings* settings = [ConnectionSettings sharedInstance];
    if ([settings.authMethod  isEqual: @"google-signin-lib"]) {
        return [GoogleSigninAuth sharedInstance];
    } else {
        // Return google sign-in handler by default so that we know that
        // this will never return null
        return [GoogleSigninAuth sharedInstance];
    }
}


@end
