//
//  AudioBinderWindowController.m
//  AudioBookBinder
//
//  Created by Oleksandr Tymoshenko on 2013-12-14.
//  Copyright (c) 2013 Bluezbox Software. All rights reserved.
//

#import "AudioBinderWindowController.h"
#import "Chapter.h"
#import "AudioBinderVolume.h"
#import "AudioFile.h"
#import "MP4File.h"
#import "ExpandedPathToPathTransformer.h"
#import "ExpandedPathToIconTransformer.h"
#include "MetaEditor.h"
#import "AudioBinder.h"
#import "AudioBinderVolume.h"
#import "Chapter.h"
#import "NSOutlineView_Extension.h"
#import "StatsManager.h"

// localized strings
#define TEXT_CONVERSION_FAILED  NSLocalizedString(@"Audiofile conversion failed", nil)
#define TEXT_BINDING_FAILED     NSLocalizedString(@"Audiobook binding failed", nil)
#define TEXT_ADDING_TAGS        NSLocalizedString(@"Adding artist/title tags", nil)
#define TEXT_ADDING_CHAPTERS    NSLocalizedString(@"Adding chapter markers", nil)
#define TEXT_ADDING_TO_ITUNES   NSLocalizedString(@"Adding file to iTunes", nil)
#define TEXT_CONVERTING         NSLocalizedString(@"Converting %@", nil)
#define TEXT_CANT_SPLIT         NSLocalizedString(@"Failed to split audiobook into volumes", nil)
#define TEXT_MAXDURATION_VIOLATED NSLocalizedString(@"%s: duration (%d sec) is larger then max. volume duration (%lld sec.)", nil)
#define TEXT_FAILED_TO_PLAY     NSLocalizedString(@"Failed to play", nil)
#define TEXT_CANT_PLAY          NSLocalizedString(@"Failed to play: %@", nil)
#define TEXT_AUDIOBOOK          NSLocalizedString(@"Audiobook", nil)
#define TEXT_AUDIOBOOKS         NSLocalizedString(@"Audiobooks", nil)
#define TEXT_FILE_EXISTS        NSLocalizedString(@"File exists", @"epub file exists")
#define TEXT_FILE_OVERWRITE     NSLocalizedString(@"File %@ already exists, replace?", @"epub file exists")
#define TEXT_OVERWRITE          NSLocalizedString(@"Replace", @"")
#define TEXT_CANCEL             NSLocalizedString(@"Cancel", @"")
#define TEXT_BOOK_IS_READY      NSLocalizedString(@"Audiobook is ready", @"");

#define ColumnsConfiguration @"ColumnsConfiguration"

#define KVO_CONTEXT_CANPLAY_CHANGED @"CanPlayChanged"
#define KVO_CONTEXT_COMMONAUTHOR_CHANGED @"CommonAuthorChanged"
#define KVO_CONTEXT_COMMONALBUM_CHANGED @"CommonAlbumChanged"

#ifdef APP_STORE_BUILD
extern BOOL requiresUpdateHack;
#endif

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

@interface AudioBinderWindowController ()

@end

@implementation AudioBinderWindowController

@synthesize validBitrates, canPlay;

- (id)initWithWindow:(NSWindow *)window
{
    self = [super initWithWindow:window];
    if (self) {
    }
    
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    [fileListView setDataSource:fileList];
    [fileListView setDelegate:fileList];
    [fileListView setAllowsMultipleSelection:YES];
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
    _destURL = nil;
    _totalBookProgress = 0;
    _totalBookDuration = 0;
    _currentFileProgress = 0;
    
    [fileList addObserver:self
        forKeyPath:@"canPlay"
           options:0
           context:KVO_CONTEXT_CANPLAY_CHANGED];

    [fileList addObserver:self
               forKeyPath:@"commonAuthor"
                  options:0
                  context:KVO_CONTEXT_COMMONAUTHOR_CHANGED];
    [fileList addObserver:self
               forKeyPath:@"commonAlbum"
                  options:0
                  context:KVO_CONTEXT_COMMONALBUM_CHANGED];

    [self updateWindowTitle];
    [self setupColumns];
    [self setupGenres];
}

