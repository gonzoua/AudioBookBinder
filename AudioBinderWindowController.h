//
//  Copyright (c) 2013-2016 Oleksandr Tymoshenko <gonzo@bluezbox.com>
//  All rights reserved.
// 
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions
//  are met:
//  1. Redistributions of source code must retain the above copyright
//     notice unmodified, this list of conditions, and the following
//     disclaimer.
//  2. Redistributions in binary form must reproduce the above copyright
//     notice, this list of conditions and the following disclaimer in the
//     documentation and/or other materials provided with the distribution.
// 
//  THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
//  ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
//  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
//  ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
//  FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
//  DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
//  OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
//  HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
//  LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
//  OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
//  SUCH DAMAGE.
//

#import <Cocoa/Cocoa.h>

#import "AudioFileList.h"
#import "AudioBinder.h"
#import "CoverImageView.h"

@interface AudioBinderWindowController : NSWindowController<NSSoundDelegate, NSTextFieldDelegate, AudioBinderDelegate> {
    IBOutlet NSOutlineView *fileListView;
    IBOutlet NSButton *bindButton;
    IBOutlet NSProgressIndicator *fileProgress;
    IBOutlet NSPanel *progressPanel;
    IBOutlet NSTextField *currentFile;
    IBOutlet NSTabView *tabs;
    IBOutlet CoverImageView *coverImageView;
    IBOutlet NSButton *playButton;
    IBOutlet NSTextField *authorField;
    IBOutlet NSTextField *titleField;
    IBOutlet NSPopUpButton *genresButton;
    IBOutlet NSTextField *genresField;
    IBOutlet NSPanel *saveAsPanel;
    IBOutlet NSTextField *saveAsFilename;
    IBOutlet NSPopUpButton *saveAsFolderPopUp;
}

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
- (IBAction) playStop: (id)sender;
- (IBAction) saveAsOk:(id)sender;
- (IBAction) saveAsCancel:(id)sender;
- (IBAction) folderSheetShow: (id) sender;

- (void)updateWindowTitle;

@end
