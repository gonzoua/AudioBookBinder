//
//  Copyright (c) 2011-2016 Oleksandr Tymoshenko <gonzo@bluezbox.com>
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

#import "Chapter.h"

@implementation Chapter

- (id) init
{
    if (self = [super init]) {
        _files = [[NSMutableArray alloc] init];
    }
    
    return self;
}

- (id)copy
{
    Chapter *c = [[Chapter alloc] init];
    c.name = self.name;
    [c addFiles:self.files];
    return c;
}

- (void) addFile:(AudioFile *)file
{
    [self.files addObject:file];
}

- (void) addFiles:(NSArray *)newFiles
{
    [self.files addObjectsFromArray:newFiles];
}

- (BOOL) containsFile:(AudioFile*)file
{
    return [self.files containsObject:file];
}

- (NSUInteger) indexOfFile:(AudioFile*)file
{
    return [self.files indexOfObject:file];
}

- (int) totalFiles
{
    return [self.files count];
}

- (AudioFile*) fileAtIndex:(NSInteger)index
{
    return [self.files objectAtIndex:index];
}

- (void) removeFile:(AudioFile*)file
{
    [self.files removeObject:file];
}

- (void) insertFile:(AudioFile*)file atIndex:(NSInteger)index
{
    [self.files insertObject:file atIndex:index];
}

- (UInt32) totalDuration
{
    UInt32 duration = 0;
    for (AudioFile *file in self.files) {
        duration += [[file duration] intValue];
    }
    
    return duration;
}

// splits chapter into two. All files prior to given file
// remain in this chapter, the rest goes to newly-created 
// chapter 
- (Chapter*) splitAtFile:(AudioFile*)file
{

    NSUInteger idx = [self.files indexOfObject:file];
    if (idx == NSNotFound)
        return nil;
    Chapter *c = [[Chapter alloc] init];
    c.name = self.name;
    while (idx < [self.files count]) {
        AudioFile *f = [self.files objectAtIndex:idx];
        [c addFile:f];
        [self.files removeObjectAtIndex:idx];
    }
    
    return c;
}

- (void) sortUsingDecriptor:(NSSortDescriptor*)descriptor
{
    [self.files sortUsingDescriptors:[NSArray arrayWithObject:descriptor]];
}

@end
