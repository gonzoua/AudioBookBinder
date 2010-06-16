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
    NSMutableArray *_files;
}

@property (readwrite, copy) NSString *name;

- (void) addFile:(AudioFile *)file;
- (BOOL) containsFile:(AudioFile*)file;
- (UInt32) totalDuration;
@end
