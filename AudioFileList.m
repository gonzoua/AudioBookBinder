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

#import "AudioFileList.h"
#import "AudioFile.h"
#import "Chapter.h"
#import "AudioBookBinderAppDelegate.h"
#import "ConfigNames.h"

// It is best to #define strings to avoid making typing errors
#define SIMPLE_BPOARD_TYPE           @"MyCustomOutlineViewPboardType"


#define TEXT_CHAPTER  \
    NSLocalizedString(@"Chapter", nil)
#define TEXT_CHAPTER_N  \
    NSLocalizedString(@"Chapter %d", nil)

@interface AudioFileList() {
    NSMutableArray *_files;
    NSMutableArray *_chapters;
    NSString *_topDir;
    NSArray *_draggedNodes;
    BOOL _sortAscending;
    NSString *_sortKey;
}
@end

@implementation AudioFileList

- (id) init
{
    if ((self = [super init])) 
    {
        _files = [[NSMutableArray alloc] init];
        _chapters = [[NSMutableArray alloc] init];
        _topDir = nil;
        self.chapterMode = YES;
        id modeObj = [[NSUserDefaults standardUserDefaults] objectForKey:kConfigChaptersEnabled];
        if (modeObj != nil)
            self.chapterMode = [modeObj boolValue];
        self.canPlay = NO;
        _sortAscending = YES;
        _sortKey = nil;
    }
    return self;
}

- (void) addFile:(NSString*)fileName
{
    AudioFile *file = [[AudioFile alloc] initWithPath:fileName];

    [self willChangeValueForKey:@"hasFiles"];
    
    if (file.valid) {
        [_files addObject:file];
        if (_chapterMode) {
            Chapter *chapter = [[Chapter alloc] init];
            if ([file.name length] > 0)
                NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"\\.\\w+$"
                                                                                       options:0
                                                                                         error:NULL];
                chapter.name = [regex stringByReplacingMatchesInString:file.name
                                                               options:0
                                                                 range:NSMakeRange(0, [file.name length])
                                                          withTemplate:@"$2$1"];


            else
                chapter.name = file.file;
            [_chapters addObject:chapter];

            [chapter addFile:file];
        }
    }
    else
        ;
    
    [self didChangeValueForKey:@"hasFiles"];
}

- (NSArray*) chapters
{
    NSArray *result;

    result = [NSArray arrayWithArray:_chapters];
    
    return result;
}

