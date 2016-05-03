//
//  Copyright (c) 2010-2016 Oleksandr Tymoshenko <gonzo@bluezbox.com>
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

#import <AudioToolbox/AudioToolbox.h>

#import "AudioFile.h"

@interface AudioFile()
- (void) updateInfo;
@end

@implementation AudioFile

- (id) initWithPath:(NSString*)path
{
    if ((self = [super init]))
    {
        self.filePath = [path stringByExpandingTildeInPath];
        self.file = [self.filePath lastPathComponent];
        self.duration = [[NSNumber alloc] initWithInt:-1];
        self.valid = NO;
        self.artist = @"";
        self.name = @"";
        self.album = @"";
        [self updateInfo];
    }
    
    return self;
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
            CFRelease(info);
        }
        self.valid = YES;
        AudioFileClose(audioFile);
    }

    CFRelease(url);
}

@end
