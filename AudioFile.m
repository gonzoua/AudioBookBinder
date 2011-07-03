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
    if ((self = [super init]))
    {
        self.filePath = [path stringByExpandingTildeInPath];
        self.file = [filePath lastPathComponent];
        self.duration = [[NSNumber alloc] initWithInt:-1];
        self.valid = NO;
        self.artist = @"";
        self.name = @"";
        self.album = @"";
        self.year = @"";
        self.genre = @"";
        self.composer = @"";
        [self updateInfo];
    }
    
    return self;
}

- (void) dealloc
{
    self.filePath = nil;
    self.file = nil;
    self.artist = nil;
    self.name = nil;
    self.album = nil;
	self.year = nil;
	self.genre = nil;
	self.composer = nil;
    [super dealloc];
}

@synthesize filePath, file, duration, valid, artist, name, album, year, composer, genre;

NSString* getPropertyFromAudioFile(NSString *propName, NSDictionary *properties)
{
	id obj = [properties objectForKey:propName];
	
	if (obj != nil)
	{
		return [NSString stringWithUTF8String:[obj UTF8String]];
	}
	return @"";
}

- (void) updateInfo
{
    // NSString *extension = [[self.filePath pathExtension] lowercaseString];
    OSStatus status;
    AudioFileID audioFile;
    CFURLRef url = CFURLCreateWithFileSystemPath(kCFAllocatorDefault,
                                                 (CFStringRef)self.filePath,
                                                 kCFURLPOSIXPathStyle, FALSE);
    if (AudioFileOpenURL(url, 0x01, 0, &audioFile) == noErr) {        
        UInt32 len = sizeof(NSTimeInterval);
        NSTimeInterval dur;
        if (AudioFileGetProperty(audioFile, kAudioFilePropertyEstimatedDuration, &len, &dur) == noErr) 
            self.duration = [[NSNumber alloc] initWithInt:(dur*1000)];

        UInt32 writable = 0, size;
        status = AudioFileGetPropertyInfo(audioFile, 
            kAudioFilePropertyInfoDictionary, &size, &writable);

        if ( status == noErr ) {
            CFDictionaryRef info = NULL;
            status = AudioFileGetProperty(audioFile, 
                kAudioFilePropertyInfoDictionary, &size, &info);
            if ( status == noErr ) {
                NSDictionary *properties = (NSDictionary *)info;
                // NSLog(@"file properties: %@", properties);
                NSString *s = nil;
                
                id obj = [properties objectForKey:@"artist"];
                
                if (obj != nil)
                    s = [NSString stringWithUTF8String:[obj UTF8String]];
                if (s) 
                    self.artist = s;
                else
                    self.artist = @"";
				self.artist = getPropertyFromAudioFile(@"artist", properties);
				self.name = getPropertyFromAudioFile(@"title", properties);
				self.album = getPropertyFromAudioFile(@"album", properties);
				self.year = getPropertyFromAudioFile(@"year", properties);
				self.genre = getPropertyFromAudioFile(@"genre", properties);
				self.composer = getPropertyFromAudioFile(@"composer", properties);
			}
        }
        self.valid = YES;
        AudioFileClose(audioFile);
    }

    CFRelease(url);
}



@end
