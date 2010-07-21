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

#import <Foundation/Foundation.h>
#import <Foundation/NSDebug.h> 
#import <QTKit/QTKit.h>
#include <getopt.h>

#import "AudioBinder.h"
#import "ABLog.h"
#import "ConsoleDelegate.h"
#import "AudioFile.h"
#import "MP4File.h"

#include "MetaEditor.h"
#import "Chapter.h"

#define NUM_VALID_RATES 9
int validRates[NUM_VALID_RATES] = { 8000, 11025, 12000, 16000, 22050,
    24000, 32000, 44100, 48000};

void usage(char *cmd)
{
    printf("Usage: %s [-hsv] [-c 1|2] [-r samplerate] [-a author] [-t title] [-i filelist] "
           "outfile [@chapter_1@ infile @chapter_2@ ...]\n", cmd);
    printf("\t-a author\tset book author\n");
    printf("\t-b bitrate\tset bitrate (KBps)\n");
    printf("\t-c 1|2\t\tnumber of channels in audiobook. Default: 2\n");
    printf("\t-C file.png\tcover image\n");
    printf("\t-e\t\talias for -E ''\n");
    printf("\t-E template\tmake each file a chapter with name defined by template\n");
    printf("\t\t\t    %%N - chapter number\n");
    printf("\t\t\t    %%a - artis (obtained from source file)\n");
    printf("\t\t\t    %%t - title (obtained from source file)\n");
    printf("\t-h\t\tshow this message\n");
    printf("\t-i file\t\tget input files list from file, \"-\" for standard input\n");
    printf("\t-q\t\tquiet mode (no output)\n");
    printf("\t-r rate\t\tsample rate of audiobook. Default: 44100\n");
    printf("\t-s\t\tskip errors and go on with conversion\n");
    printf("\t-t title\tset book title\n");
    printf("\t-v\t\tprint some info on files being converted\n");
    
}

NSString *makeChapterName(NSString *format, int chapterNum, AudioFile *file)
{

    NSString *numStr = [[NSString stringWithFormat:@"%d", chapterNum + 1] retain];
    NSMutableString *name = [[NSMutableString stringWithString:format] retain];

    [name replaceOccurrencesOfString:@"%a" 
                          withString:file.artist
                             options:NSLiteralSearch 
                               range:NSMakeRange(0, [name length])];
 
    [name replaceOccurrencesOfString:@"%t" 
                          withString:file.title 
                             options:NSLiteralSearch 
                               range:NSMakeRange(0, [name length])];

    [name replaceOccurrencesOfString:@"%N" 
                          withString:numStr
                             options:NSLiteralSearch 
                               range:NSMakeRange(0, [name length])];

    return name;
}

