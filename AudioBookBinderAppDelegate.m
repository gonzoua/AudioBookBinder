//
//  AudioBookBinderAppDelegate.m
//  AudioBookBinder
//
//  Created by Oleksandr Tymoshenko on 10-02-04.
//  Copyright 2010 Bluezbox Software. All rights reserved.
//

#import "AudioBookBinderAppDelegate.h"
#import "AudioFile.h"
#import "MP4File.h"
#import "ExpandedPathToPathTransformer.h"
#import "ExpandedPathToIconTransformer.h"
#include "MetaEditor.h"
#import "AudioBinder.h"
#import "AudioBinderVolume.h"
#import "Chapter.h"
#import "NSOutlineView_Extension.h"

#import "Sparkle/SUUpdater.h"

// localized strings
#define TEXT_CONVERSION_FAILED  \
    NSLocalizedString(@"Audiofile conversion failed", nil)
#define TEXT_BINDING_FAILED     \
    NSLocalizedString(@"Audiobook binding failed", nil)
#define TEXT_ADDING_TAGS        \
    NSLocalizedString(@"Adding artist/title tags", nil)
#define TEXT_ADDING_CHAPTERS    \
    NSLocalizedString(@"Adding chapter markers", nil)
#define TEXT_ADDING_TO_ITUNES   \
    NSLocalizedString(@"Adding file to iTunes", nil)
#define TEXT_CONVERTING         \
    NSLocalizedString(@"Converting %@", nil)
#define TEXT_CANT_SPLIT \
    NSLocalizedString(@"Failed to split audiobook into volumes", nil)
#define TEXT_MAXDURATION_VIOLATED \
    NSLocalizedString(@"%s: duration (%d sec) is larger then max. volume duration (%lld sec.)", nil)
#define TEXT_FAILED_TO_PLAY \
    NSLocalizedString(@"Failed to play", nil)
#define TEXT_CANT_PLAY \
    NSLocalizedString(@"Failed to play: %@", nil)


column_t columnDefs[] = {
    {COLUMNID_FILE, @"File", NO}, 
    {COLUMNID_AUTHOR, @"Author", NO}, 
    {COLUMNID_ALBUM, @"Album", NO}, 
    {COLUMNID_TIME, @"Time", NO}, 
    {nil, nil}
};


enum abb_form_fields {
    ABBAuthor = 0,
    ABBTitle,
};

@implementation AudioBookBinderAppDelegate

+ (void) initialize
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSMutableDictionary *appDefaults = [NSMutableDictionary
                                        dictionaryWithObject:[NSNumber numberWithInt:2] forKey:@"Channels"];
    // for checkbox "add to itunes"
    [appDefaults setObject:[NSNumber numberWithBool:YES] forKey:@"AddToiTunes"];
    [appDefaults setObject:@"44100" forKey:@"SampleRate"];
    [appDefaults setObject:@"128000" forKey:@"Bitrate"];
    [appDefaults setObject:[NSNumber numberWithInt:25] forKey:@"MaxVolumeSize"];
    [appDefaults setObject:[NSNumber numberWithBool:YES] forKey:@"ChaptersEnabled"];
    [appDefaults setObject:[NSArray arrayWithObjects:COLUMNID_TIME, nil] forKey:@"ColumnsConfiguration"];

    // for pop-up button Destination Folder
    NSString *homePath = NSHomeDirectory();
    [appDefaults setObject:homePath forKey:@"DestinationFolder"];
#ifdef notyet
    [appDefaults setObject:[NSNumber numberWithBool:YES] forKey:@"DestinationiTunes"];
#endif    
    [defaults registerDefaults:appDefaults];
    
    //set custom value transformers    
    ExpandedPathToPathTransformer * pathTransformer = [[[ExpandedPathToPathTransformer alloc] init] autorelease];
    [NSValueTransformer setValueTransformer: pathTransformer forName: @"ExpandedPathToPathTransformer"];
    ExpandedPathToIconTransformer * iconTransformer = [[[ExpandedPathToIconTransformer alloc] init] autorelease];
    [NSValueTransformer setValueTransformer: iconTransformer forName: @"ExpandedPathToIconTransformer"];

}

