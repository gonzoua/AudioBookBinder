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

#import <CoreServices/CoreServices.h>
#import <AudioToolbox/AudioConverter.h>
#import "AudioBinder.h"
#import "AudioBinderVolume.h"

#include "ABLog.h"

// 1M seems to be sane buffer size nowadays
#define AUDIO_BUFFER_SIZE 1*1024*1024


// Helper function
static NSString * 
stringForOSStatus(OSStatus err)
{
    // TODO: add proper description
    NSString * descString;
    BOOL isOSType = YES;
    char osTypeRepr[5];
    char *errStr = NULL;
    
    // Check if err is OSType and convert it to 4 chars representation
    osTypeRepr[4] = 0;
    for (int i = 0; i < 4; i++)
    {
        unsigned char c = (err >> 8*i) & 0xff;
        if (isprint(c))
            osTypeRepr[3-i] = c;
        else
        {
            isOSType = NO;
            break;
        }
    }
    
    switch (err) {
        case 0x7479703f:
            errStr = "Unsupported file type";
            break;
        case 0x666d743f:
            errStr = "Unsupported data format";
            break;
        case 0x7074793f:
            errStr = "Unsupported property";
            break;
        case 0x2173697a:
            errStr = "Bad property size";
            break;
        case 0x70726d3f:
            errStr = "Permission denied";
            break;
        case 0x6f70746d:
            errStr = "Not optimized";
            break;
        case 0x63686b3f:
            errStr = "Invalid chunk";
            break;
        case 0x6f66663f:
            errStr = "Does not allow 64bit data size";
            break;
        case 0x70636b3f:
            errStr = "Invalid packet offset";
            break;
        case 0x6474613f:
            errStr = "Invalid file";
            break;
        default:
            errStr = nil;
            break;
    }
    const char *errDescr = isOSType ? (errStr ? errStr : osTypeRepr) : GetMacOSStatusErrorString(err);
    if ((errDescr != nil) && (strlen(errDescr) > 0))
        descString = [[NSString alloc] initWithFormat:@"err#%08lx (%s)", (long)err, errDescr];
    else
        descString = [[NSString alloc] initWithFormat:@"err#%08lx ", (long)err];

    [descString autorelease];
    
    return descString;
}

@implementation AudioBinder

@synthesize channels = _channels;
@synthesize sampleRate = _sampleRate;
@synthesize bitrate = _bitrate;
@synthesize volumes = _volumes;
-(id)init
{
    if ((self = [super init])) {
        _volumes = [[NSMutableArray alloc] init];
        [self reset];
    }
 
    return self;
}

- (void) reset
{
    [_volumes removeAllObjects];
    _outAudioFile = nil;
    _outFileLength = 0;
    _delegate = nil;
    _canceled = NO;
    _sampleRate = DEFAULT_SAMPLE_RATE;
    _channels = 2;
    _bitrate = 0;
    _bitrateSet = NO;

    SInt32 major, minor, bugfix;
    Gestalt(gestaltSystemVersionMajor, &major);
    Gestalt(gestaltSystemVersionMinor, &minor);
    Gestalt(gestaltSystemVersionBugFix, &bugfix);
    if ((major == 10) && (minor >= 7))
        _isLion = YES;
    else
        _isLion = NO;
}

-(void)setDelegate: (id<AudioBinderDelegate>)delegate
{
    _delegate = delegate;
}

-(void) addVolume:(NSString*)filename files:(NSArray*)files
{
    AudioBinderVolume *volume = [[AudioBinderVolume alloc] initWithName:filename files:files];
    [_volumes addObject:volume];
}

