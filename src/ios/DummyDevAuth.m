//
//  DummyDevAuth.m
//  emission
//
//  Created by Kalyanaraman Shankari on 8/20/17.
//
//

#import "DummyDevAuth.h"
#import "LocalNotificationManager.h"

#define EXPECTED_METHOD @"dummy-dev"
#define EXPECTED_HOST @"auth"
#define METHOD_PARAM_KEY @"method"
#define TOKEN_PARAM_KEY @"token"
#define STORAGE_KEY @"dev-auth"

@interface DummyDevAuth ()
@property (atomic, copy) AuthResultCallback mResultCallback;
@end

@implementation DummyDevAuth

static DummyDevAuth *sharedInstance;

+(DummyDevAuth*) sharedInstance {
    if (sharedInstance == NULL) {
        NSLog(@"creating new DummyDevAuth sharedInstance");
        sharedInstance = [DummyDevAuth new];
    }
    return sharedInstance;
}

-(void)handleNotification:(NSNotification *)notification
{
    NSURL* url = [notification object];
    [LocalNotificationManager
        addNotification:[NSString
                        stringWithFormat:@"in handleNotification, received url = %@", url]];
    
    NSURLComponents* urlComp = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
    NSString* feature = [urlComp host];
    [LocalNotificationManager
        addNotification:[NSString stringWithFormat:@"in handleNotification, feature = %@", feature]];
    
    if ([feature isEqualToString:EXPECTED_HOST]) {
        NSArray<NSURLQueryItem*> *queryItems = [urlComp queryItems];
        NSURLQueryItem* methodParam = queryItems[0];
        NSURLQueryItem* tokenParam = queryItems[1];
        
        if (([methodParam.name isEqualToString:METHOD_PARAM_KEY]) && ([methodParam.value isEqualToString:EXPECTED_METHOD])) {
            // For the dummy-dev method name
            if ([tokenParam.name isEqualToString:TOKEN_PARAM_KEY]) {
                NSString* userName = tokenParam.value;
                [LocalNotificationManager addNotification:
                 [NSString stringWithFormat:@"in handleNotification, received userName %@",
                  userName]];
                [[NSUserDefaults standardUserDefaults] setObject:userName forKey:STORAGE_KEY];
                self.mResultCallback(userName, NULL);
            } else {
                [LocalNotificationManager addNotification:
                 [NSString stringWithFormat:@"in handleNotification, tokenParam key = %@, expected %@, ignoring...",
                  tokenParam.name, TOKEN_PARAM_KEY]];
            }
        } else {
            [LocalNotificationManager addNotification:
                [NSString stringWithFormat:@"in handleNotification, methodParam = %@, expected %@, ignoring...",
                    methodParam, @{METHOD_PARAM_KEY: EXPECTED_METHOD}]];
            // TODO: Should I return the callback with an error? It is possible that there are multiple URLs being handled,
            // in which case we should not return prematurely, but wait for _our_ URL to complete. But if we don't look
            // for it, we may be stuck overever.
        }
    } else {
        [LocalNotificationManager addNotification:
            [NSString stringWithFormat:@"in handleNotification, recived URL for feature %@, expected %@, ignoring...",
             feature, @"auth"]];
    }
}

- (NSString*) getStoredUsername
{
    return [[NSUserDefaults standardUserDefaults] objectForKey:STORAGE_KEY];
}

- (void) getEmail:(AuthResultCallback) authResultCallback
{
    authResultCallback([self getStoredUsername], NULL);
}

- (void) getJWT:(AuthResultCallback) authResultCallback
{
    // For the dummy-dev method, token = username
    authResultCallback([self getStoredUsername], NULL);
}

- (void) getExpirationDate:(AuthResultCallback) authResultCallback
{
    authResultCallback(@"never", NULL);
}

- (void) uiSignIn:(AuthResultCallback)authResultCallback withPlugin:(CDVPlugin *)plugin
{
    self.mResultCallback = authResultCallback;
    NSArray<NSString*>* devJSScriptLines = @[@"var email = window.prompt('Dev mode: Enter email', '')",
                                  // @"window.alert('email = '+email)",
                                  @"var callbackURL = 'emission://auth?method=dummy-dev&token='+email",
                                  // @"window.alert('callbackURL = '+callbackURL)",
                                  @"var callbackWindow = cordova.InAppBrowser.open(callbackURL, '_system')",
                                  @"callbackWindow.addEventListener('loadstart', function(event) {var protocol = event.url.substring(0, event.url.indexOf('://')); if (protocol == 'emission') { setTimeout(callbackWindow.close(), 5000);}})",
                                  @"callbackWindow.addEventListener('loaderr', function(event) {alert('Error '+event.message+' loading '+event.url); callbackWindow.close();})"
                                ];
    NSString* devJSScript = [devJSScriptLines componentsJoinedByString:@";\n"];
    [LocalNotificationManager addNotification:@"About to execute script"];
    [LocalNotificationManager addNotification:devJSScript];
    [plugin.commandDelegate evalJs:devJSScript];
    
}

@end
