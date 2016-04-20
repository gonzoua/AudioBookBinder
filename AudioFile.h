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
    NSString *file;
    NSNumber *duration;
    NSString *artist, *name, *album;
    BOOL valid;
}

@property(readwrite, copy) NSString *filePath;
@property(readwrite, copy) NSString *file;
@property(readwrite, copy) NSNumber *duration;
@property(readwrite, assign) BOOL valid;
@property(readwrite, copy) NSString *artist;
@property(readwrite, copy) NSString *name;
@property(readwrite, copy) NSString *album;



- (id) initWithPath:(NSString*)path;

// private function
- (void) updateInfo;
@end
