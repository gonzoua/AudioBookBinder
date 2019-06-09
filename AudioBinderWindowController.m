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

#import "AudioBinder.h"
#import "AudioBookVolume.h"
#import "AudioBookVolume.h"
#import "AudioBinderWindowController.h"
#import "AudioBookBinderAppDelegate.h"
#import "AudioFile.h"
#import "Chapter.h"
#import "Chapter.h"
#import "ConfigNames.h"
#import "ExpandedPathToIconTransformer.h"
#import "ExpandedPathToPathTransformer.h"
#import "MP4File.h"
#import "MetaEditor.h"
#import "NSOutlineView_Extension.h"
#import "StatsManager.h"
#import "QueueController.h"

#import <QuartzCore/QuartzCore.h>

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
#define TEXT_BOOK_IS_READY      NSLocalizedString(@"Audiobook is ready", @"")

#define ColumnsConfiguration                @"ColumnsConfiguration"

#define KVO_CONTEXT_CANPLAY_CHANGED         @"CanPlayChanged"
#define KVO_CONTEXT_HASFILES_CHANGED        @"HasFilesChanged"
#define KVO_CONTEXT_COMMONAUTHOR_CHANGED    @"CommonAuthorChanged"
#define KVO_CONTEXT_COMMONALBUM_CHANGED     @"CommonAlbumChanged"

#ifdef APP_STORE_BUILD
extern BOOL requiresUpdateHack;
#endif

typedef struct 
{
    __unsafe_unretained NSString *id;
    __unsafe_unretained NSString *title;
    BOOL enabled;
} column_t;

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

@interface AudioBinderWindowController () {
    NSURL *_destURL;
    NSMutableArray *knownGenres;
    BOOL autocompleting;
    BOOL _playing;
    NSString *outFile;
    AudioBinder *_binder;
    NSSound *_sound;
    NSString *_playingFile;
    NSImage *_playImg, *_stopImg;
    BOOL _conversionResult;
    AudioFileList *fileList;
    // QueueOverlayView *_queueOverlay;
    
    NSMutableArray *currentColumns;

    NSUInteger _currentFileProgress;
    NSUInteger _totalBookProgress;
    NSUInteger _totalBookDuration;
    BOOL _converting;
    BOOL _enqueued;
}

- (void)playFailed;
- (void)sound:(NSSound *)sound didFinishPlaying:(BOOL)finishedPlaying;

@end

@implementation AudioBinderWindowController

- (id)initWithWindow:(NSWindow *)window
{
    self = [super initWithWindow:window];

    if (self) {
        [self updateWindowTitle];
    }
    
    return self;
}

