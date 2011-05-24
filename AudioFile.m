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
        self.name = [filePath lastPathComponent];
        self.duration = -1;
        self.valid = NO;
        self.artist = @"";
        self.title = @"";
        self.album = @"";
        [self updateInfo];
    }
    
    return self;
}

- (void) dealloc
{
    self.filePath = nil;
    self.name = nil;
    self.artist = nil;
    self.title = nil;
    self.album = nil;
    [super dealloc];
}

@synthesize filePath, name, duration, valid, artist, title, album;

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
            self.duration = dur*1000;

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

                obj = [properties objectForKey:@"title"];
                s = nil;
                if (obj != nil)
                    s = [NSString stringWithUTF8String:[obj UTF8String]];
                if (s) 
                    self.title = s;
                else
                    self.title = @"";
                
                obj = [properties objectForKey:@"album"];
                s = nil;
                if (obj != nil)
                    s = [NSString stringWithUTF8String:[obj UTF8String]];
                if (s) 
                    self.album = s;
                else
                    self.album = @"";
            }
        }
        self.valid = YES;
        AudioFileClose(audioFile);
    }

    CFRelease(url);
}


@end
