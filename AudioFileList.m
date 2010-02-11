//
//  AudioFileList.m
//  AudioBookBinder
//
//  Created by Oleksandr Tymoshenko on 10-02-05.
//  Copyright 2010 Bluezbox Software. All rights reserved.
//

#import "AudioFileList.h"
#import "AudioFile.h"

// It is best to #define strings to avoid making typing errors
#define COLUMNID_NAME               @"NameColumn"
#define COLUMNID_DURATION			@"DurationColumn"

@implementation AudioFileList

- (id) init
{
	if (self = [super init]) 
	{
		_files = [[[NSMutableArray alloc] init] retain];
		_topDir = nil;
	}
	return self;
}

- (void) dealloc
{
	[_files release];
	[_topDir release];
	[super dealloc];
}

- (void) addFile:(NSString*)fileName
{
	AudioFile *file = [[AudioFile alloc] initWithPath:fileName];
	
	if ([file isValid]) {
		[_files addObject:file];
		// kee track of most common directory for file list
#if 0		
		NSString *fileDirectory = [fileName stringByDeletingLastPathComponent];

		if (_topDir == nil)
		{
			_topDir = [[NSString stringWithString:fileDirectory] retain];
		}
		else
		{
			NSArray *a1 = [_topDir pathComponents];
			NSArray *a2 = [fileDirectory pathComponents];
			NSMutableArray *result = [[[NSMutableArray alloc] init] retain];
			int i, common = 0;
			
			for (i = 0; i < MIN([a1 count], [a2 count]); i++)
			{
				if ([[a1 objectAtIndex:i] isEqualToString:[a2 objectAtIndex:i]])
					common++;
			}
			
			if ((common > 0) && (common != [a1 count]))
			{
				NSRange newRange;
				newRange.location = 0;
				newRange.length = common;

				[_topDir release];
				_topDir = [[[a1 subarrayWithRange:newRange] componentsJoinedByString:@"/"] retain];
			}
			else if (common == 0)
			
			[a1 release];
			[a2 release];
		}
#endif
		
	}
	else
		[file release];
}

- (NSArray*) files
{
	NSArray *result = [[NSArray arrayWithArray:_files] retain];
	return result;
}

- (void) addFilesInDirectory:(NSString*)dirName
{
	NSString *currentFile;
	NSDirectoryEnumerator *dirEnum = [[NSFileManager defaultManager] enumeratorAtPath:dirName];
	while ((currentFile = [dirEnum nextObject]))
	{
		NSLog(@"-> %@", currentFile);
		NSString *currentPath = [dirName stringByAppendingPathComponent:currentFile];
		[self addFile:currentPath];
	}
}

- (void) deleteSelected
{
}

// The NSOutlineView uses 'nil' to indicate the root item. We return our root tree node for that case.
- (NSArray *)childrenForItem:(id)item {
    if (item == nil) {
		return _files;
    }
	
	return nil;
}

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{

	return [_files count];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
	return FALSE;
}

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item
{

	if (item == nil)
		return [_files objectAtIndex:index];
	
	return nil;
}

- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
	id objectValue = nil;

	if (item != nil)
	{
		AudioFile *file = item;

		if ([tableColumn.identifier isEqualToString:COLUMNID_NAME])
			objectValue = file.name;
		else {
			int hours = file.duration / 3600;
			int minutes = (file.duration - (hours * 3600)) / 60;
			int seconds = file.duration % 60;
			
			if (hours > 3600)
				objectValue = [[NSString stringWithFormat:@"%d:%02d:%02d",
								hours, minutes, seconds] retain];
			else
				objectValue = [[NSString stringWithFormat:@"%d:%02d",
								minutes, seconds] retain];
		}
	}
	
	return objectValue;
}

// We can return a different cell for each row, if we want
- (NSCell *)outlineView:(NSOutlineView *)ov 
 dataCellForTableColumn:(NSTableColumn *)tableColumn 
				   item:(id)item 
{
    // If we return a cell for the 'nil' tableColumn, it will be used 
	// as a "full width" cell and span all the columns
    return [tableColumn dataCell];
}

@end
