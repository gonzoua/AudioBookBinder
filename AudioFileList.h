//
//  Copyright (c) 2010-2016 Oleksandr Tymoshenko <gonzo@bluezbox.com>
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
#import "AudioFile.h"
#import "NSOutlineView_Extension.h"

// the name should be the same as properties in AudioFile
#define COLUMNID_NAME           @"name"
#define COLUMNID_FILE           @"file"
#define COLUMNID_AUTHOR         @"artist"
#define COLUMNID_ALBUM          @"album"
#define COLUMNID_TIME           @"duration"

@interface AudioFileList : NSObject<NSOutlineViewDataSource, ExtendedNSOutlineViewDelegate> 

@property (readonly, getter=hasFiles) BOOL hasFiles;
@property BOOL chapterMode;
@property BOOL canPlay;
@property (copy) NSString* commonAuthor;
@property (copy) NSString* commonAlbum;

// class methods
- (id) init;

- (void) addFile:(NSString*)fileName;
- (void) addFilesInDirectory:(NSString*)dirName;
- (NSArray*) files;
- (NSArray*) chapters;
- (void) orphanFile:(AudioFile*)file;
- (void) cleanupChapters;
- (void) switchChapterMode;
- (void) renumberChapters;

- (void) removeAllFiles:(NSOutlineView*)outlineView;

// NSOutlineView data source methods
- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item;
- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item;
- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item;
- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item;

// methods
- (void)delKeyDown:(NSOutlineView *)outlineView;
- (BOOL)deleteSelected:(NSOutlineView *)outlineView;
- (BOOL)joinSelectedFiles:(NSOutlineView *)outlineView;
- (BOOL)splitSelectedFiles: (NSOutlineView*)outlineView;

@end
