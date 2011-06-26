//
//  AudioFileList.m
//  AudioBookBinder
//
//  Created by Oleksandr Tymoshenko on 10-02-05.
//  Copyright 2010 Bluezbox Software. All rights reserved.
//

#import "AudioFileList.h"
#import "AudioFile.h"
#include "NSOutlineView_Extension.h"
#import "Chapter.h"
#import "AudioBookBinderAppDelegate.h"

// It is best to #define strings to avoid making typing errors
#define SIMPLE_BPOARD_TYPE           @"MyCustomOutlineViewPboardType"


#define TEXT_CHAPTER  \
    NSLocalizedString(@"Chapter", nil)
#define TEXT_CHAPTER_N  \
    NSLocalizedString(@"Chapter %d", nil)

@implementation AudioFileList

- (id) init
{
    if ((self = [super init])) 
    {
        _files = [[[NSMutableArray alloc] init] retain];
        _chapters = [[[NSMutableArray alloc] init] retain];
        _topDir = nil;
        _chapterMode = YES;
        id modeObj = [[NSUserDefaults standardUserDefaults] objectForKey:@"ChaptersEnabled"];
        if (modeObj != nil)
            _chapterMode = [modeObj boolValue];
        _canPlay = NO;
        _sortAscending = YES;
        _sortKey = nil;
        // create initial chapter if chapters are enabled
        if (_chapterMode) {
            Chapter *newChapter = [[Chapter alloc] init];
            newChapter.name = TEXT_CHAPTER;
            [_chapters removeAllObjects];
            [_chapters addObject:newChapter];
        }
    }
    return self;
}

- (void) dealloc
{
    [_files release];
    [_topDir release];
    [_chapters release];
    [super dealloc];
}

@synthesize chapterMode = _chapterMode;

- (void) addFile:(NSString*)fileName
{
    AudioFile *file = [[AudioFile alloc] initWithPath:fileName];

    [self willChangeValueForKey:@"hasFiles"];
    
    if (file.valid) {
        [_files addObject:file];
        if (_chapterMode) {
            Chapter *chapter = [_chapters lastObject];
            [chapter addFile:file];  
        }
    }
    else
        [file release];
    
    [self didChangeValueForKey:@"hasFiles"];
}

- (NSArray*) chapters
{
    NSArray *result;

    result = [[NSArray arrayWithArray:_chapters] retain];
    
    return result;
}

- (NSArray*) files
{
    NSMutableArray *result;
    if (_chapterMode) {
        result = [[NSMutableArray alloc] init];
        for (Chapter *ch in _chapters)
            [result addObjectsFromArray:[ch files]];
    }
    else {
        result = [[NSArray arrayWithArray:_files] retain];
    }
    
    return result;
}

- (BOOL) hasFiles
{
    if ([_files count] > 0)
        return YES;
    
    return NO;
}

- (void) addFilesInDirectory:(NSString*)dirName
{
    NSString *currentFile;
    NSDirectoryEnumerator *dirEnum = [[NSFileManager defaultManager] enumeratorAtPath:dirName];
    while ((currentFile = [dirEnum nextObject]))
    {
        NSString *currentPath = [dirName stringByAppendingPathComponent:currentFile];
        [self addFile:currentPath];
    }
}

- (void) switchChapterMode
{
    // this function is called before _chapterMode is changed by binding
    if (!_chapterMode) {
        // put all files in one folder
        Chapter *newChapter = [[Chapter alloc] init];
        newChapter.name = TEXT_CHAPTER;
        [_chapters removeAllObjects];
        for (AudioFile *file in _files) {
            [newChapter addFile:file];
        }
        [_chapters addObject:newChapter];
        // change explicitely because we need to update outlineView in new mode
        _chapterMode = YES;

    } else
    {
        // flatten chapter tree
        [_files removeAllObjects];
        for (Chapter *ch in _chapters) {
            for (AudioFile *f in [ch files])
                [_files addObject:f];
        }
        // change explicitely because we need to update outlineView in new mode
        _chapterMode = NO;
    }
    [[NSUserDefaults standardUserDefaults] setBool:_chapterMode forKey:@"ChaptersEnabled"];
}

