//
//  AudioFileList.h
//  AudioBookBinder
//
//  Created by Oleksandr Tymoshenko on 10-02-05.
//  Copyright 2010 Bluezbox Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "AudioFile.h"

@interface AudioFileList : NSObject {
    NSMutableArray *_files;
    NSMutableArray *_chapters;
    NSString *_topDir;
    NSArray *_draggedNodes;
    BOOL _chapterMode;
    BOOL _canPlay;
}

@property (readonly) BOOL hasFiles;
@property BOOL chapterMode;

// class methods
- (id) init;
- (void) dealloc;

- (void) addFile:(NSString*)fileName;
- (void) addFilesInDirectory:(NSString*)dirName;
- (NSArray*) files;
- (NSArray*) chapters;
- (void) orphanFile:(AudioFile*)file;
- (void) cleanupChapters;
- (void) switchChapterMode;
- (void) renumberChapters;

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
