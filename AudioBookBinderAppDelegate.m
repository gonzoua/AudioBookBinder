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

enum abb_form_fields {
	ABBAuthor = 0,
	ABBTitle,
};

@implementation AudioBookBinderAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	fileList = [[[AudioFileList alloc] init] retain];
	[fileListView setDataSource:fileList];
	[fileListView setDelegate:fileList];
	[fileListView setAllowsMultipleSelection:YES];
}

- (IBAction) addFile: (id)sender
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

- (IBAction) delFile: (id)sender
{
	NSLog(@"delFile");
}

- (IBAction) bind: (id)sender
{
	NSSavePanel *savePanel;
	int choice;
	
	savePanel = [NSSavePanel savePanel];
	[savePanel setAccessoryView: nil];
	// [savePanel setAllowedFileTypes:[NSArray arrayWithObjects:@"m4a", @"m4b", nil]];
	
	choice = [savePanel runModalForDirectory: NSHomeDirectory()
										  file: @"book.m4b"];
	NSString *author = [[form cellAtIndex:ABBAuthor] stringValue];
	NSString *title = [[form cellAtIndex:ABBTitle] stringValue];
	
	/* if successful, save file under designated name */
	if (choice == NSOKButton)
	{
		AudioBinder *binder = [[[AudioBinder alloc] init] retain];
		NSString *outFile = [savePanel filename];
		
		[binder setOutputFile:outFile];
		
		NSArray *files = [fileList files];
		for (AudioFile *file in files) 
			[binder addInputFile:file.filePath];
		
		if (![binder convert])
		{
			NSLog(@"Conversion failed");
		}		
		
		else if (![author isEqualToString:@""] || (![title isEqualToString:@""]))
		{
			NSLog(@"Adding metadata, it may take a while...");
			MP4File *mp4 = [[MP4File alloc] initWithFileName:outFile];
			[mp4 setArtist:author]; 
			[mp4 setTitle:title]; 
			[mp4 updateFile];
		}
		
		[binder release];
	}
}

@end