- (void)setupColumns {
    int idx;
    // build table header context menu
    NSArray *cols = [[NSUserDefaults standardUserDefaults] arrayForKey:ColumnsConfiguration];
    // default case, add Name and Time columns
    if (cols == nil) {
        NSArray *tableColumns = [NSArray arrayWithArray:[fileListView tableColumns]];
        NSTableColumn *column = [tableColumns objectAtIndex:0];
        [column setIdentifier:COLUMNID_NAME];
        column = [[NSTableColumn alloc] initWithIdentifier:COLUMNID_TIME];
        
        [fileListView addTableColumn:column];
        [column setWidth:150];
    }
    else
    {
        // load from saved state
        NSDictionary *colinfo;
        NSTableColumn *column;
        NSArray *tableColumns = [NSArray arrayWithArray:[fileListView tableColumns]];
        
        idx = 0;
        for (colinfo in cols) {
            NSString *identifier = [colinfo objectForKey:@"identifier"];
            CGFloat width = [[colinfo objectForKey:@"width"] floatValue];
            if (idx == 0) {
                column = [tableColumns objectAtIndex:0];
                [column setIdentifier:identifier];
                [column setWidth:width];
            }
            else {
                column = [[NSTableColumn alloc] initWithIdentifier:identifier];
                [column setWidth:width];
                [fileListView addTableColumn:column];
            }
            
            idx++;
        }
        
    }

    // build table header context menu
    NSMenu *tableHeaderContextMenu = [[NSMenu alloc] initWithTitle:@""];
    [[fileListView headerView] setMenu:tableHeaderContextMenu];
    
    NSArray *columns = [fileListView tableColumns];
    
    for (NSTableColumn *c in columns) {
        BOOL found = NO;
        for (idx = 0; columnDefs[idx].id; idx++)
        {
            if ([columnDefs[idx].id isEqualToString:c.identifier]) {
                columnDefs[idx].enabled = YES;
                [[c headerCell] setStringValue:NSLocalizedString(columnDefs[idx].title, nil)];
                found = YES;
                break;
            }
        }
        // Name column is special. It can't be removed from view
        if (!found && ([c.identifier isEqualToString:COLUMNID_NAME])) {
            [[c headerCell] setStringValue:NSLocalizedString(@"Name", nil)];
            // make sure outline column is NameColumn
            [fileListView setOutlineTableColumn:c];
        }
    }

    
    for (idx = 0; columnDefs[idx].id; idx++)
    {
        NSString *title = NSLocalizedString(columnDefs[idx].title, nil);
        NSMenuItem *item = [tableHeaderContextMenu addItemWithTitle:title action:@selector(contextMenuSelected:) keyEquivalent:@""];
        [item setTarget:self];
        [item setRepresentedObject:columnDefs[idx].id];
        [item setState:columnDefs[idx].enabled?NSOnState:NSOffState];
    }
    
    
    // listen for changes so know when to save
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(saveTableColumns) name:NSOutlineViewColumnDidMoveNotification object:fileListView];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(saveTableColumns) name:NSOutlineViewColumnDidResizeNotification object:fileListView];
    
    // [self.window setFrameAutosaveName:@"AudioBookbinderWindow"];  // Specify the autosave name for the window.
}