@synthesize validBitrates, canPlay;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    int idx;
    
    [[window windowController] setShouldCascadeWindows:NO];      // Tell the controller to not cascade its windows.
    [window setFrameAutosaveName:@"AudioBookbinderWindow"];  // Specify the autosave name for the window.
    [window setFrameUsingName:@"AudioBookbinderWindow"];

    [fileListView setDataSource:fileList];
    [fileListView setDelegate:fileList];
    [fileListView setAllowsMultipleSelection:YES];
    
    // add column
    // build table header context menu
    NSMenu *tableHeaderContextMenu = [[NSMenu alloc] initWithTitle:@""];
    [[fileListView headerView] setMenu:tableHeaderContextMenu];
#if 0    
    NSArray *tableColumns = [NSArray arrayWithObjects:@"File", @"Title", @"Author", @"Album", @"Duration", nil]; 
    NSEnumerator *enumerator = [tableColumns objectEnumerator];
    NSString *column;
    // while((column = [enumerator nextObject])) 
#endif
    
    NSTableColumn *outlineColumn = [[fileListView tableColumns] objectAtIndex:0];
    outlineColumn.identifier = COLUMNID_NAME; 
    [[outlineColumn headerCell] setStringValue:@"Name"];

    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    currentColumns = [[NSMutableArray alloc] init];
    [currentColumns addObjectsFromArray:[defaults objectForKey:@"ColumnsConfiguration"]];
    
    
    for (NSString *column_id in currentColumns) {
        BOOL found = NO;
        for (idx = 0; columnDefs[idx].id; idx++)
        {
            if ([columnDefs[idx].id isEqualToString:column_id]) {
                columnDefs[idx].enabled = YES;
                found = YES;
                break;
            }
        }
        
        if (found) {
            NSTableColumn *c = [[NSTableColumn alloc] initWithIdentifier:columnDefs[idx].id];
            [fileListView addTableColumn:c];
            [[c headerCell] setStringValue:columnDefs[idx].title];
        }
    }
    
    for (idx = 0; columnDefs[idx].id; idx++)
    {
        NSString *title = columnDefs[idx].title;
        NSMenuItem *item = [tableHeaderContextMenu addItemWithTitle:title action:@selector(contextMenuSelected:) keyEquivalent:@""];
        [item setTarget:self];
        [item setRepresentedObject:columnDefs[idx].id];
        [item setState:columnDefs[idx].enabled?NSOnState:NSOffState];        
    }

    
    [fileListView registerForDraggedTypes:[NSArray arrayWithObjects:NSStringPboardType, NSFilenamesPboardType, nil]];
    [fileListView setDraggingSourceOperationMask:NSDragOperationEvery forLocal:YES];
    [fileListView setDraggingSourceOperationMask:NSDragOperationCopy forLocal:NO];
    [fileListView setAutoresizesOutlineColumn:NO];
    // expand initial chapter if chapter mode is enabled
    [fileListView expandItem:nil expandChildren:YES];
    
    _binder = [[[AudioBinder alloc] init] retain];
    _playing = NO;
    NSString* img = [[NSBundle mainBundle] pathForResource:@"Play" ofType:@"png"];
    NSURL* url = [NSURL fileURLWithPath:img];
    _playImg = [[NSImage alloc] initWithContentsOfURL:url];
    img = [[NSBundle mainBundle] pathForResource:@"Stop" ofType:@"png"];
    url = [NSURL fileURLWithPath:img];
    _stopImg = [[NSImage alloc] initWithContentsOfURL:url];    
    
    [playButton setImage:_playImg] ;
    [playButton setEnabled:NO];
    [self updateValidBitrates:self];
    _playingFile = nil;
    
#ifdef APP_STORE_BUILD     
    NSMenu *firstSubmenu = [[applicationMenu itemAtIndex:0] submenu];
    [firstSubmenu removeItemAtIndex:1];
