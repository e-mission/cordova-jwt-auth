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
#import "OpenIDAuth.h"
#import "DummyDevAuth.h"

@implementation AuthTokenCreationFactory

+(id<AuthTokenCreator>) getInstance
{
    ConnectionSettings* settings = [ConnectionSettings sharedInstance];
    if ([settings.authMethod  isEqual: @"google-signin-lib"]) {
        return [GoogleSigninAuth sharedInstance];
    } else if ([settings.authMethod  isEqual: @"openid-authutil"]) {
        return [OpenIDAuth sharedInstance];
    } else if ([settings.authMethod  isEqual: @"dummy-dev"]) {
        return [DummyDevAuth sharedInstance];
    } else {
        // Return dummy dev sign-in handler by default so that:
        // - we know that this will never return null
        // - dev users can start working without any configuration stuff
        return [DummyDevAuth sharedInstance];
    }
}


@end
