//
//  Copyright (c) 2009-2016 Oleksandr Tymoshenko <gonzo@bluezbox.com>
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
#include <getopt.h>

#import "AudioBinder.h"
#import "AudioBookVolume.h"
#import "ABBLog.h"
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
    printf("Usage: %s [-Aehqsv] [-c 1|2] [-r samplerate] [-a author] [-t title] [-i filelist] "
           "-o outfile [@chapter_1@ infile @chapter_2@ ...]\n", cmd);
    printf("\t-a author\tset book author\n");
    printf("\t-b bitrate\tset bitrate (KBps)\n");
    printf("\t-c 1|2\t\tnumber of channels in audiobook. Default: 2\n");
    printf("\t-C file.png\tcover image\n");
    printf("\t-e\t\talias for -E ''\n");
    printf("\t-E template\tmake each file a chapter with name defined by template\n");
    printf("\t\t\t    %%N - chapter number\n");
    printf("\t\t\t    %%a - artis (obtained from source file)\n");
    printf("\t\t\t    %%t - title (obtained from source file)\n");
    printf("\t-g genre\tbook genre\n");
    printf("\t-h\t\tshow this message\n");
    printf("\t-i file\t\tget input files list from file, \"-\" for standard input\n");
    printf("\t-l hours\t\tsplit audiobook to volumes max # hours long\n");    
    printf("\t-o outfile\t\taudiobook output file\n");
    printf("\t-q\t\tquiet mode (no output)\n");
    printf("\t-r rate\t\tsample rate of audiobook. Default: 44100\n");
    printf("\t-s\t\tskip errors and go on with conversion\n");
    printf("\t-t title\tset book title\n");
    printf("\t-v\t\tprint some info on files being converted\n");
    
}

