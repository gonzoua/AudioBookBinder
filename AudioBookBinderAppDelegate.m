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
	fileList = [[[AudioFileList alloc] init] retain];
	[fileListView setDataSource:fileList];
	[fileListView setDelegate:fileList];
	[fileListView setAllowsMultipleSelection:YES];
	
	[fileListView registerForDraggedTypes:[NSArray arrayWithObjects:NSStringPboardType, NSFilenamesPboardType, nil]];
	[fileListView setDraggingSourceOperationMask:NSDragOperationEvery forLocal:YES];
	// [fileListView setDraggingSourceOperationMask:NSDragOperationEvery forLocal:NO];
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
		[filename appendString:author];
	
	if (![title isEqualToString:@""]) {
		if (![filename isEqualToString:@""])
			[filename appendString:@" - "];
		
		[filename appendString:title];
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

- (void) bindingThreadIsDone:(id)sender
{
	[bindButton setEnabled:TRUE];
}

- (void)bindToFileThread:(id)object
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSString *author = [[form cellAtIndex:ABBAuthor] stringValue];
	NSString *title = [[form cellAtIndex:ABBTitle] stringValue];

	[_binder reset];
	[_binder setDelegate:self];
	[_binder setOutputFile:outFile];
	
	NSArray *files = [fileList files];
	for (AudioFile *file in files) 
		[_binder addInputFile:file.filePath];
	
	
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
	
	else if (![author isEqualToString:@""] || (![title isEqualToString:@""]))
	{
		NSLog(@"Adding metadata, it may take a while...");
		@try {
			[currentFile setStringValue:@"Adding artist/title tags"];
			MP4File *mp4 = [[MP4File alloc] initWithFileName:outFile];
			[mp4 setArtist:author]; 
			[mp4 setTitle:title]; 
			[mp4 updateFile];
			[currentFile setStringValue:@"Adding file to iTunes"];
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
-(void) conversionStart: (NSString*)filename 
				 format: (AudioStreamBasicDescription*)asbd 
	  formatDescription: (NSString*)description 
				 length: (UInt64)frames

{
	[currentFile setStringValue:[NSString stringWithFormat:@"Converting %@", filename]];
	[fileProgress setMaxValue:(double)frames];
	[fileProgress setDoubleValue:0];
}

-(void) updateStatus: (NSString *)filename handled:(UInt64)handledFrames total:(UInt64)totalFrames
{
	[fileProgress setDoubleValue:(double)handledFrames];
}

-(BOOL) continueFailedConversion:(NSString*)filename reason:(NSString*)reason
{

	NSAlert *alert = [[[NSAlert alloc] init] retain];
	[alert addButtonWithTitle:@"OK"];
	[alert setMessageText:@"Audiofile(s) conversion failed"];
	[alert setInformativeText:reason];
	[alert setAlertStyle:NSWarningAlertStyle];
	[alert runModal];
	return NO;
}

-(void) conversionFinished: (NSString*)filename
{
	[fileProgress setDoubleValue:[fileProgress doubleValue]];
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
