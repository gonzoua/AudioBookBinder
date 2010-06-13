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

// localized strings
#define TEXT_CONVERSION_FAILED  \
    NSLocalizedString(@"Audiofile conversion failed", nil)
#define TEXT_BINDING_FAILED     \
    NSLocalizedString(@"Audiobook binding failed", nil)
#define TEXT_ADDING_TAGS        \
    NSLocalizedString(@"Adding artist/title tags", nil)
#define TEXT_ADDING_TO_ITUNES   \
    NSLocalizedString(@"Adding file to iTunes", nil)
#define TEXT_CONVERTING         \
    NSLocalizedString(@"Converting %@", nil)

enum abb_form_fields {
    ABBAuthor = 0,
    ABBTitle,
};

@implementation AudioBookBinderAppDelegate

+ (void) initialize
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSMutableDictionary *appDefaults = [NSMutableDictionary
                                        dictionaryWithObject:[NSNumber numberWithInt:1] forKey:@"Channels"];
    // for checkbox "add to itunes"
    [appDefaults setObject:[NSNumber numberWithBool:YES] forKey:@"AddToiTunes"];
    [appDefaults setObject:@"44100" forKey:@"SampleRate"];
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

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    [fileListView setDataSource:fileList];
    [fileListView setDelegate:fileList];
    [fileListView setAllowsMultipleSelection:YES];
    
    [fileListView registerForDraggedTypes:[NSArray arrayWithObjects:NSStringPboardType, NSFilenamesPboardType, nil]];
    [fileListView setDraggingSourceOperationMask:NSDragOperationEvery forLocal:YES];
    [fileListView setDraggingSourceOperationMask:NSDragOperationCopy forLocal:NO];
    [fileListView setAutoresizesOutlineColumn:NO];
    
    
    _binder = [[[AudioBinder alloc] init] retain];
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
                NSImage *img = [[NSImage alloc] initWithContentsOfFile:fileName]; 
                coverImageView.coverImage = img;
                [img release];
                [tabs selectTabViewItemAtIndex:1];
            }
        }
        
        [fileListView reloadData];
    }    
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
    NSImage *coverImage = coverImageView.coverImage;

    [_binder reset];
    [_binder setDelegate:self];
    [_binder setOutputFile:outFile];
    
    NSArray *files = [fileList files];
    for (AudioFile *file in files) 
        [_binder addInputFile:file];
    
    
    // setup channels/samplerate
    _binder.channels = [[NSUserDefaults standardUserDefaults] integerForKey:@"Channels"];
    _binder.sampleRate = [[NSUserDefaults standardUserDefaults] floatForKey:@"SampleRate"];

    [NSApp beginSheet:progressPanel modalForWindow:window
        modalDelegate:self didEndSelector:NULL contextInfo:nil];    
    
    [fileProgress setMaxValue:100.];
    [fileProgress setDoubleValue:0.]; 
    [fileProgress displayIfNeeded];
    if (![_binder convert])
    {
        NSLog(@"Conversion failed");
    }        
    
    else if (![author isEqualToString:@""] || 
             ![title isEqualToString:@""] || (coverImage != nil))
    {
        NSLog(@"Adding metadata, it may take a while...");
        @try {
            [currentFile setStringValue:TEXT_ADDING_TAGS];
            
            MP4File *mp4 = [[MP4File alloc] initWithFileName:outFile];
            [mp4 setArtist:author]; 
            [mp4 setTitle:title];
            NSString *imgFileName = nil;
            if (coverImage) 
            {
                NSString *tempFileTemplate =
                [NSTemporaryDirectory() stringByAppendingPathComponent:@"coverimg.XXXXXX"];
                const char *tempFileTemplateCString =
                    [tempFileTemplate fileSystemRepresentation];
                char *tempFileNameCString = (char *)malloc(strlen(tempFileTemplateCString) + 1);
                strcpy(tempFileNameCString, tempFileTemplateCString);
                if (mktemp(tempFileNameCString)) {
                    imgFileName = [NSString stringWithCString:tempFileNameCString encoding:NSUTF8StringEncoding];                
                    NSData *imgData = [coverImage TIFFRepresentation];
                    NSDictionary *dict = [[NSDictionary alloc] init];
                    [[[NSBitmapImageRep imageRepWithData:imgData] 
                      representationUsingType:NSPNGFileType properties:dict]
                        writeToFile:imgFileName atomically:YES];
                    [dict release];
                    [mp4 setCoverFile:imgFileName];
                }
                else {
                    NSLog(@"Failed to generate tmp filename");
                }
            }
            [mp4 updateFile];
            if (imgFileName) {
                NSLog(@"Unlink %@", imgFileName);
                [[NSFileManager defaultManager] removeFileAtPath:imgFileName 
                                                         handler:nil];
            }
            [currentFile setStringValue:TEXT_ADDING_TO_ITUNES];
            if ([[NSUserDefaults standardUserDefaults] boolForKey:@"AddToiTunes"])
                [self addFileToiTunes:outFile];
            [currentFile setStringValue:@"Done"];
            
        }
        @catch (NSException *e) {
            NSLog(@"Something went wrong");
        }
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

-(void) audiobookFailed:(NSString*)filename reason:(NSString*)reason
{
    
    NSAlert *alert = [[[NSAlert alloc] init] retain];
    [alert addButtonWithTitle:@"OK"];
    [alert setMessageText:TEXT_BINDING_FAILED];
    [alert setInformativeText:reason];
    [alert setAlertStyle:NSWarningAlertStyle];
    [alert runModal];
}


-(void) conversionFinished: (AudioFile*)file duration:(UInt32)milliseconds
{
    [fileProgress setDoubleValue:[fileProgress doubleValue]];
    file.valid = YES;
    file.duration = milliseconds;
}

-(void) audiobookReady: (NSString*)filename duration: (UInt32)seconds
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

@end