- (void) setupGenres {
    [genresField setStringValue:TEXT_AUDIOBOOKS];
    knownGenres = [[NSMutableArray alloc] initWithObjects:@"Art",
                   @"Biography",
                   @"Business",
                   @"Chick Lit",
                   @"Children's",
                   @"Christian",
                   @"Classics",
                   @"Comics",
                   @"Contemporary",
                   @"Cookbooks",
                   @"Crime",
                   @"Ebooks",
                   @"Fantasy",
                   @"Fiction",
                   @"Gay And Lesbian",
                   @"Historical Fiction",
                   @"History",
                   @"Horror",
                   @"Humor And Comedy",
                   @"Memoir",
                   @"Music",
                   @"Mystery",
                   @"Non Fiction",
                   @"Paranormal",
                   @"Philosophy",
                   @"Poetry",
                   @"Psychology",
                   @"Religion",
                   @"Romance",
                   @"Science",
                   @"Science Fiction",
                   @"Self Help",
                   @"Suspense",
                   @"Spirituality",
                   @"Sports",
                   @"Thriller",
                   @"Travel",
                   @"Young Adult",
                   nil];
    [genresButton removeAllItems];
    [genresButton addItemsWithTitles:knownGenres];
#ifdef notyet
    [[genresButton menu] addItem:[NSMenuItem separatorItem]];
    [genresButton addItemWithTitle:@"Edit genres"];
    [[genresButton lastItem] setTag:-1];
#endif
    [genresButton setTarget:self];
    [genresButton setAction:@selector(genresButtonChanged:)];
    
    autocompleting = NO;
    [genresField setDelegate:self];
}

- (void)saveTableColumns {
    NSMutableArray *cols = [NSMutableArray array];
    NSEnumerator *enumerator = [[fileListView tableColumns] objectEnumerator];
    NSTableColumn *column;
    while((column = [enumerator nextObject])) {
        [cols addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                         [column identifier], @"identifier",
                         [NSNumber numberWithFloat:[column width]], @"width",
                         nil]];
    }
    [[NSUserDefaults standardUserDefaults] setObject:cols forKey:ColumnsConfiguration];
}

