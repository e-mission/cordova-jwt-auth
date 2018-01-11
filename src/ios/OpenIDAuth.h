//
//  DummyDevAuth.h
//  emission
//
//  Created by Andrew Tan
//
//

#import <Foundation/Foundation.h>
#import "AuthTokenCreator.h"

@class OIDAuthState;
@class OIDServiceConfiguration;

@interface OpenIDAuth : NSObject <AuthTokenCreator>

+(OpenIDAuth*) sharedInstance;

@end
