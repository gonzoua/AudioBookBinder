//
//  CoverImageView.h
//  AudioBookBinder
//
//  Created by Oleksandr Tymoshenko on 10-05-07.
//  Copyright 2010 Bluezbox Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#define ITUNES_COVER_SIZE 300

@interface CoverImageView : NSView {
    NSImage *coverImage, *scaledImage;
    NSMutableDictionary *attributes;
    NSString *string;
    NSColor *highlightedColor, *normalColor;
    BOOL highlighted;
}

@property (readwrite, retain) NSImage *coverImage;

- (void) dealloc;
- (void) drawStringCenteredIn: (NSRect) bounds;
- (void) prepareAttributes;

@end