#else
    // XXX: hack to make autoupdates work
    [SUUpdater sharedUpdater];
#endif
}

- (IBAction) addFiles: (id)sender
{
    int i; // Loop counter.
    
    // Create the File Open Dialog class.
    NSOpenPanel *openDlg = [NSOpenPanel openPanel];
    
    [openDlg setCanChooseFiles:YES];
    [openDlg setCanChooseDirectories:YES];
    [openDlg setAllowsMultipleSelection:YES];
    
    if ( [openDlg runModalForDirectory:nil file:nil] == NSOKButton )
    {
        NSArray *files = [openDlg filenames];
        
        for( i = 0; i < [files count]; i++ )
        {
            NSString* fileName = [files objectAtIndex:i];
            BOOL isDir;
            if ([[NSFileManager defaultManager] fileExistsAtPath:fileName isDirectory:&isDir])
            {
                if (isDir)
                    // add file recursively
                    [fileList addFilesInDirectory:fileName];
                else 
                    [fileList addFile:fileName];
            }
        }
        
        [fileListView reloadData];
    }    
}

- (IBAction) delFiles: (id)sender
{

    [fileList deleteSelected:fileListView];
}

- (IBAction) bind: (id)sender
{

    NSString *author = [[form cellAtIndex:ABBAuthor] stringValue];
    NSString *title = [[form cellAtIndex:ABBTitle] stringValue];
    NSSavePanel *savePanel;
    int choice;
    NSMutableString *filename = [[NSMutableString string] retain];
    
    if (![author isEqualToString:@""])
        [filename appendString:[author stringByReplacingOccurrencesOfString:@"/" withString:@" "]];
    
    if (![title isEqualToString:@""]) {
        if (![filename isEqualToString:@""])
            [filename appendString:@" - "];
        
        [filename appendString:[title stringByReplacingOccurrencesOfString:@"/" withString:@" "]];
    }

    if ([filename isEqualToString:@""])
        [filename setString:@"audiobook"];
    [filename appendString:@".m4b"];
    
    savePanel = [NSSavePanel savePanel];
    [savePanel setAccessoryView: nil];
    // [savePanel setAllowedFileTypes:[NSArray arrayWithObjects:@"m4a", @"m4b", nil]];
    NSString *dir = [[NSUserDefaults standardUserDefaults] stringForKey:@"DestinationFolder"];

#ifdef notyet    
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DestinationiTunes"]) {
        dir = [self _getiTunesMediaFolder];
    }
#endif
    
    choice = [savePanel runModalForDirectory:dir file:filename];
    [filename release];
    /* if successful, save file under designated name */
    if (choice == NSOKButton)
    {
        [bindButton setEnabled:FALSE];
        outFile = [[savePanel filename] retain];

        [NSThread detachNewThreadSelector:@selector(bindToFileThread:) toTarget:self withObject:nil];
    }
}

- (IBAction) setCover: (id)sender
{    
    // Create the File Open Dialog class.
    NSOpenPanel *openDlg = [NSOpenPanel openPanel];
    
    [openDlg setCanChooseFiles:YES];
    [openDlg setCanChooseDirectories:NO];
    [openDlg setAllowsMultipleSelection:NO];
    
    if ( [openDlg runModalForDirectory:nil file:nil] == NSOKButton )
    {
        NSArray *files = [openDlg filenames];

        NSString* fileName = [files objectAtIndex:0];
        BOOL isDir;
        if ([[NSFileManager defaultManager] fileExistsAtPath:fileName isDirectory:&isDir])
        {
            if (!isDir) // just sanity check
            {
                coverImageView.coverImageFilename = fileName;
                [tabs selectTabViewItemAtIndex:1];
            }
        }
        
        [fileListView reloadData];
    }    
}

- (IBAction) chapterModeWillChange: (id)sender
{
    [fileList switchChapterMode];
    [fileListView reloadData];
    [fileListView expandItem:nil expandChildren:YES];
}

