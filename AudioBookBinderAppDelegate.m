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
	// Insert code here to initialize your application 
}

- (IBAction) addFile: (id)sender
{
	NSLog(@"addFile");
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
