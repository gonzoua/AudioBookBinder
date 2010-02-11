//
//  AudioFile.m
//  AudioBookBinder
//
//  Created by Oleksandr Tymoshenko on 10-02-06.
//  Copyright 2010 Bluezbox Software. All rights reserved.
//

#import <AudioToolbox/AudioToolbox.h>

#import "AudioFile.h"

@implementation AudioFile

- (id) initWithPath:(NSString*)path
{
	if (self = [super init])
	{
		self.filePath = path;
		self.name = [path lastPathComponent];
		self.duration = -1;
		[self updateDuration];
	}
	
	return self;
}

- (BOOL) isValid
{
	if (self.duration >= 0)
		return TRUE;
	
	return FALSE;
}

- (void) dealloc
{
	[filePath release];
	[name release];
	[super dealloc];
}

@synthesize filePath, name, duration;

- (void) updateDuration
{
	NSWorkspace *ws = [NSWorkspace sharedWorkspace];
	NSString *extension = [[self.filePath pathExtension] lowercaseString];
	if ([ws filenameExtension:extension isValidForType:@"public.audio"]) 
	{
		AudioFileID audioFile;
		CFURLRef url = CFURLCreateWithFileSystemPath(kCFAllocatorDefault,
													 (CFStringRef)self.filePath,
													 kCFURLPOSIXPathStyle, FALSE);
		if (AudioFileOpenURL(url, 0x01, 0, &audioFile) == noErr) 
		{		
			UInt32 len = sizeof(NSTimeInterval);
			NSTimeInterval dur;
			if (AudioFileGetProperty(audioFile, kAudioFilePropertyEstimatedDuration, &len, &dur) == noErr) 
				self.duration = dur;
			AudioFileClose(audioFile);
		}
		CFRelease(url);
	}
	NSLog(@"updateDuration: %d", self.duration);
}

@end