- (IBAction) renumberChapters: (id)sender
{
    [fileList renumberChapters];
    [fileListView reloadData];
}

- (IBAction) joinFiles: (id)sender
{
    [fileList joinSelectedFiles:fileListView];
}

- (IBAction) splitFiles: (id)sender
{
    [fileList splitSelectedFiles:fileListView];
}

- (void) bindingThreadIsDone:(id)sender
{
    [bindButton setEnabled:TRUE];
}

- (void)bindToFileThread:(id)object
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    NSString *author = [[form cellAtIndex:ABBAuthor] stringValue];
    NSString *title = [[form cellAtIndex:ABBTitle] stringValue];
    NSString *coverImageFilename = nil;
    NSImage *coverImage = coverImageView.coverImage;
    UInt64 maxVolumeDuration = 0;
    NSInteger hours = [[NSUserDefaults standardUserDefaults] integerForKey:@"MaxVolumeSize"];
    if ((hours > 0) && (hours < 25))
        maxVolumeDuration = hours * 3600;
    
    NSLog(@"maxVolumeDuration == %lld", maxVolumeDuration);
    
    [_binder reset];
    [_binder setDelegate:self];
    
    // split output filename to base and extension in order to get 
    // filenames for consecutive volume files
    NSString *outFileBase = [[outFile stringByDeletingPathExtension] retain];
    NSString *outFileExt = [[outFile pathExtension] retain];
    
    NSArray *files = [fileList files];
    NSMutableArray *inputFiles = [[NSMutableArray alloc] init];
    UInt64 estTotalDuration = 0;
    NSString *currentVolumeName = [outFile copy];
    NSMutableArray *volumeChapters = [[NSMutableArray alloc] init];
    NSArray *chapters = nil;
    NSMutableArray *curChapters = [[NSMutableArray alloc] init];
    Chapter *curChapter = nil;
    int chapterIdx = 0;
    BOOL hasChapters = [fileList chapterMode];
    
    if (hasChapters) {
        chapters = [fileList chapters];
        curChapter = [[chapters objectAtIndex:chapterIdx] copy];
        chapterIdx++;
        [curChapters addObject:curChapter];
    }
    
    int totalVolumes = 0;
    BOOL onChapterBoundary = YES;
    for (AudioFile *file in files) {
        if (hasChapters) {
            if (![curChapter containsFile:file]) {
                NSLog(@"%@ -> next chapter", file.filePath);
                curChapter = [[chapters objectAtIndex:chapterIdx] copy];
                chapterIdx++;
                onChapterBoundary = YES;
                [curChapters addObject:curChapter];
            }
        }
        
        if (maxVolumeDuration) {
            if ((estTotalDuration + file.duration) > maxVolumeDuration*1000) {
                if ([inputFiles count] > 0) {
                    [_binder addVolume:currentVolumeName files:inputFiles];
                    [inputFiles removeAllObjects];
                    estTotalDuration = 0;
                    totalVolumes++;
                    currentVolumeName = [[NSString alloc] initWithFormat:@"%@-%d.%@",
                                         outFileBase, totalVolumes, outFileExt];
                    if (hasChapters) {
                        [volumeChapters addObject:curChapters];
                        if (!onChapterBoundary) {
                            curChapter = [curChapter splitAtFile:file];
                            NSLog(@"Splitting chapter %@ on file %@", curChapter.name, file.filePath);
                        }
                        curChapters = [[NSMutableArray alloc] init];
                        [curChapters addObject:curChapter];
                    }
                }
                else {
                    NSAlert *alert = [[[NSAlert alloc] init] retain];
                    NSString *msg = [NSString stringWithFormat:TEXT_MAXDURATION_VIOLATED, 
                                     [file.filePath UTF8String], file.duration/1000, maxVolumeDuration];
                    [alert addButtonWithTitle:@"OK"];
                    [alert setMessageText:TEXT_CANT_SPLIT];
                    [alert setInformativeText:msg];
                    [alert setAlertStyle:NSWarningAlertStyle];
                    [alert runModal];
                    return;
                }
            }
        }
        onChapterBoundary = NO;
        [inputFiles addObject:file];
        estTotalDuration += file.duration;
    }
    
    [_binder addVolume:currentVolumeName files:inputFiles];
    [volumeChapters addObject:curChapters];
    
    // make sure that at this point we have valid bitrate in settings
    [self fixupBitrate];
    // setup channels/samplerate

    _binder.channels = [[NSUserDefaults standardUserDefaults] integerForKey:@"Channels"];
    _binder.sampleRate = [[NSUserDefaults standardUserDefaults] floatForKey:@"SampleRate"];
    _binder.bitrate = [[NSUserDefaults standardUserDefaults] integerForKey:@"Bitrate"];
    
    [NSApp beginSheet:progressPanel modalForWindow:window
        modalDelegate:self didEndSelector:NULL contextInfo:nil];    
    
    [fileProgress setMaxValue:100.];
    [fileProgress setDoubleValue:0.]; 
    [fileProgress displayIfNeeded];
    if (![_binder convert])
    {
        NSLog(@"Conversion failed");
    }        
    
    else 
    {
        if (![author isEqualToString:@""] || 
                 ![title isEqualToString:@""] || (coverImage != nil))
        {
            NSLog(@"Adding metadata, it may take a while...");
            @try {
                [currentFile setStringValue:TEXT_ADDING_TAGS];
                BOOL temporaryFile = NO;
                if ([coverImageView haveCover]) {
                    if ([coverImageView shouldConvert]) {
                        NSString *tempFileTemplate =
                        [NSTemporaryDirectory() stringByAppendingPathComponent:@"coverimg.XXXXXX"];
                        const char *tempFileTemplateCString =
                        [tempFileTemplate fileSystemRepresentation];
                        char *tempFileNameCString = (char *)malloc(strlen(tempFileTemplateCString) + 1);
                        strcpy(tempFileNameCString, tempFileTemplateCString);
                        if (mktemp(tempFileNameCString)) {
                            coverImageFilename = [NSString stringWithCString:tempFileNameCString encoding:NSUTF8StringEncoding];                
                            NSData *imgData = [coverImage TIFFRepresentation];
                            NSDictionary *dict = [[NSDictionary alloc] init];
                            [[[NSBitmapImageRep imageRepWithData:imgData] 
                              representationUsingType:NSPNGFileType properties:dict]
                             writeToFile:coverImageFilename atomically:YES];
                            [dict release];
                            temporaryFile = YES;
                        }
                        else {
                            NSLog(@"Failed to generate tmp filename");
                        }
                    }
                    else {
                        coverImageFilename = coverImageView.coverImageFilename;
                    }
                }
    
                
                int track = 1;
                NSArray *volumes = [_binder volumes];
                for (AudioBinderVolume *v in volumes) {
                    NSString *volumeName = v.filename;
                    MP4File *mp4 = [[MP4File alloc] initWithFileName:volumeName];
                    mp4.artist = author;
                    if ([volumes count] > 1) {
                        mp4.title = [NSString stringWithFormat:@"%@ #%02d", title, track];
                        mp4.gaplessPlay = YES;
                    }
                    else
                        mp4.title = title;
                    mp4.album = title;
                    if (coverImageFilename)        
                        [mp4 setCoverFile:coverImageFilename];
                    mp4.track = track;
                    mp4.tracksTotal = [volumes count];
                    [mp4 updateFile];
                    [mp4 release];
                    track ++;
                }
                
                if ((coverImageFilename != nil) && temporaryFile) {
                    NSLog(@"Unlink %@", coverImageFilename);
                    [[NSFileManager defaultManager] removeFileAtPath:coverImageFilename 
                                                             handler:nil];
                }
                
                if ([fileList chapterMode]) {
                    [currentFile setStringValue:TEXT_ADDING_CHAPTERS];
                    int idx = 0;
                    for (AudioBinderVolume *v in volumes) {
                        addChapters([v.filename UTF8String], [volumeChapters objectAtIndex:idx]);
                        idx++;
                    }

                }
                
                if ([[NSUserDefaults standardUserDefaults] boolForKey:@"AddToiTunes"]) {

                    [currentFile setStringValue:TEXT_ADDING_TO_ITUNES];
                    for(AudioBinderVolume *volume in volumes)
                        [self addFileToiTunes:volume.filename];
                }
                
                [currentFile setStringValue:@"Done"];
                
            }
            @catch (NSException *e) {
                NSLog(@"Something went wrong");
            }
        }
        
        // write chapters
    }
    
    [NSApp endSheet:progressPanel];
    [progressPanel orderOut:nil];
    [self performSelectorOnMainThread:@selector(bindingThreadIsDone:) withObject:nil waitUntilDone:NO];
    [pool release];
}

