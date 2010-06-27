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
- (IBAction) chapterModeWillChange: (id)sender;
- (IBAction) joinFiles: (id)sender;
- (IBAction) splitFiles: (id)sender;
- (IBAction) renumberChapters: (id)sender;

- (void) bindingThreadIsDone: (id) sender;

// AudioBinderDelegate methods
-(void) updateStatus: (AudioFile *)file handled:(UInt64)handledFrames total:(UInt64)totalFrames;
-(void) conversionStart: (AudioFile*)file format: (AudioStreamBasicDescription*)asbd formatDescription: (NSString*)description length: (UInt64)frames;
-(BOOL) continueFailedConversion:(AudioFile*)file reason:(NSString*)reason;
-(void) conversionFinished: (AudioFile*)file duration:(UInt32)milliseconds;
-(void) audiobookReady: (NSString*)filename duration: (UInt32)seconds;
-(void) audiobookFailed:(NSString*)filename reason:(NSString*)reason;

- (void) addFileToiTunes:(NSString *)path;
@end