-(BOOL)convert
{
    BOOL failed = NO;
    NSFileManager *fm;
    int filesConverted = 0;
    for (AudioBinderVolume *v in _volumes) {
    
        if ([v.inputFiles count] == 0)
        {
            ABLog(@"No input files");
            [_delegate volumeFailed:v.filename reason:@"No input files"];
            return NO;
        }

        if ([self openOutFile:v.filename] == NO)
        {
            ABLog(@"Can't open output file");
            [_delegate volumeFailed:v.filename reason:@"Can't create output file"];
            return NO;
        }


        for (AudioFile *inFile in v.inputFiles) {
            NSString *reason;
            
            if ([self convertOneFile:inFile reason:&reason] == NO)
            {
                // We failed 
                if (![_delegate continueFailedConversion:inFile reason:reason])
                {
                    failed = YES;
                    break;
                }
            }
            else
                filesConverted++;
            
            if (_canceled)
                break;
        
        } 

        _outBookLength += _outFileLength; 
        
        [self closeOutFile];
        
        if (failed || _canceled)
            break;
        else
            [_delegate volumeReady:v.filename duration:(UInt32)(_outFileLength/_sampleRate)];
    }
    
    if (failed || _canceled)
    {
        fm = [NSFileManager defaultManager];
        for (AudioBinderVolume *v in _volumes) 
            [fm removeItemAtPath:v.filename error:nil];
    }
       
    BOOL result = YES;
    // Did we fail? Were there any files successfully converted? 
    if (failed || (filesConverted == 0) || _canceled)
        result = NO;
    else
        [_delegate audiobookReady:(UInt32)(_outBookLength/_sampleRate)];
    
    // Back to non-cacneled state
    _canceled = NO;
    
    return result;
}

-(BOOL)openOutFile:(NSString*)outFile
{
    OSStatus status;
    AudioStreamBasicDescription outputFormat;
    
    // delete file if exists
    if([[NSFileManager defaultManager] fileExistsAtPath:outFile]) 
    {
        if (![[NSFileManager defaultManager] removeItemAtPath:outFile 
                                                      error:nil])
        {
            ABLog(@"Can't remove file %@", outFile);
            return NO;
        }
    }    
   
    id url = [NSURL fileURLWithPath:outFile];
    
    memset(&outputFormat, 0, sizeof(AudioStreamBasicDescription));
    outputFormat.mSampleRate = _sampleRate;
    outputFormat.mFormatID = kAudioFormatMPEG4AAC;
    outputFormat.mChannelsPerFrame = _channels;
   
    status = ExtAudioFileCreateWithURL((__bridge CFURLRef)url,
                                   kAudioFileMPEG4Type, &outputFormat, 
                                   NULL, kAudioFileFlags_EraseFile, &_outAudioFile);
    
    if (status != noErr)
    {
        ABLog(@"Can't create output file %@: %@", 
              outFile, stringForOSStatus(status));
        return NO;
    }
    
    // reset output file length
    _outFileLength = 0;

    return YES;
}

-(void)closeOutFile
{
    if (_outAudioFile != nil)
        ExtAudioFileDispose(_outAudioFile);
    _outAudioFile = nil;
}

