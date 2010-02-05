//
//  AudioBookBinderAppDelegate.h
//  AudioBookBinder
//
//  Created by Oleksandr Tymoshenko on 10-02-04.
//  Copyright 2010 Bluezbox Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

// #if (MAC_OS_X_VERSION_MAX_ALLOWED <= MAC_OS_X_VERSION_10_5)
@interface AudioBookBinderAppDelegate : NSObject {
// #else
// @interface AudioBookBinderAppDelegate : NSObject <NSApplicationDelegate> {
// #endif
    NSWindow *window;
};

- (IBAction) addFile: (id)sender;
- (IBAction) delFile: (id)sender;
- (IBAction) bind: (id)sender;

@end