int main (int argc, char * argv[]) {
    int c, i;
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
    AudioBinder *binder = [[AudioBinder alloc] init];
    NSString *bookAuthor = nil;
    NSString *bookTitle = nil;
    NSString *outFile = nil;
    NSString *inputFileList = nil;
    NSString *coverFile = nil;
    NSMutableArray *inputFilenames;
    NSMutableArray *inputFiles;
    NSError *error;
    ConsoleDelegate *delegate;
    BOOL verbose = NO;
    BOOL quiet = NO;
    BOOL skipErrors = NO;
    int channels = 2;
    float samplerate = 44100.;
    int bitrate;
    BOOL withChapters = NO;
    BOOL eachFileIsChapter = NO;
    NSString *chapterNameFormat;
    NSMutableArray *chapters = [[NSMutableArray alloc] init];
    
    NSZombieEnabled = YES;
    while ((c = getopt(argc, argv, "a:b:c:C:eE:hi:qr:st:v")) != -1) {
        switch (c) {
            case 'h':
                usage(argv[0]);
                exit(0);
            case 'a':
                bookAuthor = [NSString stringWithUTF8String:optarg];
                break;
            case 't':
                bookTitle = [NSString stringWithUTF8String:optarg];
                break;
            case 'i':
                inputFileList = [NSString stringWithUTF8String:optarg];
                break;
            case 'v':
                verbose = YES;
                break;
            case 's':
                skipErrors = YES;
                break;
            case 'c':
                channels = atoi(optarg);
                break;
            case 'r':
                samplerate = atof(optarg);
                break;
            case 'C':
                coverFile = [NSString stringWithUTF8String:optarg];
                break;
            case 'q':
                quiet = YES;
                break;
            case 'e':
                if (withChapters) {
                    fprintf(stderr, "You can't use both -e and -E together");
                    exit(1);
                }
                withChapters = YES;
                eachFileIsChapter = YES;
                chapterNameFormat = @"";
                break;
            case 'E':
                if (withChapters) {
                    fprintf(stderr, "You can't use both -e and -E together");
                    exit(1);
                }
                withChapters = YES;
                eachFileIsChapter = YES;
                chapterNameFormat = [NSString stringWithUTF8String:optarg];
                break;
            case 'b':
                bitrate = atoi(optarg)*1000;
                if (bitrate == 0) {
                    fprintf(stderr, "Invalid bitrate: %s", optarg);
                    exit(1);
                }
                break;
            default:
                usage(argv[0]);
                exit(1);
        }
    }
    
    // Do we have output file et al?
    if (optind < argc) 
    {
            outFile = [NSString stringWithUTF8String:argv[optind]];
            optind++;
    }
    else
    {
        fprintf(stderr, "No output file specified\n");
        usage(argv[0]);
        exit(1);
    }

    if (channels != 1 && channels != 2) {
        fprintf(stderr, "only 1 and 2 are valid as -c argument");
        exit(1);
    }
    
    for (i = 0; i < NUM_VALID_RATES; i++) {
        if (validRates[i] == samplerate)
            break;
    }
    
    if (i == NUM_VALID_RATES) {
        fprintf(stderr, "Invalid sample rate. Valid rates: ");
        for (i = 0; i < NUM_VALID_RATES; i++) {
            if (i)
                fprintf(stderr, ", ");
            fprintf(stderr, "%d", validRates[i]);
        }
        fprintf(stderr, "\n");
        exit(1);
    }

    // Get input files from all possible sources:
    // 
    inputFilenames = [[NSMutableArray alloc] init];
    inputFiles = [[NSMutableArray alloc] init];
    if (inputFileList != nil)
    {
        // Add files from the list file
        NSString *listContent;
        if ([inputFileList isEqualToString:@"-"])
        {
            NSData *data = 
                [[NSFileHandle fileHandleWithStandardInput] readDataToEndOfFile];
            listContent = [[NSString alloc] initWithData:data 
                                                encoding:NSUTF8StringEncoding]; 

        }
        else
            listContent = [[NSString alloc] 
                       initWithContentsOfFile:inputFileList
                                     encoding:NSUTF8StringEncoding
                                        error:&error];
        
        if (listContent == nil) {
            ABLog(@"Error reading file at %@\n%@", 
                  inputFileList, [error localizedFailureReason]);
            usage(argv[0]);
            exit(1);
        }

        NSArray *filesList = [listContent componentsSeparatedByString: @"\n"];
        for (NSString *file in filesList)
            if ([file length] > 0)
                [inputFilenames addObject:file];
    }

    // Now get input files from the remain of arguments
    while (optind < argc) 
    {
        NSString *path = [NSString stringWithUTF8String:argv[optind]];
        [inputFilenames addObject:path];
        optind++;
    }

    if ([inputFilenames count] == 0)
    {
        fprintf(stderr, "No input file specified\n");
        usage(argv[0]);
        exit(1);
    }
    
    // check if we have chapter markers in file list
    for (NSString *path in inputFilenames) { 
        int len = [path length];
        if (len == 0)
            continue;
        
        // is it chapter marker?
        if ((len > 2) && ([path characterAtIndex:0] == '@') 
            && ([path characterAtIndex:(len-1)] == '@')) {
            if (withChapters) {
                fprintf(stderr, "You can not use -e/-E and chapter marks together\n");
                exit(1);
            }
            withChapters = YES;
            break;
        }
    }

    // create implicit first chapter. It wil be overriden
    // if files list starts with chapter marker
    Chapter *curChapter = [[Chapter alloc] init];
    for (NSString *path in inputFilenames) { 
        int len = [path length];
        
        if (len == 0)
            continue;
        
        // is it chapter marker?
        if ((len > 2) && ([path characterAtIndex:0] == '@')
            && ([path characterAtIndex:(len-1)] == '@')) {
            NSString *chapterName = [path substringWithRange:NSMakeRange(1, len-2)];
            curChapter = [[Chapter alloc] init];
            curChapter.name = chapterName;
            [chapters addObject:curChapter];
            continue;
        }
            
        AudioFile *file = [[AudioFile alloc] initWithPath:path];
        
        if (withChapters) {
            if (eachFileIsChapter) {
                Chapter *chapter = [[Chapter alloc] init];
                chapter.name = makeChapterName(chapterNameFormat, 
                                               [chapters count], file);
                [chapter addFile:file];
                [chapters addObject:chapter];
            }
            else {
                // at this point we should have at least one item in chapters
                // list. If there is none - the first element of files list is
                // not chapter mark and we should add our implicit marker
                if ([chapters count] == 0)
                    [chapters addObject:curChapter];
                
                [curChapter addFile:file];
            }

        }
        [inputFiles addObject:file];
    }
    
    // Feed files to binder
    [binder setOutputFile:outFile];
    for (AudioFile *file in inputFiles) 
        [binder addInputFile:file];
    
    binder.channels = channels;
    binder.sampleRate = samplerate;
    
    if (bitrate) {
        BOOL found = NO;
        NSArray *validBitrates = [binder validBitrates];
        for (NSNumber *rate in validBitrates) {
            if ([rate intValue] == bitrate) {
                binder.bitrate = bitrate;
                found = YES;
                break;
            }
        }
        
        if (!found) {
            fprintf(stderr, "Invalid bitrate value %d, valid values:\n    ", bitrate/1000);
            bool first = YES;
            for (NSNumber *rate in validBitrates) {
                if (!first)
                    fprintf(stderr, ", ");
                fprintf(stderr, "%d", [rate intValue]/1000);
                first = NO;
            }
            fprintf(stderr, "\n");
            exit(1);
        }
    }
    
    // Setup delegate, it will print progress messages on console
    delegate = [[ConsoleDelegate alloc] init];
    [delegate setQuiet:quiet];
    [delegate setVerbose:verbose];
    [delegate setSkipErrors:skipErrors];
    [binder setDelegate:delegate];   

    if (![binder convert])
    {
        ABLog(@"Conversion failed");
        exit(255);
    }
    
    NSArray *volumes = [binder volumeNames];
    int totalTracks = [volumes count];
    if (!quiet) {
        printf("Adding metadata, it may take a while...");
        fflush(stdout);
    }
    
    int track = 1;
    for (NSString *volumeName in volumes) {
        MP4File *mp4 = [[MP4File alloc] initWithFileName:volumeName];
        mp4.artist = bookAuthor;
        if (totalTracks > 1)
            mp4.title = [NSString stringWithFormat:@"%@ #%02d", bookTitle, track];
        else
            mp4.title = bookTitle;
        mp4.album = bookTitle;
        mp4.coverFile = coverFile;
        mp4.tracksTotal = totalTracks;
        mp4.track = track;
        [mp4 updateFile];
        [mp4 release];
        track++;
    }
    
    if (!quiet)
        printf("done\n");

    if ([chapters count]) {
        if (!quiet) {
            printf("Adding chapter markers, it may take a while...");
            fflush(stdout);
        }
        
        addChapters([outFile UTF8String], chapters);
        if (!quiet)
            printf("done\n");
    }

    [pool drain];
    return 0;
}
