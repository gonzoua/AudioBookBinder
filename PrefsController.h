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
    NSArray *validBitrates;
    IBOutlet NSPopUpButton * _folderPopUp;
    // HACK ALERT: dublicate all the changes on "save as" panel too 
    IBOutlet NSPopUpButton * _saveAsFolderPopUp;
    
    IBOutlet NSTextField *updateLabel;
    IBOutlet NSButton *updateButton;
}

@property (readwrite, strong) NSArray *validBitrates;

// Prefs panel delegates
- (void) folderSheetShow: (id) sender;

- (void) updateValidBitrates;
- (void) fixupBitrate;
@end
