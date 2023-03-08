#import <Cordova/CDV.h>

@interface BEMOPCode: CDVPlugin

- (void) getOPCode:(CDVInvokedUrlCommand*)command;
- (void) setOPCode:(CDVInvokedUrlCommand*)command;

@end
