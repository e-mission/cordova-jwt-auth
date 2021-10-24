//
//  OpenIDAuth.m
//  emission
//
//  Created by Andrew Tan
//
//

#import "OpenIDAuth.h"
@import AppAuth;
@import JWT;
#import <Cordova/CDV.h>
#import "BEMConnectionSettings.h"
#import "LocalNotificationManager.h"

#define STORAGE_KEY @"openid-auth"

@interface OpenIDAuth ()
@property (atomic, copy) AuthResultCallback mResultCallback;
/*! @brief The authorization state. This is the AppAuth object that you should keep around and
 serialize to disk.
 */
@property(nonatomic, nullable) OIDAuthState *_authState;
@property (nonatomic, strong, nullable) id<OIDExternalUserAgentSession> currentAuthorizationFlow;
@property (atomic, retain) CDVPlugin* mPlugin;

/*! @brief The OIDC issuer from which the configuration will be discovered.
 */
@property NSString *kIssuer;

/*! @brief The OAuth client ID.
 @discussion For client configuration instructions, see the README.
 Set to nil to use dynamic registration with this example.
 @see https://github.com/openid/AppAuth-iOS/blob/master/Examples/Example-iOS_ObjC/README.md
 */
@property NSString *kClientID;

/*! @brief The OAuth redirect URI for the client @c kClientID.
 @discussion For client configuration instructions, see the README.
 @see https://github.com/openid/AppAuth-iOS/blob/master/Examples/Example-iOS_ObjC/README.md
 */
@property NSString *kRedirectURI;
@end

@implementation OpenIDAuth

static OpenIDAuth *sharedInstance;


+(OpenIDAuth*) sharedInstance {
    if (sharedInstance == nil) {
        NSLog(@"creating new OpenIDAuth sharedInstance");
        OpenIDAuth *newAuth = [OpenIDAuth new];
        newAuth.kIssuer = [[ConnectionSettings sharedInstance] authValueForKey:@"discoveryURI"];
        newAuth.kClientID = [[ConnectionSettings sharedInstance] authValueForKey:@"clientID"];
        newAuth.kRedirectURI = @"emission.auth://oauth2redirect";
        [newAuth loadState];

        sharedInstance = newAuth;
    }
    return sharedInstance;
}

/*! @brief Saves the @c OIDAuthState to @c NSUSerDefaults.
 */
- (void)saveState {
    NSData *serializedAuthState = [NSKeyedArchiver archivedDataWithRootObject:[self getAuthState]];
    [[NSUserDefaults standardUserDefaults] setObject:serializedAuthState forKey:STORAGE_KEY];
}

/*! @brief Loads the @c OIDAuthState from @c NSUSerDefaults.
 */
- (void)loadState {
    // loads OIDAuthState from storage
    NSData *serializedAuthState = [[NSUserDefaults standardUserDefaults] objectForKey:STORAGE_KEY];
    OIDAuthState *authState = [NSKeyedUnarchiver unarchiveObjectWithData:serializedAuthState];
    [self setAuthState:authState];
}

- (void)setAuthState:(nullable OIDAuthState *)authState {
    if (self._authState == authState) {
        return;
    }
    self._authState = authState;
    [self saveState];
}

- (nullable OIDAuthState *)getAuthState {
    return self._authState;
}

-(void)handleNotification:(NSNotification *)notification
{
    // For compatibility with iOS 10 and earlier
    NSURL* url = [notification object];
    if ([url.scheme isEqualToString:@"emission.auth"]) {
        if([self.currentAuthorizationFlow resumeExternalUserAgentFlowWithURL:url]) {
            self.currentAuthorizationFlow = nil;
        } else {
            [LocalNotificationManager addNotification:[NSString stringWithFormat:@"[iOS Auth] Resuming authorization flow failed with redirect URL: %@", url]];
        }
    }
}

- (NSString*) getStoredUsername
{
    return [[NSUserDefaults standardUserDefaults] objectForKey:STORAGE_KEY];
}

- (void) getEmail:(AuthResultCallback) authResultCallback
{
    if ([self getAuthState] == nil) {
        [self logMessage:@"Error retrieving auth state: it is empty"];
        return;
    }

    [[self getAuthState] performActionWithFreshTokens:^(NSString *_Nonnull accessToken,
                                                    NSString *_Nonnull idToken,
                                                    NSError *_Nullable error) {
        if (error) {
            [self logMessage:@"Error fetching fresh tokens: %@", [error localizedDescription]];
            authResultCallback(NULL, error);
            return;
        }

        // get user email. we can skip the jwt verification because it is already verified in AppAuth library
        NSNumber *decodeForced = @(YES);
        NSDictionary *payload = [JWTBuilder decodeMessage:idToken].options(decodeForced).decode;

        authResultCallback(payload[@"payload"][@"email"], NULL);
    }];
}

