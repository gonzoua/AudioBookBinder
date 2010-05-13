//
//  CoverImageView.h
//  AudioBookBinder
//
//  Created by Oleksandr Tymoshenko on 10-05-07.
//  Copyright 2010 Bluezbox Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface CoverImageView : NSView {
    NSImage *coverImage;
    NSMutableDictionary *attributes;
    NSString *string;
    NSColor *highlightedColor, *normalColor;
    BOOL highlighted;
}

@property (readwrite, copy) NSImage *coverImage;

- (void) dealloc;
- (void) drawStringCenteredIn: (NSRect) bounds;
- (void) prepareAttributes;
@end