- (void)dealloc
{
    [fileList removeObserver:self forKeyPath:@"hasFiles"];
    [fileList removeObserver:self forKeyPath:@"canPlay"];
    [fileList removeObserver:self forKeyPath:@"commonAuthor"];
    [fileList removeObserver:self forKeyPath:@"commonAlbum"];
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    fileList = [[AudioFileList alloc] init];
    [fileListView setDataSource:fileList];
    [fileListView setDelegate:fileList];
    [fileListView setAllowsMultipleSelection:YES];
    [fileListView registerForDraggedTypes:[NSArray arrayWithObjects:NSStringPboardType, NSFilenamesPboardType, nil]];
    [fileListView setDraggingSourceOperationMask:NSDragOperationEvery forLocal:YES];
    [fileListView setDraggingSourceOperationMask:NSDragOperationCopy forLocal:NO];
    [fileListView setAutoresizesOutlineColumn:NO];
    // expand initial chapter if chapter mode is enabled
    [fileListView expandItem:nil expandChildren:YES];
    
    _binder = [[AudioBinder alloc] init];
    _playing = NO;
    _converting = NO;
    _enqueued = NO;
    NSString* img = [[NSBundle mainBundle] pathForResource:@"Play" ofType:@"png"];
    NSURL* url = [NSURL fileURLWithPath:img];
    _playImg = [[NSImage alloc] initWithContentsOfURL:url];
    img = [[NSBundle mainBundle] pathForResource:@"Stop" ofType:@"png"];
    url = [NSURL fileURLWithPath:img];
    _stopImg = [[NSImage alloc] initWithContentsOfURL:url];
    
    [playButton setImage:_playImg] ;
    [playButton setEnabled:NO];
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
        forKeyPath:@"hasFiles"
           options:0
           context:KVO_CONTEXT_HASFILES_CHANGED];
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
    [bindButton setEnabled:FALSE];
    
    AudioBookBinderAppDelegate *delegate = [[NSApplication sharedApplication] delegate];
    [self.window setDelegate:delegate];
    
    // _queueOverlay = [[QueueOverlayView alloc] init];
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
    // Create the File Open Dialog class.
    NSOpenPanel *openDlg = [NSOpenPanel openPanel];
    
    [openDlg setCanChooseFiles:YES];
    [openDlg setCanChooseDirectories:YES];
    [openDlg setAllowsMultipleSelection:YES];

    if ( [openDlg runModal] == NSOKButton )
    {
        BOOL sortFiles = [[NSUserDefaults standardUserDefaults] boolForKey:kConfigSortAudioFiles];
        NSArray *urls;
        
        if (sortFiles)
            urls = [[openDlg URLs] sortedArrayUsingComparator:^(id a, id b) {return [[a path] compare:[b path]];}];
        else
            urls = [openDlg URLs];
        
        for(NSURL *url in urls)
        {
            NSString* fileName = [url path];
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
    NSString *author = [authorField stringValue];
    NSString *title = [titleField stringValue];
    NSMutableString *filename = [NSMutableString string];
    
    if (![author isEqualToString:@""])
        [filename appendString:
            [[author stringByReplacingOccurrencesOfString:@"/" withString:@" "]  stringByReplacingOccurrencesOfString:@":" withString:@" -"]];
    
    if (![title isEqualToString:@""]) {
        if (![filename isEqualToString:@""])
            [filename appendString:@" - "];
        
        [filename appendString:
            [[title stringByReplacingOccurrencesOfString:@"/" withString:@" "] stringByReplacingOccurrencesOfString:@":" withString:@" -"]];
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
    NSString *dir = [[NSUserDefaults standardUserDefaults] stringForKey:kConfigDestinationFolder];
    
    [savePanel setDirectoryURL:[NSURL fileURLWithPath:dir]];
    [savePanel setNameFieldStringValue:filename];
    NSInteger choice = [savePanel runModal];
    
    
    /* if successful, save file under designated name */
    if (choice == NSOKButton)
    {
        [bindButton setEnabled:FALSE];
        outFile = [[savePanel URL] path];
        _converting = YES;
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
    _destURL = [NSURL URLByResolvingBookmarkData:[defaults objectForKey:kConfigDestinationFolderBookmark] options:NSURLBookmarkResolutionWithSecurityScope relativeToURL:nil bookmarkDataIsStale:nil error:nil];
    if (_destURL == nil) {
#ifdef APP_STORE_BUILD
        if (requiresUpdateHack) {
            NSString *currentDest = [defaults stringForKey:kConfigDestinationFolder];
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
            destPath = [defaults stringForKey:kConfigDestinationFolder];
#else
        // standard Music directory
        destPath = [defaults stringForKey:kConfigDestinationFolder];
#endif
    }
    else {
        destPath = [_destURL path];
        [_destURL startAccessingSecurityScopedResource];
    }
    
    outFile = [destPath stringByAppendingPathComponent:[saveAsFilename stringValue]];
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
    _converting = YES;
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
    
    if ( [openDlg runModal] == NSOKButton )
    {
        NSURL *url = [openDlg URL];
        
        NSString* fileName = [url path];
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
    [authorField setStringValue:@""];
    [titleField setStringValue:@""];
    [actorField setStringValue:@""];
    [genresField setStringValue:@"Audiobooks"];
    [fileList removeAllFiles:fileListView];
    [coverImageView resetImage];
}

- (void) bindingThreadIsDone:(id)sender
{
    _converting = NO;
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

- (void) showProgressPanel: (id) sender
{
    [NSApp beginSheet:progressPanel modalForWindow:self.window
        modalDelegate:self didEndSelector:NULL contextInfo:nil];
}

- (void) hideProgressPanel: (id) sender
{
    [NSApp endSheet:progressPanel];
    [progressPanel orderOut:nil];
}

- (void)bindToFileThread:(id)object
{
    NSString *coverImageFilename = nil;
    NSImage *coverImage = coverImageView.coverImage;
    UInt64 maxVolumeDuration = 0;
    NSInteger hours = [[NSUserDefaults standardUserDefaults] integerForKey:kConfigMaxVolumeSize];
    if ((hours > 0) && (hours < 25))
        maxVolumeDuration = hours * 3600;
    
    NSLog(@"maxVolumeDuration == %lld", maxVolumeDuration);
    _conversionResult = NO;
    [_binder reset];
    [_binder setDelegate:self];
    
    // split output filename to base and extension in order to get
    // filenames for consecutive volume files
    NSString *outFileBase = [outFile stringByDeletingPathExtension];
    NSString *outFileExt = [outFile pathExtension];
    
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
                    NSAlert *alert = [[NSAlert alloc] init];
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
    // setup channels/samplerate
    
    _binder.channels = [[NSUserDefaults standardUserDefaults] integerForKey:kConfigChannels];
    _binder.sampleRate = [[NSUserDefaults standardUserDefaults] floatForKey:kConfigSampleRate];
    _binder.bitrate = [[NSUserDefaults standardUserDefaults] integerForKey:kConfigBitrate];
    
    [self performSelectorOnMainThread:@selector(showProgressPanel:) withObject:nil waitUntilDone:NO];

    [fileProgress setMaxValue:100.];
    [fileProgress setDoubleValue:0.];
    [fileProgress displayIfNeeded];
    if (!(_conversionResult = [_binder convert]))
    {
        NSLog(@"Conversion failed");
    }
    
    else
    {
        if (![self.author isEqualToString:@""] ||
            ![self.title isEqualToString:@""] || (coverImage != nil))
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
                for (AudioBookVolume *v in volumes) {
                    NSString *volumeName = v.filename;
                    MP4File *mp4 = [[MP4File alloc] initWithFileName:volumeName];
                    mp4.artist = self.author;
                    if ([volumes count] > 1) {
                        mp4.title = [NSString stringWithFormat:@"%@ #%02d", self.title, track];
                        mp4.gaplessPlay = YES;
                    }
                    else
                        mp4.title = self.title;
                    mp4.albumArtist = self.actor;
                    mp4.album = self.title;
                    mp4.genre = self.genre;
                    if (coverImageFilename)
                        [mp4 setCoverFile:coverImageFilename];
                    mp4.track = track;
                    mp4.tracksTotal = [volumes count];
                    [mp4 updateFile];
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
                    for (AudioBookVolume *v in volumes) {
                        addChapters([v.filename UTF8String], [volumeChapters objectAtIndex:idx]);
                        idx++;
                    }
                    
                }
                
                if ([[NSUserDefaults standardUserDefaults] boolForKey:kConfigAddToITunes]) {
                    
                    [currentFile setStringValue:TEXT_ADDING_TO_ITUNES];
                    for(AudioBookVolume *volume in volumes)
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

    [[StatsManager sharedInstance] removeConverter:self];
       [self performSelectorOnMainThread:@selector(hideProgressPanel:) withObject:nil waitUntilDone:NO];
    [self performSelectorOnMainThread:@selector(bindingThreadIsDone:) withObject:nil waitUntilDone:NO];
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
    
    NSAlert *alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle:@"OK"];
    [alert setMessageText:TEXT_CONVERSION_FAILED];
    [alert setInformativeText:reason];
    [alert setAlertStyle:NSWarningAlertStyle];
    [alert runModal];
    return NO;
}

-(void) volumeFailed:(NSString*)filename reason:(NSString*)reason
{
    
    NSAlert *alert = [[NSAlert alloc] init];
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
        
        _playingFile = [file.filePath copy];
        _sound = [[NSSound alloc] initWithContentsOfFile:file.filePath byReference:NO];
        [_sound setDelegate:self];
        if (![_sound play]) {
            [playButton setImage:_playImg] ;
            _sound = nil;
            [playButton setEnabled:fileList.canPlay];
            [self playFailed];
        }
    }
}

- (void)sound:(NSSound *)sound didFinishPlaying:(BOOL)finishedPlaying
{
    [playButton setImage:_playImg] ;
    _sound = nil;
    [playButton setEnabled:fileList.canPlay];
}

- (void) playFailed
{
    NSAlert *alert = [[NSAlert alloc] init];
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
    }
    else if(context == KVO_CONTEXT_HASFILES_CHANGED){
        [bindButton setEnabled:fileList.hasFiles];
    }
    else if (context == KVO_CONTEXT_COMMONAUTHOR_CHANGED) {
        NSString *author = [authorField stringValue];
        if ([author isEqualTo:@""] || (author == nil))
        {
            NSString *guessedAuthor = [fileList commonAuthor];
            if ((guessedAuthor != nil) && !([guessedAuthor isEqualToString:@""]))
                [authorField setStringValue:guessedAuthor];
        }
        [self updateWindowTitle];
    }
    else if (context == KVO_CONTEXT_COMMONALBUM_CHANGED) {
        NSString *title = [titleField stringValue];

        if ([title isEqualTo:@""] || (title == nil))
        {
            NSString *guessedTitle = [fileList commonAlbum];

            if ((guessedTitle != nil) && !([guessedTitle isEqualToString:@""]))
                [titleField setStringValue:guessedTitle];
        }
        [self updateWindowTitle];
    }
}

- (void)updateWindowTitle
{
    self.author = [[authorField stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    self.title = [[titleField stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    self.actor = [[actorField stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    self.genre = [[genresField stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    
    self.windowTitle = nil;
    NSString *title;
    
    if (([self.author length] == 0) && ([self.title length] == 0))
    {
        title = TEXT_AUDIOBOOK;
    }
    else {
        title = [NSString stringWithFormat:@"%@ - %@", self.title, self.author];
    }
    
    if (_enqueued)
        title = [NSString stringWithFormat:@"[QUEUED] %@", title];
    self.windowTitle = title;
    
    // do not update if it hasn't been changed
    if (![self.windowTitle isEqualToString:self.window.title])
        [self.window setTitle:self.windowTitle];

}

-(BOOL)control:(NSControl *)control textShouldEndEditing:(NSText *)fieldEditor {
    if ((control == authorField) || (control == titleField) || (control == actorField)) {
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
            NSURL *folderURL = [panel URL];
            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

#ifdef APP_STORE_BUILD

            NSData* data = [folderURL bookmarkDataWithOptions:NSURLBookmarkCreationWithSecurityScope includingResourceValuesForKeys:nil relativeToURL:nil error:nil];
            [defaults setObject:data forKey:kConfigDestinationFolderBookmark];
            // Menu item is bound to DestinationFolder key so let AppStore
            // build set it as well
#endif
            NSString * folder = [folderURL path];
            [defaults setObject:folder forKey:kConfigDestinationFolder];
        }
        [saveAsFolderPopUp selectItemAtIndex:0];

    }];
}

- (IBAction) toggleQueue: (id)sender
{
    AudioBookBinderAppDelegate *delegate = [[NSApplication sharedApplication] delegate];

    _enqueued = !_enqueued;
    if (_enqueued) {
        [delegate.queueController addBookWindowController:self];
        // [_queueOverlay setFrame:self.window.contentView.frame];
        // [self.window.contentView addSubview:_queueOverlay positioned:NSWindowAbove relativeTo:nil];
        // [_queueOverlay becomeFirstResponder];
    }
    else {
        // [_queueOverlay removeFromSuperview];
        [delegate.queueController removeBookWindowController:self];
    }
    [self updateWindowTitle];
}

@end
