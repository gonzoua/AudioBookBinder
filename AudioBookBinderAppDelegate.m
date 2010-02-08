//
//  AudioBookBinderAppDelegate.m
//  AudioBookBinder
//
//  Created by Oleksandr Tymoshenko on 10-02-04.
//  Copyright 2010 Bluezbox Software. All rights reserved.
//

#import "AudioBookBinderAppDelegate.h"

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
	NSLog(@"bind!");
}

@end
