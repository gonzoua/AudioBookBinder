//
//  Chapter.m
//  AudioBookBinder
//
//  Created by Oleksandr Tymoshenko on 10-06-11.
//  Copyright 2010 Bluezbox Software. All rights reserved.
//

#import "Chapter.h"


@implementation Chapter

@synthesize name, files;

- (id) init
{
    if (self = [super init]) {
        files = [[NSMutableArray alloc] init];
        name = nil;
    }
    
    return self;
}

- (void) addFile:(AudioFile *)file
{
    [files addObject:file];
}

- (void) addFiles:(NSArray *)newFiles
{
    [files addObjectsFromArray:newFiles];
}

- (BOOL) containsFile:(AudioFile*)file
{
    return [files containsObject:file];
}

- (int) totalFiles
{
    return [files count];
}

- (AudioFile*) fileAtIndex:(NSInteger)index
{
    return [files objectAtIndex:index];
}

- (void) removeFile:(AudioFile*)file
{
    [files removeObject:file];
}

- (void) insertFile:(AudioFile*)file atIndex:(NSInteger)index
{
    [files insertObject:file atIndex:index];
}


- (UInt32) totalDuration
{
    UInt32 duration = 0;
    for (AudioFile *file in files) {
        duration += [file duration];
    }
    
    return duration;
}

@end