NSString *makeChapterName(NSString *format, NSUInteger chapterNum, AudioFile *file)
{

    NSString *numStr = [[NSString stringWithFormat:@"%d", chapterNum + 1] retain];
    NSMutableString *name = [[NSMutableString stringWithString:format] retain];

    [name replaceOccurrencesOfString:@"%a" 
                          withString:file.artist
                             options:NSLiteralSearch 
                               range:NSMakeRange(0, [name length])];
 
    [name replaceOccurrencesOfString:@"%t" 
                          withString:file.name 
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
    AudioBinder *binder = [[AudioBinder alloc] init];
    NSString *bookAuthor = nil;
    NSString *bookTitle = nil;
    NSString *outFile = nil;
    NSString *inputFileList = nil;
    NSString *coverFile = nil;
    NSString *bookGenre = nil;
    NSMutableArray *inputFilenames;
    NSMutableArray *inputFiles;
    NSError *error;
    ConsoleDelegate *delegate;
    BOOL verbose = NO;
    BOOL quiet = NO;
    BOOL skipErrors = NO;
    int channels = 2;
    float samplerate = 44100.;
    int bitrate = 0;
    BOOL withChapters = NO;
    BOOL eachFileIsChapter = NO;
    UInt64 maxVolumeDuration = 0;
    NSString *chapterNameFormat;
    NSMutableArray *currentChapters = [[NSMutableArray alloc] init];
    NSMutableArray *volumeChapters = [[NSMutableArray alloc] init];
    
    NSZombieEnabled = YES;
    while ((c = getopt(argc, argv, "a:Ab:c:C:eE:g:hi:l:o:qr:st:v")) != -1) {
        switch (c) {
            case 'h':
                usage(argv[0]);
                exit(0);
            case 'a':
                bookAuthor = [NSString stringWithUTF8String:optarg];
                break;
            case 'g':
                bookGenre = [NSString stringWithUTF8String:optarg];
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
            case 'l':
                maxVolumeDuration = atoi(optarg)*3600; // convert to seconds
                break;
            case 'o':
                outFile = [NSString stringWithUTF8String:optarg];
                break;
            default:
                usage(argv[0]);
                exit(1);
        }
    }
    
    // Do we have output file et al?
    if (outFile == nil)
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
            ABBLog(@"Error reading file at %@\n%@", 
                  inputFileList, [error localizedFailureReason]);
            usage(argv[0]);
            exit(1);
        }

        NSArray *linesList = [listContent componentsSeparatedByCharactersInSet:
                                            [NSCharacterSet characterSetWithCharactersInString:@"\r\n"]];
        for (NSString *line in linesList) {
            NSString *file = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if ([file length] > 0)
                [inputFilenames addObject:file];
        }
    }



    // Now get input files from the remain of arguments
    while (optind < argc) 
    {
        NSString *path = [NSString stringWithUTF8String:argv[optind]];
        if (inputFileList != nil) {
            fprintf(stderr, "-i list provided, ignoring file list from command line\n");
            break;
        }
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
        NSUInteger len = [path length];
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
    
    // split output filename to base and extension in order to get 
    // filenames for consecutive volume files
    NSString *outFileBase = [[outFile stringByDeletingPathExtension] retain];
    NSString *outFileExt = [[outFile pathExtension] retain];


    // create implicit first chapter. It wil be overriden
    // if files list starts with chapter marker
    UInt64 estTotalDuration = 0;
    NSString *currentVolumeName = [outFile copy];
    int totalVolumes = 0;
    Chapter *curChapter = [[Chapter alloc] init];
    for (NSString *path in inputFilenames) { 
        NSUInteger len = [path length];
        
        if (len == 0)
            continue;
        
        // is it chapter marker?
        if ((len > 2) && ([path characterAtIndex:0] == '@')
            && ([path characterAtIndex:(len-1)] == '@')) {
            NSString *chapterName = [path substringWithRange:NSMakeRange(1, len-2)];
            curChapter = [[Chapter alloc] init];
            if (verbose) {
                ABBLog(@"Chapter marker detected: '%@'", chapterName);
            }
            curChapter.name = chapterName;
            [currentChapters addObject:curChapter];
            continue;
        }
        AudioFile *file = [[AudioFile alloc] initWithPath:path];
        if (maxVolumeDuration) {
            if ((estTotalDuration + [file.duration intValue]) > maxVolumeDuration*1000) {
                if ([inputFiles count] > 0) {
                    [binder addVolume:currentVolumeName files:inputFiles];
                    [inputFiles removeAllObjects];
                    estTotalDuration = 0;
                    totalVolumes++;
                    currentVolumeName = [[NSString alloc] initWithFormat:@"%@-%d.%@",
                                         outFileBase, totalVolumes, outFileExt];
                    // restart chapter
                    [volumeChapters addObject:currentChapters];
                    currentChapters = [[NSMutableArray alloc] init];
                    Chapter *c = [[Chapter alloc] init];
                    c.name = curChapter.name;
                    curChapter = c;
                }
                else {
                    fprintf(stderr, "%s: duration (%d sec) is larger than the maximum volume duration (%lld sec.)\n",
                            [path UTF8String], [file.duration intValue]/1000, maxVolumeDuration);
                    exit(1);
                }
            }
        }
        
        [inputFiles addObject:file];
        estTotalDuration += [file.duration intValue];
        
        if (withChapters) {
            if (eachFileIsChapter) {
                Chapter *chapter = [[Chapter alloc] init];
                chapter.name = makeChapterName(chapterNameFormat, 
                                               [currentChapters count], file);
                [chapter addFile:file];
                [currentChapters addObject:chapter];
            }
            else {
                // at this point we should have at least one item in chapters
                // list. If there is none - the first element of files list is
                // not chapter mark and we should add our implicit marker
                if ([currentChapters count] == 0)
                    [currentChapters addObject:curChapter];
                
                [curChapter addFile:file];
            }
        }
    }
    
    // Add last volume to the binder
    [binder addVolume:currentVolumeName files:inputFiles];
    // add chapters for last volume
    [volumeChapters addObject:currentChapters];

    
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
        ABBLog(@"Conversion failed");
        exit(255);
    }
    
    NSArray *volumes = [binder volumes];
    NSUInteger totalTracks = [volumes count];
    if (!quiet) {
        printf("Adding metadata, it may take a while...");
        fflush(stdout);
    }
    
    int track = 1;
    for (AudioBookVolume *v in volumes) {
        NSString *volumeName = v.filename;
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
        if (bookGenre != nil)
            mp4.genre = bookGenre;
        if (totalTracks > 1)
            mp4.gaplessPlay = YES;
        [mp4 updateFile];
        [mp4 release];
        track++;
    }
    
    if (!quiet)
        printf("done\n");

    if ([currentChapters count]) {
        if (!quiet) {
            printf("Adding chapter markers, it may take a while...");
            fflush(stdout);
        }
        int idx = 0;
        for (AudioBookVolume *v in volumes) {
            addChapters([v.filename UTF8String], [volumeChapters objectAtIndex:idx]);
            idx++;
        }
        if (!quiet)
            printf("done\n");
    }
    
    if (!quiet)
        printf("done\n");
    
    return 0;
}