-(BOOL) convertOneFile: (AudioFile *)inFile reason: (NSString**)reason
{
    // Get description
    NSString *fileFormat;
    UInt32 specSize;
    OSStatus status;

    ExtAudioFileRef inAudioFile = nil;
    AudioStreamBasicDescription format;    
    AudioStreamBasicDescription pcmFormat;      
    UInt32 size;
    AudioConverterRef conv = NULL;
    UInt64 framesTotal = 0, framesConverted = 0;
    UInt32 framesToRead = 0;
    AudioBufferList bufferList;
    void *audioBuffer = NULL;
        
    @try {

        id url = [NSURL fileURLWithPath:inFile.filePath];
        status = ExtAudioFileOpenURL((__bridge CFURLRef)url, &inAudioFile);
        if (status != noErr)
            [NSException raise:@"ConvertException" 
                format:@"ExtAudioFileOpenURL failed: %@", 
                stringForOSStatus(status)];
        
        // Query file type
        size = sizeof(AudioStreamBasicDescription);
        status = ExtAudioFileGetProperty(inAudioFile, 
                                         kExtAudioFileProperty_FileDataFormat,
                                         &size, &format);
        if(status != noErr)
            [NSException raise:@"ConvertException" 
                format:@"AudioFileGetProperty failed: %@", 
             stringForOSStatus(status)];
        
        specSize = sizeof(fileFormat);
        size = sizeof(AudioStreamBasicDescription);
        status = AudioFormatGetProperty(kAudioFormatProperty_FormatName, 
                                        size, &format, &specSize, &fileFormat);
        
        if(status != noErr) 
            [NSException raise:@"ConvertException" 
                format:@"AudioFormatGetProperty failed: %@", 
                stringForOSStatus(status)];        

        size = sizeof(framesTotal);
        status = ExtAudioFileGetProperty(inAudioFile, 
                                         kExtAudioFileProperty_FileLengthFrames,
                                         &size, &framesTotal);
        
        if(status != noErr)
            [NSException raise:@"ConvertException" 
                        format:@"can't get input file length: %@", 
             stringForOSStatus(status)];
        
        [_delegate conversionStart: inFile 
                            format: &format
                 formatDescription: fileFormat
                            length: framesTotal];        
        // framesTotal was calculated with respect to original format
        // in order to get proper progress dialog we need convert to to client
        // format
        framesTotal = (framesTotal * _sampleRate) / format.mSampleRate;

        // Setup input format descriptor, preserve mSampleRate
        bzero(&pcmFormat, sizeof(pcmFormat));
        pcmFormat.mSampleRate = _sampleRate;
        pcmFormat.mFormatID = kAudioFormatLinearPCM;
        pcmFormat.mFormatFlags = kAudioFormatFlagIsSignedInteger 
            | kAudioFormatFlagIsBigEndian 
            | kAudioFormatFlagIsPacked;

        pcmFormat.mBitsPerChannel = 16;
        pcmFormat.mChannelsPerFrame = _channels;
        pcmFormat.mFramesPerPacket = 1;
        pcmFormat.mBytesPerPacket = 
            (pcmFormat.mBitsPerChannel / 8) * pcmFormat.mChannelsPerFrame;
        pcmFormat.mBytesPerFrame = 
            pcmFormat.mBytesPerPacket * pcmFormat.mFramesPerPacket;

        status = ExtAudioFileSetProperty(inAudioFile, 
                                         kExtAudioFileProperty_ClientDataFormat, 
                                         sizeof(pcmFormat), &pcmFormat);
        if(status != noErr)
            [NSException raise:@"ConvertException" 
                format:@"ExtAudioFileSetProperty(ClientDataFormat) failed: %@", 
                stringForOSStatus(status)];

        // Get the underlying AudioConverterRef
        size = sizeof(AudioConverterRef);

        status = ExtAudioFileGetProperty(inAudioFile, 
                                         kExtAudioFileProperty_AudioConverter, 
                                         &size, &conv);
        if(status != noErr)
            [NSException raise:@"ConvertException" 
                        format:@"can't get AudioConverter: %@", 
                        stringForOSStatus(status)]; 
        
        // Convert mono files to stereo by duplicating channel
        if ((format.mChannelsPerFrame == 1) && (_channels == 2))
        {
            if (conv)
            {
                SInt32 channelMap[] = { 0, 0 };
                status = AudioConverterSetProperty(conv, 
                                                   kAudioConverterChannelMap, 
                                                   2*sizeof(SInt32), 
                                                   channelMap);
                if(status != noErr)
                    [NSException raise:@"ConvertException" 
                                format:@"Can't set ChannelMap: %@", 
                                stringForOSStatus(status)];             
            }
            else
            {
                [NSException raise:@"ConvertException" 
                            format:@"Can't get AudioConverter ref"];             
                
            }
        }

        status = ExtAudioFileSetProperty(_outAudioFile, 
                                         kExtAudioFileProperty_ClientDataFormat, 
                                         sizeof(pcmFormat), &pcmFormat);
        if(status != noErr)
            [NSException raise:@"ConvertException" 
                format:@"can't set ClientDataFormat: %@", 
                stringForOSStatus(status)];
        
        if (_bitrate > 0) {
            if (_isLion && !_bitrateSet) {
                if (![self setConverterBitrate]) {
                    [NSException raise:@"ConvertException" 
                        format:@"can't set output bit rate"]; 
                }
                _bitrateSet = YES;
            }
        }
        
        audioBuffer = malloc(AUDIO_BUFFER_SIZE);
        NSAssert(audioBuffer != NULL, @"malloc failed");
        audioBuffer = malloc(AUDIO_BUFFER_SIZE);
        bufferList.mNumberBuffers = 1;
        bufferList.mBuffers[0].mNumberChannels = pcmFormat.mChannelsPerFrame;
        bufferList.mBuffers[0].mData = audioBuffer;
        bufferList.mBuffers[0].mDataByteSize = AUDIO_BUFFER_SIZE;
                
        do {
            
            framesToRead = 
                bufferList.mBuffers[0].mDataByteSize / pcmFormat.mBytesPerFrame;
            status = ExtAudioFileRead(inAudioFile, &framesToRead, &bufferList);
            if(status != noErr)
                [NSException raise:@"ConvertException" 
                            format:@"ExtAudioFileRead failed: %@", 
                            stringForOSStatus(status)];
            
            if (framesToRead > 0) 
            {
                status = ExtAudioFileWrite(_outAudioFile, 
                                           framesToRead, &bufferList);
                if(status != noErr)
                    [NSException raise:@"ConvertException" 
                        format:@"ExtAudioFileWrite failed: %@", 
                        stringForOSStatus(status)];
            }

            framesConverted += framesToRead;

            [_delegate updateStatus:inFile 
                            handled:framesConverted 
                              total:framesTotal];

            status = ExtAudioFileTell(_outAudioFile, &_outFileLength);
            if(status != noErr)
                [NSException raise:@"ConvertException" 
                            format:@"ExtAudioFileTell failed: %@", 
                 stringForOSStatus(status)];
            
            if (_canceled)
                break;

        } while(framesToRead > 0);


        UInt32 duration = framesConverted*1000/_sampleRate;
        [_delegate conversionFinished:inFile
                             duration:duration];
    }  
    @catch (NSException *e) {
        *reason = [e reason];
        if (inAudioFile != nil)
            ExtAudioFileDispose(inAudioFile);
        if (audioBuffer)
            free(audioBuffer);
        return NO;
    }
    
    // _needNextVolume = YES;
    
    if (inAudioFile != nil)
        ExtAudioFileDispose(inAudioFile);
    if (audioBuffer)
        free(audioBuffer);

    return YES;
}

