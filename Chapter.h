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

#import <Cocoa/Cocoa.h>
#import "AudioFile.h"

@interface Chapter : NSObject

@property (copy) NSString *name;
@property (retain) NSMutableArray *files;

- (id) copy;
- (void) addFile:(AudioFile *)file;
- (void) addFiles:(NSArray *)newFiles;
- (BOOL) containsFile:(AudioFile*)file;
- (NSUInteger) indexOfFile:(AudioFile*)file;
- (AudioFile*) fileAtIndex:(NSInteger)index;
- (void) removeFile:(AudioFile*)file;
- (void) insertFile:(AudioFile*)file atIndex:(NSInteger)index;
- (int) totalFiles;
- (Chapter*) splitAtFile:(AudioFile*)file;
- (UInt32) totalDuration;
- (void) sortUsingDecriptor:(NSSortDescriptor*)descriptor;

@end