//
// AudioBinderDelegate methods
// 
-(void) conversionStart: (AudioFile*)file 
                 format: (AudioStreamBasicDescription*)asbd 
      formatDescription: (NSString*)description 
                 length: (UInt64)frames

{
    [currentFile setStringValue:[NSString stringWithFormat:TEXT_CONVERTING, 
                                 [file filePath]]];
    [fileProgress setMaxValue:(double)frames];
    [fileProgress setDoubleValue:0];
}

-(void) updateStatus: (AudioFile *)file handled:(UInt64)handledFrames total:(UInt64)totalFrames
{
    [fileProgress setMaxValue:(double)totalFrames];
    [fileProgress setDoubleValue:(double)handledFrames];
}

-(BOOL) continueFailedConversion:(AudioFile*)file reason:(NSString*)reason
{

    NSAlert *alert = [[[NSAlert alloc] init] retain];
    [alert addButtonWithTitle:@"OK"];
    [alert setMessageText:TEXT_CONVERSION_FAILED];
    [alert setInformativeText:reason];
    [alert setAlertStyle:NSWarningAlertStyle];
    [alert runModal];
    return NO;
}

-(void) volumeFailed:(NSString*)filename reason:(NSString*)reason
{
    
    NSAlert *alert = [[[NSAlert alloc] init] retain];
    [alert addButtonWithTitle:@"OK"];
    [alert setMessageText:TEXT_BINDING_FAILED];
    [alert setInformativeText:reason];
    [alert setAlertStyle:NSWarningAlertStyle];
    [alert runModal];
}


