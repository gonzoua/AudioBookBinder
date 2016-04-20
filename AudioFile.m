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
        [self updateInfo];
    }
    
    return self;
}


@synthesize filePath, file, duration, valid, artist, name, album;

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
                NSDictionary *properties = [NSDictionary dictionaryWithDictionary:(__bridge NSDictionary*)info];
                // convert properties to CString and back to get rid of
                // trailing zero bytes in NSString
                
                id obj = [properties objectForKey:@"artist"];

                if (obj)
                    self.artist = [NSString stringWithUTF8String:[obj UTF8String]];
                else
                    self.artist = @"";

                obj = [properties objectForKey:@"title"];
                if (obj) 
                    self.name = [NSString stringWithUTF8String:[obj UTF8String]];
                else
                    self.name = @"";
                
                obj = [properties objectForKey:@"album"];
                if (obj) 
                    self.album = [NSString stringWithUTF8String:[obj UTF8String]];
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
