//
//  AuthTokenCreationFactory.h
//  emission
//
//  Created by Kalyanaraman Shankari on 8/19/17.
//
//

#import <Foundation/Foundation.h>
#import "AuthTokenCreator.h"

@interface AuthTokenCreationFactory : NSObject

+(id<AuthTokenCreator>) getInstance;

@end