-(void) conversionFinished:(AudioFile*)file duration:(UInt32)milliseconds
{
    [fileProgress setDoubleValue:[fileProgress doubleValue]];
    file.valid = YES;
    file.duration = milliseconds;
}

-(void) volumeReady:(NSString*)filename duration: (UInt32)seconds
{
}

-(void) audiobookReady:(UInt32)seconds
{
}

- (IBAction) cancel: (id)sender
{
    [_binder cancel];
}

- (void) addFileToiTunes: (NSString*)path
{
    NSDictionary* errorDict;
    NSAppleEventDescriptor* returnDescriptor = NULL;
    
    NSString *source = [NSString stringWithFormat:
                        @"\
                        tell application \"iTunes\"\n\
                            add POSIX file \"%@\"\n\
                        end tell", path, nil];
    
    NSAppleScript* scriptObject = [[NSAppleScript alloc] initWithSource:source];
    
    returnDescriptor = [scriptObject executeAndReturnError: &errorDict];
    [scriptObject release];
}

- (IBAction) updateValidBitrates: (id)sender
{
    // Initialize samplerate/channels -> avail bitrates
    AudioBinder *tmpBinder = [[AudioBinder alloc] init];

    // setup channels/samplerate
    tmpBinder.channels = [[NSUserDefaults standardUserDefaults] integerForKey:@"Channels"];
    tmpBinder.sampleRate = [[NSUserDefaults standardUserDefaults] floatForKey:@"SampleRate"];
    self.validBitrates = [tmpBinder validBitrates];
    [self fixupBitrate];
    
    [tmpBinder release];
}