- (void) renumberChapters
{
    if (_chapterMode) {
        int idx = 1;
        for (Chapter *ch in _chapters) {
            ch.name = [NSString stringWithFormat:TEXT_CHAPTER_N, idx];
            idx++;
        }
    }
}

// The NSOutlineView uses 'nil' to indicate the root item. We return our root tree node for that case.
- (NSArray *)childrenForItem:(id)item {
    if (item == nil) {
        if (_chapterMode)
            return _chapters;
        else
            return _files;
    }
    else {
        if ([item isKindOfClass:[Chapter class]]) {
            return [(Chapter*)item files];
        }
    }
    return nil;
}

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{
    if (item == nil) {
        if (_chapterMode)
            return [_chapters count];
        else
            return [_files count];
    }
    else {
        if ([item isKindOfClass:[Chapter class]])
            return [item totalFiles];
    }
    
    return 0;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
    if ([item isKindOfClass:[Chapter class]])
        return YES;
    else
        return NO;
}

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item
{

    if (item == nil) {
        if (_chapterMode)
            return [_chapters objectAtIndex:index];
        else
            return [_files objectAtIndex:index];
    }
    
    if ([item isKindOfClass:[Chapter class]])
        return [item fileAtIndex:index];
    
    return nil;
}

- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
    id objectValue = nil;
    if (item == nil)
        return nil;
    
    if ([item isKindOfClass:[AudioFile class]])
    {
        AudioFile *file = item;

        if ([tableColumn.identifier isEqualToString:COLUMNID_FILE])
            objectValue = file.file;
        else if ([tableColumn.identifier isEqualToString:COLUMNID_NAME])
            objectValue = file.name;
        else if ([tableColumn.identifier isEqualToString:COLUMNID_AUTHOR])
            objectValue = file.artist;
        else if ([tableColumn.identifier isEqualToString:COLUMNID_ALBUM])
            objectValue = file.album;
        else if ([tableColumn.identifier isEqualToString:COLUMNID_TIME])
        {
            UInt32 duration = [file.duration intValue];
            duration /= 1000;
            int hours = duration / 3600;
            int minutes = (duration - (hours * 3600)) / 60;
            int seconds = duration % 60;
            
            if (hours > 0)
                objectValue = [[NSString stringWithFormat:@"%d:%02d:%02d",
                                hours, minutes, seconds] retain];
            else
                objectValue = [[NSString stringWithFormat:@"%d:%02d",
                                minutes, seconds] retain];
        }
        else
            objectValue = @"";
        
        return objectValue;
    }
    else {
        Chapter *chapter = item;
        if ([tableColumn.identifier isEqualToString:COLUMNID_NAME])
            return [chapter name];
        else if ([tableColumn.identifier isEqualToString:COLUMNID_TIME])
        {            
            UInt32 duration = [chapter totalDuration];
            duration /= 1000;
            int hours = duration / 3600;
            int minutes = (duration - (hours * 3600)) / 60;
            int seconds = duration % 60;
            
            if (hours > 0)
                objectValue = [[NSString stringWithFormat:@"%d:%02d:%02d",
                                hours, minutes, seconds] retain];
            else
                objectValue = [[NSString stringWithFormat:@"%d:%02d",
                                minutes, seconds] retain];
            return objectValue;
        }
        else
            return @"";
        
    }

    
    return nil;
}

// We can return a different cell for each row, if we want
- (NSCell *)outlineView:(NSOutlineView *)outlineView
 dataCellForTableColumn:(NSTableColumn *)tableColumn 
                   item:(id)item 
{
    // If we return a cell for the 'nil' tableColumn, it will be used 
    // as a "full width" cell and span all the columns
    return [tableColumn dataCell];
}


//
// optional methods for content editing
//

- (BOOL)    outlineView:(NSOutlineView *)outlineView 
  shouldEditTableColumn:(NSTableColumn *)tableColumn 
                   item:(id)item {

    if ([item isKindOfClass:[Chapter class]])
        if ([tableColumn.identifier isEqualToString:COLUMNID_NAME])
            return YES;
    // [outline editColumn:0 row:[outline selectedRow] withEvent:[NSApp currentEvent] select:YES];
    return NO;
}

