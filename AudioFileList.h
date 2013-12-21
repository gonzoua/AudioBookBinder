//
//  AudioFileList.h
//  AudioBookBinder
//
//  Created by Oleksandr Tymoshenko on 10-02-05.
//  Copyright 2010 Bluezbox Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "AudioFile.h"

// the name should be the same as properties in AudioFile
#define COLUMNID_NAME           @"name"
#define COLUMNID_FILE           @"file"
#define COLUMNID_AUTHOR         @"artist"
#define COLUMNID_ALBUM          @"album"
#define COLUMNID_TIME           @"duration"

typedef struct 
{
    NSString *id;
    NSString *title;
    BOOL enabled;
} column_t;

@interface AudioFileList : NSObject<NSOutlineViewDataSource, NSOutlineViewDelegate> {
    NSMutableArray *_files;
    NSMutableArray *_chapters;
    NSString *_topDir;
    NSArray *_draggedNodes;
    BOOL _chapterMode;
    BOOL _sortAscending;
    NSString *_sortKey;
    BOOL _canPlay;
    NSString *_commonAuthor;
    NSString *_commonAlbum;
}

@property (readonly) BOOL hasFiles;
@property BOOL chapterMode;
@property BOOL canPlay;
@property (copy) NSString* commonAuthor;
@property (copy) NSString* commonAlbum;

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
