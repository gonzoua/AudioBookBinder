//
//  AudioFileList.h
//  AudioBookBinder
//
//  Created by Oleksandr Tymoshenko on 10-02-05.
//  Copyright 2010 Bluezbox Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface AudioFileList : NSObject {
	NSMutableArray *_files;
	NSString *_topDir;
}

// class methods
- (id) init;
- (void) dealloc;

- (void) addFile:(NSString*)fileName;
- (void) addFilesInDirectory:(NSString*)dirName;
- (void) deleteSelected;
- (NSArray*) files;
// NSOutlineView data source methods
- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item;
- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item;
- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item;
- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item;

@end
