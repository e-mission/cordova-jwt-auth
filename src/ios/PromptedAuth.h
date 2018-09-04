//
//  DummyDevAuth.h
//  emission
//
//  Created by Kalyanaraman Shankari on 8/20/17.
//
//

#import <Foundation/Foundation.h>
#import "AuthTokenCreator.h"

@interface PromptedAuth : NSObject <AuthTokenCreator>
+ (PromptedAuth*) sharedInstance;
@end
