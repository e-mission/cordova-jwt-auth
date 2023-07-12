//
//  PromptedAuth.m
//  emission
//
//  Created by Kalyanaraman Shankari on 8/20/17.
//
//

#import "PromptedAuth.h"
#import "LocalNotificationManager.h"
#import "BEMConnectionSettings.h"
#import "BEMBuiltinUserCache.h"

#define EXPECTED_METHOD @"prompted-auth"
#define EXPECTED_HOST @"auth"
#define METHOD_PARAM_KEY @"method"
#define TOKEN_PARAM_KEY @"token"
#define STORAGE_KEY @"dev-auth"

@interface PromptedAuth ()
@property (atomic, copy) AuthResultCallback mResultCallback;
@end

@implementation PromptedAuth

static PromptedAuth *sharedInstance;

+(PromptedAuth*) sharedInstance {
    if (sharedInstance == NULL) {
        NSLog(@"creating new PromptedAuth sharedInstance");
        sharedInstance = [PromptedAuth new];
    }
    return sharedInstance;
}

- (NSString*) getStoredUserAuthEntry
{
    NSString* token = NULL;
    NSDictionary* dbStorageObject = [[BuiltinUserCache database] getLocalStorage:EXPECTED_METHOD withMetadata:NO];
    if (dbStorageObject != NULL) {
        [LocalNotificationManager addNotification:
            [NSString stringWithFormat:@"Auth found in local storage, now it should be stable"]];
        token = dbStorageObject[TOKEN_PARAM_KEY];
    }
    return token;
}

- (void) setStoredUserAuthEntry: (NSString*)token
{
    NSDictionary* dbStorageObject = @{TOKEN_PARAM_KEY: token};
    [[BuiltinUserCache database] putLocalStorage:EXPECTED_METHOD jsonValue:dbStorageObject];
}

- (void) getOPCode:(AuthResultCallback) authResultCallback
{
    authResultCallback([self getStoredUserAuthEntry], NULL);
}

- (void) getJWT:(AuthResultCallback) authResultCallback
{
    // For the prompted-auth method, token = username
    authResultCallback([self getStoredUserAuthEntry], NULL);
}

- (void) setOPCode:(NSString*) opcode
{
    [NSException raise:@"Storing opcodes through the plugin is no longer supported since it does not duplicate data"];
}

@end