- (NSArray*) files
{
    NSMutableArray *result;
    if (_chapterMode) {
        result = [[NSMutableArray alloc] init];
        for (Chapter *ch in _chapters)
            [result addObjectsFromArray:ch.files];
    }
    else {
        result = [NSMutableArray arrayWithArray:_files];
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
    NSMutableArray *files = [[NSMutableArray alloc] init];
    NSDirectoryEnumerator *dirEnum = [[NSFileManager defaultManager] enumeratorAtPath:dirName];
    while ((currentFile = [dirEnum nextObject]))
    {
        [files addObject:currentFile];
    }

    // Should be OK for most cases  
    BOOL sortFiles = [[NSUserDefaults standardUserDefaults] boolForKey:kConfigSortAudioFiles];

    NSArray *orderedFiles;
    if (sortFiles)
        orderedFiles = [files sortedArrayUsingComparator:^(id a, id b) {return [a compare:b];}];
    else
        orderedFiles = [NSArray arrayWithArray:files];


    for (currentFile in orderedFiles) {
        NSString *currentPath = [dirName stringByAppendingPathComponent:currentFile];
        [self addFile:currentPath];
    }
}

- (void) switchChapterMode
{
    // this function is called before _chapterMode is changed by binding
    if (!_chapterMode) {
        if ([_files count]) {
            // put all files in one folder
            Chapter *newChapter = [[Chapter alloc] init];
            newChapter.name = TEXT_CHAPTER;
            [_chapters removeAllObjects];
            for (AudioFile *file in _files) {
                [newChapter addFile:file];
            }
            [_chapters addObject:newChapter];
        }
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
        else if ([tableColumn.identifier isEqualToString:COLUMNID_NAME]) {
            if ([file.name length] > 0)
                objectValue = file.name;
            else
                objectValue = file.file;
        } else if ([tableColumn.identifier isEqualToString:COLUMNID_AUTHOR])
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
                objectValue = [NSString stringWithFormat:@"%d:%02d:%02d",
                                hours, minutes, seconds];
            else
                objectValue = [NSString stringWithFormat:@"%d:%02d",
                                minutes, seconds];
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
                objectValue = [NSString stringWithFormat:@"%d:%02d:%02d",
                                hours, minutes, seconds];
            else
                objectValue = [NSString stringWithFormat:@"%d:%02d",
                                minutes, seconds];
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

    // we have stale _draggedNodes, release them
    if (_draggedNodes) {
        _draggedNodes = nil;
    }
    
    _draggedNodes = [items copy]; 
    
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

    if ([info draggingSource] == outlineView) {
        if (_chapterMode) {
            BOOL draggingChapters = YES;
            for (id audioItem in _draggedNodes) {
                if ([audioItem isKindOfClass:[AudioFile class]]) {
                    draggingChapters = NO;
                    break;
                }
            }
            // only chapters could be dropped on root item
            if ((item == nil) && !draggingChapters) 
                result = NSDragOperationNone;
            else {
                // prevent chapter from being dropped on itself
                for (id audioItem in _draggedNodes) {
                    if (audioItem == item) {
                        result = NSDragOperationNone;
                        break;
                    }
                }
            }
        }
    }
    else
    {
        // we have stale _draggedNodes, release them
        if (_draggedNodes) {
            _draggedNodes = nil;
        }
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
                        if ([dropChapter containsFile:audioItem]) {
                            NSUInteger idx = [dropChapter indexOfFile:audioItem];
                            if (idx <= childIndex)
                                childIndex--;
                        }
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
        
        if (_draggedNodes) {
            _draggedNodes = nil;
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
            //we have a list of file names in an NSData object
            NSArray *fileArray;
            BOOL sortFiles = [[NSUserDefaults standardUserDefaults] boolForKey:kConfigSortAudioFiles];

            if (sortFiles)
                fileArray = [[paste propertyListForType:@"NSFilenamesPboardType"] sortedArrayUsingComparator:^(id a, id b) {return [a compare:b];}];
            else
                fileArray = [paste propertyListForType:@"NSFilenamesPboardType"];

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
            
            [self tryGuessingAuthorAndAlbum];
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

            for (AudioFile *file in [ch files]) {
                [_files removeObject:file];
            }

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
    Chapter *ch;
    
    id item = [[outlineView selectedItems] objectAtIndex:0];
    
    NSInteger chapterIndex;
    
    if ([item isKindOfClass:[Chapter class]]) {
        chapterIndex = [_chapters indexOfObject:item];
        ch = (Chapter*)item;
        newChapter.name = ch.name;
    }
    else {
        AudioFile *file = item;
        if ([file.name length] > 0)
            newChapter.name = file.name;
        else
            newChapter.name = file.file;

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
        NSUInteger chapterIndex = [_chapters indexOfObject:ch]+1;
        for (AudioFile *file in [ch files]) {
            Chapter *newChapter = [[Chapter alloc] init];
            if ([file.name length] > 0)
                newChapter.name = file.name;
            else
                newChapter.name = file.file;
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
    BOOL playable = NO;
    NSOutlineView *view = [notification object];
    if ([[view selectedItems] count] == 1) {    
        id item = [[view selectedItems] objectAtIndex:0];
        if ([item isKindOfClass:[AudioFile class]])
            playable = YES;
    }
    
    self.canPlay = playable;
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
    [outlineView setIndicatorImage:(_sortAscending ?
                                    [NSImage imageNamed:@"NSAscendingSortIndicator"] :
                                    [NSImage imageNamed:@"NSDescendingSortIndicator"])
                     inTableColumn:tableColumn];
    
    [outlineView reloadData];

    
}



- (void) removeAllFiles:(NSOutlineView*)outlineView;
{
    Chapter *newChapter = nil;

    [self willChangeValueForKey:@"hasFiles"];
    [_files removeAllObjects];
    [_chapters removeAllObjects];

    [outlineView deselectAll:self];
    [outlineView reloadData];
    if (_chapterMode)
        [outlineView expandItem:newChapter];
    [self didChangeValueForKey:@"hasFiles"];

}

- (void)tryGuessingAuthorAndAlbum
{
    if ([_files count] == 0) {
        self.commonAlbum = nil;
        self.commonAuthor = nil;
    }
    else {
        NSString *author = [[_files objectAtIndex:0] artist];
        NSString *album = [[_files objectAtIndex:0] album];

        for (AudioFile *f in _files) {
            if (![author isEqualToString:f.artist]) {
                author = nil;
                break;
            }
        }
        
        for (AudioFile *f in _files) {
            if (![album isEqualToString:f.album]) {
                album = nil;
                break;
            }
        }
        
        self.commonAlbum = album;
        self.commonAuthor = author;
    }
}

@end
