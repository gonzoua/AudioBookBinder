//
//  AudioFile.h
//  AudioBookBinder
//
//  Created by Oleksandr Tymoshenko on 10-02-06.
//  Copyright 2010 Bluezbox Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface AudioFile : NSObject {
    NSString *filePath;
    NSString *name;
    NSInteger duration;
    NSString *artist, *title;
    BOOL valid;
}

@property(readwrite, copy) NSString *filePath;
@property(readwrite, copy) NSString *name;
@property(readwrite, assign) NSInteger duration;
@property(readwrite, assign) BOOL valid;
@property(readwrite, copy) NSString *artist;
@property(readwrite, copy) NSString *title;


- (id) initWithPath:(NSString*)path;
- (void) dealloc;

// private function
- (void) updateInfo;
@end
