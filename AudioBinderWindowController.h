//
//  AudioBinderWindowController.h
//  AudioBookBinder
//
//  Created by Oleksandr Tymoshenko on 2013-12-14.
//  Copyright (c) 2013 Bluezbox Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "AudioFileList.h"
#import "AudioBinder.h"
#import "CoverImageView.h"

@interface AudioBinderWindowController : NSWindowController<NSSoundDelegate, NSTextFieldDelegate, AudioBinderDelegate> {
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
    IBOutlet NSPopUpButton *genresButton;
    IBOutlet NSTextField *genresField;
    IBOutlet NSPanel *saveAsPanel;
    IBOutlet NSTextField *saveAsFilename;
    IBOutlet NSPopUpButton *saveAsFolderPopUp;
    
    NSURL *_destURL;
    NSMutableArray *knownGenres;
    BOOL autocompleting;
    BOOL _playing;
    NSString *outFile;
    AudioBinder *_binder;
    NSArray *validBitrates;
    NSSound *_sound;
    NSString *_playingFile;
    NSImage *_playImg, *_stopImg;
    BOOL canPlay;
    NSUInteger currentProgress;
    BOOL _conversionResult;
    
    NSMutableArray *currentColumns;

    NSUInteger _currentFileProgress;
    NSUInteger _totalBookProgress;
    NSUInteger _totalBookDuration;
}

@property (readwrite, retain) NSArray *validBitrates;
@property (readwrite, assign) BOOL canPlay;

@property (atomic, assign) NSUInteger currentProgress;

- (IBAction) addFiles: (id)sender;
- (IBAction) delFiles: (id)sender;
- (IBAction) setCover: (id)sender;
- (IBAction) bind: (id)sender;
- (IBAction) cancel: (id)sender;
- (IBAction) toggleChapters: (id)sender;
- (IBAction) joinFiles: (id)sender;
- (IBAction) splitFiles: (id)sender;
- (IBAction) renumberChapters: (id)sender;
- (IBAction) updateValidBitrates: (id)sender;
- (IBAction) playStop: (id)sender;

- (IBAction) saveAsOk:(id)sender;
- (IBAction) saveAsCancel:(id)sender;
- (IBAction) folderSheetShow: (id) sender;

- (void) playFailed;
- (void)sound:(NSSound *)sound didFinishPlaying:(BOOL)finishedPlaying;

@end
