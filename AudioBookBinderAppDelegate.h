//
//  AudioBookBinderAppDelegate.h
//  AudioBookBinder
//
//  Created by Oleksandr Tymoshenko on 10-02-04.
//  Copyright 2010 Bluezbox Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "AudioFileList.h"
#import "AudioBinder.h"

@interface AudioBookBinderAppDelegate : NSObject {
    IBOutlet NSWindow *window;
	IBOutlet NSOutlineView *fileListView;
	IBOutlet NSForm *form;
	AudioFileList *fileList;
};

- (IBAction) addFile: (id)sender;
- (IBAction) delFile: (id)sender;
- (IBAction) bind: (id)sender;

@end