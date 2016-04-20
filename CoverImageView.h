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
    NSString *coverImageFilename;
    NSMutableDictionary *attributes;
    NSString *string;
    NSColor *highlightedColor, *normalColor;
    BOOL highlighted;
}

@property (readwrite, strong) NSImage *coverImage;
@property (readwrite, strong) NSString *coverImageFilename;

- (void) drawStringCenteredIn: (NSRect) bounds;
- (void) prepareAttributes;
- (void) resetImage;
- (BOOL) haveCover;
- (BOOL) shouldConvert;

@end
