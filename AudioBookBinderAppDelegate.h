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
#import "CoverImageView.h"

@interface AudioBookBinderAppDelegate : NSObject <AudioBinderDelegate> {
    IBOutlet NSWindow *window;
    IBOutlet NSOutlineView *fileListView;
    IBOutlet NSForm *form;
    IBOutlet NSButton *bindButton;
    IBOutlet NSProgressIndicator *fileProgress;
    IBOutlet NSPanel *progressPanel;
    IBOutlet NSTextField *currentFile;
    IBOutlet NSTabView *tabs;
    IBOutlet AudioFileList *fileList;
    IBOutlet CoverImageView *coverImageView;
    NSString *outFile;
    AudioBinder *_binder;
};

+ (void) initialize;

- (IBAction) addFiles: (id)sender;
- (IBAction) delFiles: (id)sender;
- (IBAction) setCover: (id)sender;
- (IBAction) bind: (id)sender;
- (IBAction) cancel: (id)sender;
- (void) bindingThreadIsDone: (id) sender;

// AudioBinderDelegate methods
-(void) updateStatus: (NSString *)filename handled:(UInt64)handledFrames total:(UInt64)totalFrames;
-(void) conversionStart: (NSString*)filename format: (AudioStreamBasicDescription*)asbd formatDescription: (NSString*)description length: (UInt64)frames;
-(BOOL) continueFailedConversion:(NSString*)filename reason:(NSString*)reason;
-(void) conversionFinished: (NSString*)filename;
-(void) audiobookReady: (NSString*)filename duration: (UInt32)seconds;
-(void) audiobookFailed:(NSString*)filename reason:(NSString*)reason;

- (void) addFileToiTunes:(NSString *)path;
@end
