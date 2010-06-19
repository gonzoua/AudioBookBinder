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

#import <AudioToolbox/AudioConverter.h>
#import "AudioBinder.h"

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
        descString = [[NSString alloc] initWithFormat:@"err#%08x (%s)", err, errDescr];
    else
        descString = [[NSString alloc] initWithFormat:@"err#%08x ", err];

    [descString autorelease];
    
    return descString;
}

@implementation AudioBinder

@synthesize channels = _channels;
@synthesize sampleRate = _sampleRate;
@synthesize bitrate = _bitrate;

-(id)init
{
    if (self = [super init]) {
        _inFiles = [[NSMutableArray alloc] init];
        [self reset];
    }
 
    return self;
}

- (void) reset
{
    [_inFiles removeAllObjects];
    _outFileName = nil;
    _outAudioFile = nil;
    _outFileLength = 0;
    _delegate = nil;
    _canceled = NO;
    _sampleRate = DEFAULT_SAMPLE_RATE;
    _channels = 2;
    _bitrate = 0;
}

-(void)setDelegate: (id<AudioBinderDelegate>)delegate
{
    _delegate = delegate;
}

-(void)addInputFile: (AudioFile*)file
{
    [_inFiles addObject: file];
}

-(void)setOutputFile: (NSString*)outFileName
{
    [_outFileName release];
    _outFileName = [[NSString alloc] initWithString:outFileName];
}

