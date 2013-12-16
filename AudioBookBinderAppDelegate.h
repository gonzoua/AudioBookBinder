//
//  AudioBookBinderAppDelegate.h
//  AudioBookBinder
//
//  Created by Oleksandr Tymoshenko on 10-02-04.
//  Copyright 2010 Bluezbox Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#ifndef APP_STORE_BUILD
@class SUUpdater;
#endif

@interface AudioBookBinderAppDelegate : NSObject {
    IBOutlet NSMenu *applicationMenu;

#ifndef APP_STORE_BUILD
    IBOutlet SUUpdater *updater;
#endif
    
    NSImage *_appIcon;
};


+ (void) initialize;

- (IBAction) openChaptersHowTo: (id)sender;
- (IBAction) newAudiobookWindow: (id)sender;



#ifndef APP_STORE_BUILD
- (IBAction) checkForUpdates: (id)sender;
#endif

- (void)updateTotalProgress;
- (void)resetTotalProgress;


@end