- (void) fixupBitrate
{
    int bitrate = [[NSUserDefaults standardUserDefaults] integerForKey:@"Bitrate"];
    int newBitrate;
    int distance = bitrate;
    
    for (NSNumber *n in validBitrates) {
        if (abs([n integerValue] - bitrate) < distance) {
            distance = abs([n integerValue] - bitrate);
            newBitrate = [n integerValue];
        }
    }
    
    if (newBitrate != bitrate) {
        [[NSUserDefaults standardUserDefaults] setInteger:newBitrate forKey:@"Bitrate"];
    }
}

- (BOOL)windowShouldClose:(NSNotification *)notification
{
	[window orderOut:self];
	return NO;
}

- (BOOL) applicationShouldHandleReopen:(NSApplication *)theApplication
                     hasVisibleWindows:(BOOL)flag 
{
    if (!flag) {
        [window makeKeyAndOrderFront:nil];
    }
    return YES;
}


- (IBAction) playStop: (id)sender
{
    if ((_sound != nil) && [_sound isPlaying]) {
        [_sound stop];
        return;
    }
    
    if ([[fileListView selectedItems] count] != 1)
        return;
    
    id item = [[fileListView selectedItems] objectAtIndex:0];
    if ([item isKindOfClass:[AudioFile class]]) {
        AudioFile *file = (AudioFile *)item;
        [playButton setImage:_stopImg] ;
        if (_playingFile)
            [_playingFile release];
        
        _playingFile = [[file.filePath copy] retain];
        _sound = [[NSSound alloc] initWithContentsOfFile:file.filePath byReference:NO];
        [_sound setDelegate:self];
        if (![_sound play]) {
            [playButton setImage:_playImg] ;
            [_sound release];
            _sound = nil;
            [playButton setEnabled:canPlay];            
            [self playFailed];
        }
    }
}

- (void)sound:(NSSound *)sound didFinishPlaying:(BOOL)finishedPlaying
{
    [playButton setImage:_playImg] ;
    [_sound release];
    _sound = nil;
    [playButton setEnabled:canPlay];
}

- (void) playFailed
{
    NSAlert *alert = [[[NSAlert alloc] init] retain];
    NSString *msg = [NSString stringWithFormat:TEXT_CANT_PLAY, _playingFile];
    [alert addButtonWithTitle:@"OK"];
    [alert setMessageText:TEXT_FAILED_TO_PLAY];
    [alert setInformativeText:msg];
    [alert setAlertStyle:NSWarningAlertStyle];
    [alert runModal];
}

- (void)setCanPlay:(BOOL)b
{
    if (_sound == nil) {
        [playButton setEnabled:b];
    }
    canPlay = b;
}

- (void)openChaptersHowTo:(id)sender
{
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://bluezbox.com/audiobookbinder/chapters.html"]];
}

- (void) checkForUpdates:(id)sender
{
#ifndef APP_STORE_BUILD
    [[SUUpdater sharedUpdater] checkForUpdates:sender];
#endif

}

- (void)contextMenuSelected:(id)sender
{
    NSMenuItem *item = sender;
    if (item.state == NSOffState) {
        [item setState:NSOnState];
        
        BOOL found = NO;
        int idx;
        for (idx = 0; columnDefs[idx].id; idx++)
        {
            if ([columnDefs[idx].id isEqualToString:[item representedObject]]) {
                found = YES;
                break;
            }
        }
        
        if (found) {
            NSTableColumn *c = [[NSTableColumn alloc] initWithIdentifier:columnDefs[idx].id];
            [fileListView addTableColumn:c];
            [[c headerCell] setStringValue:columnDefs[idx].title];
        }
    }
    else {
        NSTableColumn *c = [fileListView tableColumnWithIdentifier:[item representedObject]];
        if (c) {
            [fileListView removeTableColumn:c];
        }
        [item setState:NSOffState];
    }
}

@end
