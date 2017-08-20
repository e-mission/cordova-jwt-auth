//
//  GoogleSigninAuth.h
//  E-Mission
//
//  Created by Kalyanaraman Shankari on 4/3/14.
//  Copyright (c) 2014 Kalyanaraman Shankari. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AuthTokenCreator.h"

@interface GoogleSigninAuth: NSObject <AuthTokenCreator>

+(GoogleSigninAuth*) sharedInstance;

@end
