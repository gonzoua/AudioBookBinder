//
//  Chapter.m
//  AudioBookBinder
//
//  Created by Oleksandr Tymoshenko on 10-06-11.
//  Copyright 2010 Bluezbox Software. All rights reserved.
//

#import "Chapter.h"


@implementation Chapter

@synthesize name;

- (id) init
{
    if (self = [super init]) {
        _files = [[NSMutableArray alloc] init];
        name = nil;
    }
    
    return self;
}

- (void) addFile:(AudioFile *)file
{
    [_files addObject:file];
}

- (BOOL) containsFile:(AudioFile*)file
{
    return [_files containsObject:file];
}

- (UInt32) totalDuration
{
    UInt32 duration = 0;
    for (AudioFile *file in _files) {
        duration += [file duration];
    }
    
    return duration;
}

@end