- (IBAction) addFiles: (id)sender
{
    int i; // Loop counter.
    
    // Create the File Open Dialog class.
    NSOpenPanel *openDlg = [NSOpenPanel openPanel];
    
    [openDlg setCanChooseFiles:YES];
    [openDlg setCanChooseDirectories:YES];
    [openDlg setAllowsMultipleSelection:YES];
    
    BOOL tryGuess = ![fileList hasFiles];
    
    if ( [openDlg runModalForDirectory:nil file:nil] == NSOKButton )
    {
        BOOL sortFiles = [[NSUserDefaults standardUserDefaults] boolForKey:@"SortAudioFiles"];
        NSArray *files = [[openDlg filenames] sortedArrayUsingComparator:^(id a, id b) {return [a compare:b];}];
        
        if (sortFiles)
            files = [[openDlg filenames] sortedArrayUsingComparator:^(id a, id b) {return [a compare:b];}];
        else
            files = [openDlg filenames];
        
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
        if (tryGuess)
        {
			[self updateGuiWithGuessedData];
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
    
#ifdef APP_STORE_BUILD
    saveAsFilename.stringValue = filename;
    [NSApp beginSheet:saveAsPanel modalForWindow:self.window
        modalDelegate:self didEndSelector:NULL contextInfo:nil];
#else
    NSSavePanel *savePanel = [NSSavePanel savePanel];
    [savePanel setAccessoryView: nil];
    // [savePanel setAllowedFileTypes:[NSArray arrayWithObjects:@"m4a", @"m4b", nil]];
    NSString *dir = [[NSUserDefaults standardUserDefaults] stringForKey:@"DestinationFolder"];
    
    choice = [savePanel runModalForDirectory:dir file:filename];
    
    [filename release];
    
    /* if successful, save file under designated name */
    if (choice == NSOKButton)
    {
        [bindButton setEnabled:FALSE];
        outFile = [[savePanel filename] retain];
        
        [NSThread detachNewThreadSelector:@selector(bindToFileThread:) toTarget:self withObject:nil];
    }
    
#endif
}


- (IBAction) saveAsOk:(id)sender
{
    [NSApp endSheet:saveAsPanel];
    [saveAsPanel orderOut:nil];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *destPath;
    _destURL = [[NSURL URLByResolvingBookmarkData:[defaults objectForKey:@"DestinationFolderBookmark"] options:NSURLBookmarkResolutionWithSecurityScope relativeToURL:nil bookmarkDataIsStale:nil error:nil] retain];
    if (_destURL == nil) {
#ifdef APP_STORE_BUILD
        if (requiresUpdateHack) {
            NSString *currentDest = [defaults stringForKey:@"DestinationFolder"];
            NSOpenPanel * panel = [NSOpenPanel openPanel];
            
            [panel setPrompt: NSLocalizedString(@"Select", nil)];
            [panel setAllowsMultipleSelection: NO];
            [panel setCanChooseFiles: NO];
            [panel setCanChooseDirectories: YES];
            [panel setCanCreateDirectories: YES];
            [panel setDirectoryURL:[NSURL fileURLWithPath:currentDest]];
            NSInteger result = [panel runModal];
            if (result == NSOKButton)
            {
                _destURL = [panel URL];
                destPath = [_destURL path];
                
            }
            else
                return;
        }
        else
            destPath = [defaults stringForKey:@"DestinationFolder"];
#else
        // standard Music directory
        destPath = [defaults stringForKey:@"DestinationFolder"];
#endif
    }
    else {
        destPath = [_destURL path];
        [_destURL startAccessingSecurityScopedResource];
    }
    
    outFile = [[destPath stringByAppendingPathComponent:[saveAsFilename stringValue]] retain];
    if ([[NSFileManager defaultManager] fileExistsAtPath:outFile]) {
        NSAlert *a = [[NSAlert alloc] init];
        [a addButtonWithTitle:TEXT_OVERWRITE];
        [a addButtonWithTitle:TEXT_CANCEL];
        
        [a setMessageText:TEXT_FILE_EXISTS];
        [a setAlertStyle:NSWarningAlertStyle];
        [a setInformativeText: [NSString stringWithFormat:TEXT_FILE_OVERWRITE, outFile]];
        NSInteger result = [a runModal];
        if (result == NSAlertSecondButtonReturn) {
            return;
        }
    }
    
    [bindButton setEnabled:FALSE];
    [NSThread detachNewThreadSelector:@selector(bindToFileThread:) toTarget:self withObject:nil];
}

- (IBAction) saveAsCancel:(id)sender
{
    
    [NSApp endSheet:saveAsPanel];
    [saveAsPanel orderOut:nil];
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

- (IBAction) toggleChapters: (id)sender
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

- (IBAction) resetToDefaults: (id)sender
{
    [[form cellAtIndex:ABBAuthor] setStringValue:@""];
    [[form cellAtIndex:ABBTitle] setStringValue:@""];
    [genresField setStringValue:@"Audiobooks"];
    [fileList removeAllFiles:fileListView];
    [coverImageView resetImage];
}

- (void) bindingThreadIsDone:(id)sender
{
#ifdef APP_STORE_BUILD
    if (_destURL) {
        [_destURL startAccessingSecurityScopedResource];
        [_destURL release];
        _destURL = nil;
    }
#endif
    
    BOOL notificationCenterIsAvailable = (NSClassFromString(@"NSUserNotificationCenter")!=nil);
    if (_conversionResult && notificationCenterIsAvailable) {
        NSUserNotification *notification = [[NSUserNotification alloc] init];
        notification.title = TEXT_BOOK_IS_READY;
        notification.subtitle = [outFile lastPathComponent];
        notification.soundName = NSUserNotificationDefaultSoundName;
        
        [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
    }
    
    [bindButton setEnabled:TRUE];
}

- (void)bindToFileThread:(id)object
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    NSString *author = [[form cellAtIndex:ABBAuthor] stringValue];
    NSString *title = [[form cellAtIndex:ABBTitle] stringValue];
    NSString *genre = [genresField stringValue];
    NSString *coverImageFilename = nil;
    NSImage *coverImage = coverImageView.coverImage;
    UInt64 maxVolumeDuration = 0;
    NSInteger hours = [[NSUserDefaults standardUserDefaults] integerForKey:@"MaxVolumeSize"];
    if ((hours > 0) && (hours < 25))
        maxVolumeDuration = hours * 3600;
    
    NSLog(@"maxVolumeDuration == %lld", maxVolumeDuration);
    _conversionResult = NO;
    [_binder reset];
    [_binder setDelegate:self];
    
    // split output filename to base and extension in order to get
    // filenames for consecutive volume files
    NSString *outFileBase = [[outFile stringByDeletingPathExtension] retain];
    NSString *outFileExt = [[outFile pathExtension] retain];
    
    NSArray *files = [fileList files];
    NSMutableArray *inputFiles = [[NSMutableArray alloc] init];
    UInt64 estVolumeDuration = 0;
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
    _currentFileProgress = 0;
    _totalBookDuration = 0;
    _totalBookProgress = 0;
    self.currentProgress = 0;

    [[StatsManager sharedInstance] updateConverter:self];
    
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
            if ((estVolumeDuration + [file.duration intValue]) > maxVolumeDuration*1000) {
                if ([inputFiles count] > 0) {
                    [_binder addVolume:currentVolumeName files:inputFiles];
                    [inputFiles removeAllObjects];
                    estVolumeDuration = 0;
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
                                     [file.filePath UTF8String], [file.duration intValue]/1000, maxVolumeDuration];
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
        estVolumeDuration += [file.duration intValue];
        _totalBookDuration += [file.duration intValue];
    }
    
    [_binder addVolume:currentVolumeName files:inputFiles];
    [volumeChapters addObject:curChapters];
    
    // make sure that at this point we have valid bitrate in settings
    [self fixupBitrate];
    // setup channels/samplerate
    
    _binder.channels = [[NSUserDefaults standardUserDefaults] integerForKey:@"Channels"];
    _binder.sampleRate = [[NSUserDefaults standardUserDefaults] floatForKey:@"SampleRate"];
    _binder.bitrate = [[NSUserDefaults standardUserDefaults] integerForKey:@"Bitrate"];
    
    [NSApp beginSheet:progressPanel modalForWindow:self.window
        modalDelegate:self didEndSelector:NULL contextInfo:nil];
    
    [fileProgress setMaxValue:100.];
    [fileProgress setDoubleValue:0.];
    [fileProgress displayIfNeeded];
    if (!(_conversionResult = [_binder convert]))
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
                    mp4.genre = genre;
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
                    [[NSFileManager defaultManager] removeItemAtPath:coverImageFilename
                                                               error:nil];
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
    [[StatsManager sharedInstance] removeConverter:self];
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

- (void)recalculateProgress
{
    NSUInteger newProgress = 0;
    if (_totalBookDuration > 0)
        newProgress = floor((_currentFileProgress + _totalBookProgress)*100./_totalBookDuration);
    if (newProgress != self.currentProgress) {
        self.currentProgress = newProgress;
        [[StatsManager sharedInstance] updateConverter:self];
    }
}

-(void) updateStatus: (AudioFile *)file handled:(UInt64)handledFrames total:(UInt64)totalFrames
{
    [fileProgress setMaxValue:(double)totalFrames];
    [fileProgress setDoubleValue:(double)handledFrames];
    if (totalFrames > 0) {
        _currentFileProgress = [file.duration intValue]*handledFrames/totalFrames;
        [self recalculateProgress];
    }
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
    file.duration = [[NSNumber alloc] initWithInt:milliseconds];
    if (_totalBookDuration > 0) {
        _totalBookProgress += [file.duration intValue];
        _currentFileProgress = 0;
        [self recalculateProgress];
    }
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
            [[c headerCell] setStringValue:NSLocalizedString(columnDefs[idx].title, nil)];
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

- (IBAction) genresButtonChanged: (id)sender
{
    
    [genresField setStringValue:[[genresButton selectedItem] title]];
}

- (void) controlTextDidChange: (NSNotification *)genre {
#ifdef notyet
    if (!autocompleting) {
        NSTextView * fieldEditor = [[genre userInfo] objectForKey:@"NSFieldEditor"];
        autocompleting = YES;
        [fieldEditor complete:nil];
        autocompleting = NO;
        NSLog(@"Did change %@", fieldEditor);
    }
#endif
}

- (NSArray *)control:(NSControl *)control textView:(NSTextView *)textView completions:(NSArray *)words forPartialWordRange:(NSRange)charRange indexOfSelectedItem:(NSInteger *)index
{
    NSMutableArray *genres = [NSMutableArray arrayWithCapacity:[knownGenres count]];
    
    for (NSString *g in knownGenres) {
        if([g compare:[textView string] options:NSCaseInsensitiveSearch range:charRange] == NSOrderedSame) {
            [genres addObject:g];
        }
    }
    *index = 0;
    
    return genres;
}


//whenever an observed key path changes, this method will be called
- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context;
{
    //use the context to make sure this is a change in the address,
    //because we may also be observing other things
    if(context == KVO_CONTEXT_CANPLAY_CHANGED){
        if (_sound == nil) {
            [playButton setEnabled:fileList.canPlay];
        }
        
        self.canPlay = fileList.canPlay;
    }
    else if (context == KVO_CONTEXT_COMMONAUTHOR_CHANGED) {
        NSString *author = [[form cellAtIndex:ABBAuthor] stringValue];
        if ([author isEqualTo:@""] || (author == nil))
        {
            NSString *guessedAuthor = [fileList commonAuthor];
            if ((guessedAuthor != nil) && !([guessedAuthor isEqualToString:@""]))
                [[form cellAtIndex:ABBAuthor] setStringValue:guessedAuthor];
        }    }
    else if (context == KVO_CONTEXT_COMMONALBUM_CHANGED) {
        NSString *title = [[form cellAtIndex:ABBTitle] stringValue];
        if ([title isEqualTo:@""] || (title == nil))
        {
            NSString *guessedTitle = [fileList commonAlbum];
            if ((guessedTitle != nil) && !([guessedTitle isEqualToString:@""]))
                [[form cellAtIndex:ABBTitle] setStringValue:guessedTitle];
        }
    }
}

- (void)updateWindowTitle
{
    NSString *author = [[[form cellAtIndex:ABBAuthor] stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    NSString *title = [[[form cellAtIndex:ABBTitle] stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if (([author length] == 0) && ([title length] == 0))
    {
        [self.window setTitle:TEXT_AUDIOBOOK];
    }
    else {
        NSString *winTitle = [NSString stringWithFormat:@"%@ - %@", title, author];
        [self.window setTitle:winTitle];
    }
}

-(BOOL)control:(NSControl *)control textShouldEndEditing:(NSText *)fieldEditor {
    if (control == form) {
        [self updateWindowTitle];
    }

    return YES;
}

- (NSUInteger) totalBookProgress {
    return _currentFileProgress + _totalBookProgress;
}



- (IBAction)folderSheetShow: (id) sender
{
    NSOpenPanel * panel = [NSOpenPanel openPanel];
    
    [panel setPrompt: NSLocalizedString(@"Select", "Preferences -> Open panel prompt")];
    [panel setAllowsMultipleSelection: NO];
    [panel setCanChooseFiles: NO];
    [panel setCanChooseDirectories: YES];
    [panel setCanCreateDirectories: YES];
    [panel beginSheetModalForWindow:saveAsPanel completionHandler:^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton) {
#ifdef APP_STORE_BUILD
            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

            NSURL *folderURL = [panel URL];
            NSData* data = [folderURL bookmarkDataWithOptions:NSURLBookmarkCreationWithSecurityScope includingResourceValuesForKeys:nil relativeToURL:nil error:nil];
            [defaults setObject:data forKey: @"DestinationFolderBookmark"];
            // Menu item is bound to DestinationFolder key so let AppStore
            // build set it as well
#endif
            NSString * folder = [[panel filenames] objectAtIndex:0];
            [defaults setObject:folder forKey: @"DestinationFolder"];
        }
        [saveAsFolderPopUp selectItemAtIndex:0];

    }];
}

@end
