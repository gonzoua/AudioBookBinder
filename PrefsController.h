//
//  PrefsController.h
//  AudioBookBinder
//
//  Created by Oleksandr Tymoshenko on 10-03-29.
//  Copyright 2010 Bluezbox Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface VolumeLengthTransformer : NSValueTransformer {
}

@end

@interface PrefsController : NSWindowController {
    NSUserDefaults *_userDefaults;
    IBOutlet NSPopUpButton * _folderPopUp;
    
    IBOutlet NSTextField *updateLabel;
    IBOutlet NSButton *updateButton;
}

// Prefs panel delegates
- (void) folderSheetShow: (id) sender;
- (void) folderSheetClosed: (NSOpenPanel *) openPanel returnCode: (int) code contextInfo: (void *) info;
- (void) destinationiTunes: (id) sender;
@end
