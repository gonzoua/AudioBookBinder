//
//  Chapter.h
//  AudioBookBinder
//
//  Created by Oleksandr Tymoshenko on 10-06-11.
//  Copyright 2010 Bluezbox Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "AudioFile.h"

@interface Chapter : NSObject {
    NSString *name;
    NSMutableArray *files;
}

@property (readwrite, copy) NSString *name;
@property (readwrite, copy) NSMutableArray *files;

- (id) copy;
- (void) addFile:(AudioFile *)file;
- (void) addFiles:(NSArray *)newFiles;
- (BOOL) containsFile:(AudioFile*)file;
- (AudioFile*) fileAtIndex:(NSInteger)index;
- (void) removeFile:(AudioFile*)file;
- (void) insertFile:(AudioFile*)file atIndex:(NSInteger)index;
- (int) totalFiles;
- (Chapter*) splitAtFile:(AudioFile*)file;
- (UInt32) totalDuration;
- (void) sortUsingDecriptor:(NSSortDescriptor*)descriptor;
@end
