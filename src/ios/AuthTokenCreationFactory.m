//
//  AuthTokenCreationFactory.m
//  emission
//
//  Created by Kalyanaraman Shankari on 8/19/17.
//
//

#import "AuthTokenCreationFactory.h"
#import "PromptedAuth.h"

@implementation AuthTokenCreationFactory

+(id<AuthTokenCreator>) getInstance
{
    return [PromptedAuth sharedInstance];
}


@end