- (void) cancel
{
    _canceled = YES;
}

-(NSArray*) validBitrates
{
    OSStatus status;
    ExtAudioFileRef tmpAudioFile;
    AudioConverterRef outConverter;
    NSMutableArray *validBitrates = [[[NSMutableArray alloc] init] autorelease];
    UInt32 size;
    
    AudioStreamBasicDescription outputFormat, pcmFormat;  
    
    // open out file
    NSString *dir = NSTemporaryDirectory();
    NSString *file = [dir stringByAppendingFormat:@"/%@",
                      [[NSProcessInfo processInfo] globallyUniqueString]];

    
    memset(&outputFormat, 0, sizeof(AudioStreamBasicDescription));
    outputFormat.mSampleRate = _sampleRate;
    outputFormat.mFormatID = kAudioFormatMPEG4AAC;
    outputFormat.mChannelsPerFrame = _channels;
    
    id url = [NSURL fileURLWithPath:file];
    status = ExtAudioFileCreateWithURL((__bridge CFURLRef)url,
                                   kAudioFileMPEG4Type, &outputFormat, 
                                   NULL, kAudioFileFlags_EraseFile, &tmpAudioFile);
    
    if (status != noErr)
        return validBitrates;
    
    // Setup input format descriptor, preserve mSampleRate
    bzero(&pcmFormat, sizeof(pcmFormat));
    pcmFormat.mSampleRate = _sampleRate;
    pcmFormat.mFormatID = kAudioFormatLinearPCM;
    pcmFormat.mFormatFlags = kAudioFormatFlagIsSignedInteger 
                                | kAudioFormatFlagIsBigEndian 
                                | kAudioFormatFlagIsPacked;
    
    pcmFormat.mBitsPerChannel = 16;
    pcmFormat.mChannelsPerFrame = _channels;
    pcmFormat.mFramesPerPacket = 1;
    pcmFormat.mBytesPerPacket = 
    (pcmFormat.mBitsPerChannel / 8) * pcmFormat.mChannelsPerFrame;
    pcmFormat.mBytesPerFrame = 
    pcmFormat.mBytesPerPacket * pcmFormat.mFramesPerPacket;
    
    status = ExtAudioFileSetProperty(tmpAudioFile, 
                                     kExtAudioFileProperty_ClientDataFormat, 
                                     sizeof(pcmFormat), &pcmFormat);

    if(status != noErr) {
        ExtAudioFileDispose(tmpAudioFile);
        [[NSFileManager defaultManager] removeItemAtPath:file error:nil];
        return validBitrates;
    }
    
    // Get the underlying AudioConverterRef
    size = sizeof(AudioConverterRef);
    status = ExtAudioFileGetProperty(tmpAudioFile, 
                                     kExtAudioFileProperty_AudioConverter, 
                                     &size, &outConverter);
    
    if(status != noErr) {
        ExtAudioFileDispose(tmpAudioFile);
        [[NSFileManager defaultManager] removeItemAtPath:file error:nil];
        return validBitrates;
    }
    
    size = 0;
    // Get the available bitrates (CBR)
    status = AudioConverterGetPropertyInfo(outConverter, 
                                           kAudioConverterApplicableEncodeBitRates, 
                                           &size, NULL);
    if(noErr != status) {
        ExtAudioFileDispose(tmpAudioFile);
        [[NSFileManager defaultManager] removeItemAtPath:file error:nil];
        return validBitrates;
    }

    AudioValueRange *bitrates = malloc(size);
    NSCAssert(NULL != bitrates, 
              NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));
    
    status = AudioConverterGetProperty(outConverter, 
                                       kAudioConverterApplicableEncodeBitRates, 
                                       &size, bitrates);

    if(noErr == status) {
        int bitrateCount = size / sizeof(AudioValueRange);

        for(int n = 0; n < bitrateCount; ++n) {
            unsigned long minRate = (unsigned long) bitrates[n].mMinimum;
            if(0 != minRate) {
                [validBitrates addObject:[NSNumber numberWithUnsignedLong: minRate]];
            }
        }
    }
    
    free(bitrates);
    
    ExtAudioFileDispose(tmpAudioFile);
    [[NSFileManager defaultManager] removeItemAtPath:file error:nil];

    return validBitrates;
    
}


-(BOOL) setConverterBitrate
{
    OSStatus status;
    AudioConverterRef outConverter;
    UInt32 size;
    
    // Get the underlying AudioConverterRef
    size = sizeof(AudioConverterRef);
    status = ExtAudioFileGetProperty(_outAudioFile, 
                                     kExtAudioFileProperty_AudioConverter, 
                                     &size, &outConverter);
    
    if(status != noErr) {
        // ABLog(@"can't get AudioConverter: %@", stringForOSStatus(status)); 
        return NO;
    }
    
    status = AudioConverterSetProperty(outConverter, kAudioConverterEncodeBitRate, 
                                       sizeof(_bitrate), &_bitrate);
    if(status != noErr) {
        // ABLog(@"can't set requested bit rate: %@", stringForOSStatus(status)); 
        return NO;
    }
    
    return YES;
    
}

@end
