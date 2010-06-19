//
//  Copyright (c) 2009, Oleksandr Tymoshenko <gonzo@bluezbox.com>
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

#import <Cocoa/Cocoa.h>

#include <AudioToolbox/AudioFormat.h>
#include <AudioToolbox/ExtendedAudioFile.h>
#import "AudioFile.h"

#define DEFAULT_SAMPLE_RATE 44100.f

@protocol AudioBinderDelegate

-(void) updateStatus: (AudioFile*)file handled:(UInt64)handledFrames total:(UInt64)totalFrames;
-(void) conversionStart: (AudioFile*)file 
                 format: (AudioStreamBasicDescription*)format
      formatDescription: (NSString*)description
                 length: (UInt64)frames;
-(BOOL) continueFailedConversion:(AudioFile*)file reason:(NSString*)reason;
-(void) conversionFinished: (AudioFile*)file duration: (UInt32)milliseconds;
-(void) audiobookReady: (NSString*)filename duration: (UInt32)seconds;
-(void) audiobookFailed: (NSString*)filename reason: (NSString*)reason;

@end


@interface AudioBinder : NSObject {
    NSMutableArray *_inFiles;
    NSString *_outFileName;
    ExtAudioFileRef _outAudioFile;
    SInt64 _outFileLength;
    id _delegate;
    BOOL _canceled;
    float _sampleRate;
    int _channels;
    UInt32 _bitrate;
    NSMutableArray *_availableBitrates;
}


@property (assign) int channels;
@property (assign) float sampleRate;
@property (assign) UInt32 bitrate;

-(id) init;
-(void) reset;
-(void) setDelegate: (id <AudioBinderDelegate>)delegate;
-(void) addInputFile: (AudioFile*)file;
-(void) setOutputFile: (NSString*)outFileName;
-(BOOL) convert;
-(BOOL) openOutFile;
-(void) closeOutFile;
-(BOOL) convertOneFile: (AudioFile*)inFile reason: (NSString**)reason;
-(void) cancel;
-(BOOL) setConverterBitrate;
-(NSArray*) validBitrates;
@end
