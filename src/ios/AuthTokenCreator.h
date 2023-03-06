//
//  AuthTokenCreator.h
//  emission
//
//  Created by Kalyanaraman Shankari on 8/19/17.
//
//  Standard protocol that various auth implementations will implement
//

#import <Foundation/Foundation.h>
#import <Cordova/CDV.h>
typedef void (^AuthResultCallback)(NSString *,NSError*);

@protocol AuthTokenCreator <NSObject>
// Get token
- (void) getOPCode:(AuthResultCallback)authResultCallback;
- (void) getJWT:(AuthResultCallback)authResultCallback;
- (void) setOPCode:(NSString*)opcode;

@end

