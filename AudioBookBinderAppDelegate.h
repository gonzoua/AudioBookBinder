//
//  AudioBookBinderAppDelegate.h
//  AudioBookBinder
//
//  Created by Oleksandr Tymoshenko on 10-02-04.
//  Copyright 2010 Bluezbox Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Foundation/Foundation.h>
#import "AudioFileList.h"
#import "AudioBinder.h"
#import "CoverImageView.h"
#import <AppKit/NSSound.h>

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
    IBOutlet NSButton *playButton;
    BOOL _playing;
    NSString *outFile;
    AudioBinder *_binder;
    NSArray *validBitrates;
    NSSound *_sound;
    NSString *_playingFile;
    NSImage *_playImg, *_stopImg;
    BOOL canPlay;
};

@property (readwrite, retain) NSArray *validBitrates;
@property (readwrite, assign) BOOL canPlay;
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
- (IBAction) updateValidBitrates: (id)sender;
- (IBAction) playStop: (id)sender;
- (IBAction) openChaptersHowTo: (id)sender;

- (void) bindingThreadIsDone: (id) sender;
- (void) fixupBitrate;

- (BOOL) windowShouldClose:(NSNotification *)notification;
- (void) addFileToiTunes:(NSString *)path;

- (void) playFailed;
// NSSoundDelegate methods
- (void)sound:(NSSound *)sound didFinishPlaying:(BOOL)finishedPlaying;

@end