- (void) getJWT:(AuthResultCallback) authResultCallback
{
    if ([self getAuthState] == nil) {
        [self logMessage:@"Error retrieving auth state: it is empty"];
        return;
    }

    [[self getAuthState] performActionWithFreshTokens:^(NSString *_Nonnull accessToken,
                                               NSString *_Nonnull idToken,
                                               NSError *_Nullable error) {
        if (error) {
            [self logMessage:@"Error fetching fresh tokens: %@", [error localizedDescription]];
            authResultCallback(NULL, error);
            return;
        }

        // get access token
        authResultCallback(idToken, NULL);
    }];
}

- (void) getExpirationDate:(AuthResultCallback) authResultCallback
{
    // The library will automatically refereshs token when expired, so it 'never' expires
    authResultCallback(@"never", NULL);
}

- (void) uiSignIn:(AuthResultCallback)authResultCallback withPlugin:(CDVPlugin *)plugin
{
    self.mPlugin = plugin;

    // discovers endpoints
    NSURL *issuer = [NSURL URLWithString:self.kIssuer];
    [OIDAuthorizationService discoverServiceConfigurationForIssuer:issuer
                                                        completion:^(OIDServiceConfiguration *_Nullable configuration, NSError *_Nullable error) {
                                                            if (!configuration) {
                                                                [self logMessage:@"Error retrieving discovery document: %@", [error localizedDescription]];
                                                                [self setAuthState:nil];
                                                                return;
                                                            }

                                                            if (self.kClientID) {
                                                                [self doAuthWithAutoCodeExchange:configuration clientID:self.kClientID clientSecret:nil authResultCallback:authResultCallback];
                                                            } else {
                                                                [self logMessage:@"Error Client ID: %@", self.kClientID];
                                                            }
                                                        }];
}

- (void)doAuthWithAutoCodeExchange:(OIDServiceConfiguration *)configuration
                          clientID:(NSString *)clientID
                      clientSecret:(NSString *)clientSecret
                authResultCallback:(AuthResultCallback)authResultCallback {
    NSURL *redirectURI = [NSURL URLWithString:self.kRedirectURI];
    // builds authentication request
    OIDAuthorizationRequest *request =
    [[OIDAuthorizationRequest alloc] initWithConfiguration:configuration
                                                  clientId:clientID
                                              clientSecret:clientSecret
                                                    scopes:@[ OIDScopeOpenID, OIDScopeProfile, OIDScopeEmail, @"offline_access" ]
                                               redirectURL:redirectURI
                                              responseType:OIDResponseTypeCode
                                      additionalParameters:nil];
    // performs authentication request
    [self logMessage:@"Initiating authorization request with scope: %@", request.scope];

    self.currentAuthorizationFlow =
    [OIDAuthState authStateByPresentingAuthorizationRequest:request
                                   presentingViewController:self.mPlugin.viewController
                                                   callback:^(OIDAuthState *_Nullable authState, NSError *_Nullable error) {
                                                       if (authState) {
                                                           [self setAuthState:authState];
                                                           [self logMessage:@"Got authorization tokens. Access token: %@",
                                                            authState.lastTokenResponse.accessToken];
                                                           [self getEmail:authResultCallback];
                                                       } else {
                                                           [self logMessage:@"Authorization error: %@", [error localizedDescription]];
                                                           [self setAuthState:nil];
                                                           authResultCallback(nil, error);
                                                       }
                                                   }];
}

/*! @brief Logs a message to stdout and the textfield.
 @param format The format string and arguments.
 */
- (void)logMessage:(NSString *)format, ... NS_FORMAT_FUNCTION(1,2) {
    // gets message as string
    va_list argp;
    va_start(argp, format);
    NSString *log = [[NSString alloc] initWithFormat:format arguments:argp];
    va_end(argp);

    // generate date string
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateFormat = @"hh:mm:ss";
    NSString *dateString = [dateFormatter stringFromDate:[NSDate date]];

    // Output to logger
    [LocalNotificationManager addNotification:[NSString stringWithFormat:@"[iOS Auth] %@: %@", dateString, log]];
}

@end