-(BOOL)convert
{
    BOOL failed = NO;
    NSFileManager *fm;
    int filesConverted = 0;
    
    if ([_inFiles count] == 0)
    {
        ABLog(@"No input file");
        [_delegate audiobookFailed:_outFileName reason:@"No input files"];
        return NO;
    }
    
    if ([self openOutFile] == NO)
    {
        ABLog(@"Can't open output file");
        [_delegate audiobookFailed:_outFileName reason:@"Can't create output file"];
        return NO;
    }
    
    for (AudioFile* inFile in _inFiles) 
    {
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
    
    [self closeOutFile];
    if (failed || _canceled)
    {
        fm = [NSFileManager defaultManager];
        [fm removeFileAtPath:_outFileName handler:nil];
    }
       
    BOOL result = YES;
    // Did we fail? Were there any files successfully converted? 
    if (failed || (filesConverted == 0) || _canceled)
        result = NO;
    else
        [_delegate audiobookReady:_outFileName 
                         duration:(UInt32)(_outFileLength/_sampleRate)];
    
    // Back to non-cacneled state
    _canceled = NO;
    
    return result;
}

-(BOOL)openOutFile
{
    FSRef dirFSRef;
    OSStatus status;
    AudioStreamBasicDescription outputFormat;
    
    // delete file if exists
    if([[NSFileManager defaultManager] fileExistsAtPath:_outFileName]) 
    {
        if (![[NSFileManager defaultManager] removeFileAtPath:_outFileName 
                                                      handler:nil])
        {
            ABLog(@"Can't remove file %@", _outFileName);
            return NO;
        }
    }    
     
    // open out file
    NSString *dir = [[_outFileName stringByDeletingLastPathComponent] retain];
    // if its only path name - make reference to current directory
    if ([dir isEqualToString:@""])
    {
        [dir release];
        dir = [[NSString stringWithString:@"."] retain];
    }
    
    status = FSPathMakeRef((UInt8 *)
                           [dir UTF8String], 
                           &dirFSRef, NULL);
    [dir release];
    if (status != noErr)
    {
        ABLog(@"FSPathMakeRef failed for %@: %@", 
              _outFileName, stringForOSStatus(status));        
        return NO;
    }    
    
    memset(&outputFormat, 0, sizeof(AudioStreamBasicDescription));
    outputFormat.mSampleRate = _sampleRate;
    outputFormat.mFormatID = kAudioFormatMPEG4AAC;
    outputFormat.mChannelsPerFrame = _channels;
   
    status = ExtAudioFileCreateNew(&dirFSRef, 
                                   (CFStringRef)[_outFileName lastPathComponent], 
                                   kAudioFileMPEG4Type, &outputFormat, 
                                   NULL, &_outAudioFile);
    
    if (status != noErr)
    {
        ABLog(@"Can't create output file %@: %@", 
              _outFileName, stringForOSStatus(status));
        return NO;
    }
    
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
    FSRef ref;
    Boolean isDirectory;
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
        // open audio file
        status = FSPathMakeRef(
                               (const UInt8 *)[inFile.filePath fileSystemRepresentation], 
                               &ref, &isDirectory);
        if (status != noErr)
            [NSException raise:@"ConvertException" 
                format:@"Can't make reference for file %@: %@", 
                inFile.filePath, stringForOSStatus(status)];
        
        if (isDirectory)
            [NSException raise:@"ConvertException" 
                format:@"Error: %@ is directory", inFile.filePath];
        
        status = ExtAudioFileOpen(&ref, &inAudioFile);
        if (status != noErr)
            [NSException raise:@"ConvertException" 
                format:@"ExtAudioFileWrapAudioFileID failed: %@", 
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
            if (![self setConverterBitrate]) {
                [NSException raise:@"ConvertException" 
                        format:@"can't set output bit rate"]; 
            }
        }
        
        audioBuffer = malloc(AUDIO_BUFFER_SIZE);
        NSAssert(audioBuffer != NULL, @"malloc failed");
        audioBuffer = malloc(AUDIO_BUFFER_SIZE);
        bufferList.mNumberBuffers = 1;
        bufferList.mBuffers[0].mNumberChannels = pcmFormat.mChannelsPerFrame;
        bufferList.mBuffers[0].mData = audioBuffer;
        bufferList.mBuffers[0].mDataByteSize = AUDIO_BUFFER_SIZE;
                
        SInt64 prevPos = _outFileLength;
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


        UInt32 duration = (_outFileLength - prevPos)*1000/_sampleRate;
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
    
    FSRef dirFSRef;
    AudioStreamBasicDescription outputFormat, pcmFormat;  
    
    // open out file
    NSString *dir = NSTemporaryDirectory();
    NSString *file = [dir stringByAppendingFormat:@"/%@",
                      [[NSProcessInfo processInfo] globallyUniqueString]];

    status = FSPathMakeRef((UInt8 *)
                           [dir UTF8String], 
                           &dirFSRef, NULL);
    if (status != noErr)
        return validBitrates;
    
    memset(&outputFormat, 0, sizeof(AudioStreamBasicDescription));
    outputFormat.mSampleRate = _sampleRate;
    outputFormat.mFormatID = kAudioFormatMPEG4AAC;
    outputFormat.mChannelsPerFrame = _channels;
    
    status = ExtAudioFileCreateNew(&dirFSRef, 
                                   (CFStringRef)[file lastPathComponent], 
                                   kAudioFileMPEG4Type, &outputFormat, 
                                   NULL, &tmpAudioFile);
    
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
        [[NSFileManager defaultManager] removeFileAtPath:file handler:nil];
        return validBitrates;
    }
    
    // Get the underlying AudioConverterRef
    size = sizeof(AudioConverterRef);
    status = ExtAudioFileGetProperty(tmpAudioFile, 
                                     kExtAudioFileProperty_AudioConverter, 
                                     &size, &outConverter);
    
    if(status != noErr) {
        ExtAudioFileDispose(tmpAudioFile);
        [[NSFileManager defaultManager] removeFileAtPath:file handler:nil];
        return validBitrates;
    }
    
    size = 0;
    // Get the available bitrates (CBR)
    status = AudioConverterGetPropertyInfo(outConverter, 
                                           kAudioConverterApplicableEncodeBitRates, 
                                           &size, NULL);
    if(noErr != status) {
        ExtAudioFileDispose(tmpAudioFile);
        [[NSFileManager defaultManager] removeFileAtPath:file handler:nil];
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
    [[NSFileManager defaultManager] removeFileAtPath:file handler:nil];

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