- (void)outlineView:(NSOutlineView *)outlineView 
     setObjectValue:(id)object 
     forTableColumn:(NSTableColumn *)tableColumn 
             byItem:(id)item  
{
    Chapter *chapter = item;

    if ([item isKindOfClass:[Chapter class]])
        if ([tableColumn.identifier isEqualToString:COLUMNID_NAME])
            chapter.name = object;
}

// To get the "group row" look, we implement this method.
- (BOOL)outlineView:(NSOutlineView *)outlineView isGroupItem:(id)item 
{

    return ([item isKindOfClass:[Chapter class]]);
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldExpandItem:(id)item 
{
    
    return ([item isKindOfClass:[Chapter class]]);
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item 
{
    
    return YES;
}        


- (BOOL)outlineView:(NSOutlineView *)outlineView 
         writeItems:(NSArray *)items 
       toPasteboard:(NSPasteboard *)pboard 
{    

    _draggedNodes = items; 
    // Don't retain since this is just holding temporaral drag information, 
    // and it is only used during a drag!  We could put this in the pboard actually.
    
    // Provide data for our custom type, and simple NSStrings.    
    [pboard declareTypes:[NSArray arrayWithObjects:SIMPLE_BPOARD_TYPE, NSStringPboardType, NSFilesPromisePboardType, nil] 
                   owner:self];
    
    // the actual data doesn't matter since SIMPLE_BPOARD_TYPE drags aren't recognized by anyone but us!.
    [pboard setData:[NSData data] forType:SIMPLE_BPOARD_TYPE]; 
    
    // Put string data on the pboard... notice you can drag into TextEdit!
    [pboard setString:[_draggedNodes description] forType:NSStringPboardType];
    
    // Put the promised type we handle on the pasteboard.
    [pboard setPropertyList:[NSArray arrayWithObjects:@"txt", nil] forType:NSFilesPromisePboardType];

    return YES;
}


- (NSDragOperation) outlineView:(NSOutlineView *)outlineView 
                   validateDrop:(id <NSDraggingInfo>)info 
                   proposedItem:(id)item 
             proposedChildIndex:(NSInteger)childIndex 
{
    NSDragOperation result = NSDragOperationGeneric;

    //
    // check if we drop 'on' or 'between' something 
    //
    if (childIndex == NSOutlineViewDropOnItemIndex)
            result = NSDragOperationNone;
    
    if (_chapterMode) {
        BOOL draggingChapters = YES;
        for (id audioItem in _draggedNodes) {
            if ([audioItem isKindOfClass:[AudioFile class]]) {
                draggingChapters = NO;
                break;
            }
        }
        
        if ((item == nil) && !draggingChapters) 
            result = NSDragOperationNone;
    }
    
    return result;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView 
         acceptDrop:(id <NSDraggingInfo>)info 
               item:(id)item childIndex:(NSInteger)childIndex 
{
    NSMutableArray *newSelectedItems = [NSMutableArray array];

    if ([info draggingSource] == outlineView)
    {
        if (_chapterMode) {
            Chapter *dropChapter = item;
            if (dropChapter != nil) {
                for (id audioItem in _draggedNodes) {
                    if ([audioItem isKindOfClass:[Chapter class]]) {
                        for (AudioFile *file in [audioItem files]) {
                            [dropChapter insertFile:file atIndex:childIndex];
                            childIndex++;
                        }
                        [_chapters removeObject:audioItem];
                    }
                    else {
                        [self orphanFile:audioItem];
                        [dropChapter insertFile:audioItem atIndex:childIndex];
                        childIndex++;
                    }
                }
            }
            else {
                // reorder chapters, validateDrop will ensure there are
                // only Chapter nodes are dropped
                for (Chapter *ch in _draggedNodes) {
                    [_chapters removeObject:ch];
                    [_chapters insertObject:ch atIndex:childIndex];
                    childIndex++;
                }
            }
            
            [self cleanupChapters];

        }
        else {
            // Go ahead and move things. 
            for (AudioFile *file in _draggedNodes) {
                // Remove the node from its old location
                NSInteger oldIndex = [_files indexOfObject:file];
                NSInteger newIndex = childIndex;
                if (oldIndex != NSNotFound) {
                    [_files removeObjectAtIndex:oldIndex];
                    if (childIndex > oldIndex) {
                        newIndex--; // account for the remove
                    }
                }
                [_files insertObject:file atIndex:newIndex];
                newIndex++;
                [newSelectedItems addObject:file];
            }
        }
    }
    else {
        // drop from external source
        NSPasteboard *paste = [info draggingPasteboard];    //gets the dragging-specific pasteboard from the sender
        NSArray *types = [NSArray arrayWithObjects: NSFilenamesPboardType, nil];
        //a list of types that we can accept
        NSString *desiredType = [paste availableTypeFromArray:types];
        NSData *carriedData = [paste dataForType:desiredType];
        
        if (nil == carriedData)
            return NSDragOperationNone;
        
        if ([desiredType isEqualToString:NSFilenamesPboardType])
        {
			BOOL tryGuess = ![self hasFiles];
            //we have a list of file names in an NSData object
            NSArray *fileArray = [paste propertyListForType:@"NSFilenamesPboardType"];
            for (NSString *s in fileArray) {
                BOOL isDir;

                if ([[NSFileManager defaultManager] fileExistsAtPath:s isDirectory:&isDir])
                {
                    if (isDir)
                        // add file recursively
                        [self addFilesInDirectory:s];
                    else 
                        [self addFile:s];
                }
            }
			if (tryGuess) 
			{
				AudioBookBinderAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
				[appDelegate updateGuiWithGuessedData];
			}
        }
        
    }
    [outlineView reloadData];
    // Reselect old items.
    [outlineView setSelectedItems:newSelectedItems];
    
    return YES;
}

- (void)delKeyDown:(NSOutlineView *)outlineView
{
    [self deleteSelected:outlineView];
}

- (void)enterKeyDown:(NSOutlineView *)outlineView
{
    [self joinSelectedFiles:outlineView];
}

- (BOOL)deleteSelected:(NSOutlineView *)outlineView
{
    // Go ahead and move things. 
    [self willChangeValueForKey:@"hasFiles"];
    for (id item in [outlineView selectedItems]) {
        if ([item isKindOfClass:[Chapter class]]) {
            Chapter *ch = item;
            if ([_chapters count] > 1)
                [_chapters removeObject:ch];
        }
        else {
            AudioFile *file = item;
            // Remove the node from its old location
            NSInteger oldIndex = [_files indexOfObject:file];
            if (oldIndex != NSNotFound) {
                [_files removeObjectAtIndex:oldIndex];
            }
            
            for (Chapter *ch in _chapters) {
                if ([ch containsFile:file])
                    [ch removeFile:file];
            }
        }
    }
    [self cleanupChapters];
    [self didChangeValueForKey:@"hasFiles"];
    [outlineView deselectAll:self];
    [outlineView reloadData];    
    return YES;
}

- (BOOL)joinSelectedFiles:(NSOutlineView *)outlineView
{
    if (!_chapterMode)
        return NO;
    
    if (![[outlineView selectedItems] count]) 
        return NO;
    
    Chapter *newChapter = [[Chapter alloc] init];
    newChapter.name = TEXT_CHAPTER;
    Chapter *ch;
    
    id item = [[outlineView selectedItems] objectAtIndex:0];
    
    NSInteger chapterIndex;
    
    if ([item isKindOfClass:[Chapter class]])
        chapterIndex = [_chapters indexOfObject:item];
    else {
        AudioFile *file = item;
        for (ch in _chapters) {
            if ([ch containsFile:file]) {
                break;
            }
        }
        chapterIndex = [_chapters indexOfObject:ch];
    }
    
    for (item in [outlineView selectedItems]) {
        if ([item isKindOfClass:[Chapter class]]) {
            // copy all files
            for (AudioFile *f in [item files]) {
                if (![newChapter containsFile:f])
                    [newChapter addFile:f];
            }
            [_chapters removeObject:item];
        }
        else {
            if (![newChapter containsFile:item]) {
                [self orphanFile:item];
                [newChapter addFile:item]; 
            }
        }
    }
    
    [_chapters insertObject:newChapter atIndex:chapterIndex];
    [self cleanupChapters];
    [outlineView deselectAll:self];
    [outlineView reloadData]; 
    [outlineView setSelectedItem:newChapter];
    [outlineView expandItem:newChapter];
    
    return YES;
}

- (BOOL)splitSelectedFiles:(NSOutlineView *)outlineView
{
    if (!_chapterMode)
        return NO;
    
    if (![[outlineView selectedItems] count]) 
        return NO;
    
    NSMutableArray *newChapters = [[NSMutableArray alloc] init];
    for (id item in [outlineView selectedItems]) {
        if (![item isKindOfClass:[Chapter class]])
            continue;
        Chapter *ch = item;
        int chapterIndex = [_chapters indexOfObject:ch]+1;
        for (AudioFile *file in [ch files]) {
            Chapter *newChapter = [[Chapter alloc] init];
            newChapter.name = TEXT_CHAPTER;
            [newChapter addFile:file];
            [_chapters insertObject:newChapter atIndex:chapterIndex];
            chapterIndex++;
            [newChapters addObject:newChapter];
        }
        [_chapters removeObject:ch];
    }
    [self cleanupChapters];
    [outlineView deselectAll:self];
    [outlineView reloadData]; 
    for (id item in newChapters)
        [outlineView expandItem:item];
    if ([newChapters count])
        [outlineView setSelectedItem:[newChapters objectAtIndex:0]];
    [newChapters release];
    return YES;
}

- (void) orphanFile:(AudioFile*)file
{
    for (Chapter *ch in _chapters) {
        if ([ch containsFile:file])
            [ch removeFile:file];
    }
}

- (void) cleanupChapters
{
    int index = 0;
    while (index < [_chapters count]) {
        Chapter *ch = [_chapters objectAtIndex:index];
        if (([ch totalFiles] == 0) && ([_chapters count] > 1))
            [_chapters removeObject:ch];
        else
            index++;
    }
}



- (void)outlineViewSelectionDidChange:(NSNotification *)notification
{
    BOOL canPlay = NO;
    NSOutlineView *view = [notification object];
    if ([[view selectedItems] count] == 1) {    
        id item = [[view selectedItems] objectAtIndex:0];
        if ([item isKindOfClass:[AudioFile class]])
            canPlay = YES;
    }
    
    // do not spam AppDelegate
    if (_canPlay != canPlay) {
        AudioBookBinderAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
        _canPlay = canPlay;
        [appDelegate setCanPlay:_canPlay];
    }
}



- (void)      outlineView:(NSOutlineView *) outlineView
    didClickTableColumn:(NSTableColumn *) tableColumn 
{
    NSArray *columns = [outlineView tableColumns];
    if (_sortKey != nil) {
        for (NSTableColumn *c in columns) {
            [outlineView setIndicatorImage:nil
                         inTableColumn:c]; 
        }
        
        if ([_sortKey isEqualToString:[tableColumn identifier]])
            _sortAscending = !_sortAscending;
        else
            _sortAscending = YES;
    }
    
    _sortKey = [tableColumn identifier];
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:_sortKey ascending:_sortAscending];
    if (_chapterMode) {
        for (Chapter *c in _chapters) {
            [c sortUsingDecriptor:sortDescriptor];
        }
    }
    else
        [_files sortUsingDescriptors:[NSArray arrayWithObject:sortDescriptor]];
    [sortDescriptor release];
    [outlineView setIndicatorImage:(_sortAscending ?
                                    [NSImage imageNamed:@"NSAscendingSortIndicator"] :
                                    [NSImage imageNamed:@"NSDescendingSortIndicator"])
                     inTableColumn:tableColumn];
    
    [outlineView reloadData];

    
}

- (NSString *)commonAuthor
{
    if ([_files count] == 0)
        return nil;
    NSString *author = [[_files objectAtIndex:0] artist]; 
    for (AudioFile *f in _files) {
        if (![author isEqualToString:f.artist])
            return nil;
    }
    return author;
}

- (NSString *)commonAlbum
{
    if ([_files count] == 0)
        return nil;
    NSString *album = [[_files objectAtIndex:0] album]; 
    for (AudioFile *f in _files) {
        if (![album isEqualToString:f.album])
            return nil;
    }
    return album;
}
          
@end
