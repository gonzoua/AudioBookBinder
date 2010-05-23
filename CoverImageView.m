//
//  CoverImageView.m
//  AudioBookBinder
//
//  Created by Oleksandr Tymoshenko on 10-05-07.
//  Copyright 2010 Bluezbox Software. All rights reserved.
//

#import "CoverImageView.h"

@implementation CoverImageView

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        coverImage = nil;
        highlighted = NO;
        highlightedColor = [[NSColor blackColor] retain];
        normalColor = [[NSColor colorWithCalibratedWhite:0.4 alpha:1] retain];
        [self prepareAttributes];
        string = NSLocalizedString(@"⌘ + I\nor\nDrag Image Here", nil);
        [self registerForDraggedTypes:[NSArray arrayWithObjects:NSTIFFPboardType, 
                                       NSFilenamesPboardType, nil]];

    }
    return self;
}

- (void) dealloc {
    [attributes release];
    [super dealloc];
}

- (void) prepareAttributes {
    attributes = [[NSMutableDictionary alloc] init];
    [attributes setObject:[NSFont fontWithName:@"Helvetica" size:24]
                   forKey:NSFontAttributeName];


    NSMutableParagraphStyle *centeredStyle = 
        [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
    [centeredStyle setAlignment:NSCenterTextAlignment];

    [attributes setObject:[[centeredStyle copy] autorelease]
                   forKey:NSParagraphStyleAttributeName];

    [centeredStyle release];
    
}

- (NSImage *) coverImage
{
    return [coverImage retain];
}

- (void) setCoverImage:(NSImage *)image
{
    [coverImage release];
    
    if (image == nil)
    {
        coverImage = nil;
        return;
    }
    
    NSSize origSize = [image size];
    if ((origSize.width > ITUNES_COVER_SIZE) || (origSize.height > ITUNES_COVER_SIZE)) {
        NSSize scaledSize;
        if (origSize.width > origSize.height) {
            scaledSize.width = ITUNES_COVER_SIZE;
            scaledSize.height = origSize.height * ITUNES_COVER_SIZE/origSize.width;
        }
        else {
            scaledSize.height = ITUNES_COVER_SIZE;
            scaledSize.width = origSize.width * ITUNES_COVER_SIZE/origSize.height;                
        }
        
        NSImage *scaledImage = [[NSImage alloc] initWithSize:scaledSize];
        
        // Composite image appropriately
        [scaledImage lockFocus];
        [[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];
        [image drawInRect:NSMakeRect(0, 0, scaledSize.width, scaledSize.height) 
                    fromRect:NSMakeRect(0, 0, origSize.width, origSize.height)
                   operation:NSCompositeSourceOver 
                    fraction:1.0];
        [scaledImage unlockFocus];
        coverImage = scaledImage;
    }
    else
        coverImage = [image copy];
    [self setNeedsDisplay:YES];
}

- (void)drawStringCenteredIn: (NSRect)r 
{
    NSSize strSize = [string sizeWithAttributes:attributes];
    NSRect strRect;
    strRect.origin.x = r.origin.x + (r.size.width - strSize.width)/2;
    strRect.origin.y = r.origin.y + (r.size.height - strSize.height)/2;
    strRect.size = strSize;
    [string drawInRect:strRect withAttributes:attributes];
}

- (void)drawRect: (NSRect)dirtyRect 
{
    if (coverImage == nil) {
        NSColor *bgColor;
        if(highlighted) {
            bgColor = highlightedColor;
            [attributes setObject:highlightedColor 
                           forKey:NSForegroundColorAttributeName];
        
        }
        else {
            bgColor = normalColor;
            [attributes setObject:normalColor
                           forKey:NSForegroundColorAttributeName];	
        }
        float     borderWidth = 4.0;
        NSRect boxRect = [self bounds];
        NSRect bgRect = boxRect;
        bgRect = NSInsetRect(boxRect, borderWidth / 2.0, borderWidth / 2.0);
        bgRect = NSIntegralRect(bgRect);
        bgRect.origin.x += 0.5;
        bgRect.origin.y += 0.5;
        
        int minX = NSMinX(bgRect);
        int midX = NSMidX(bgRect);
        int maxX = NSMaxX(bgRect);
        int minY = NSMinY(bgRect);
        int midY = NSMidY(bgRect);
        int maxY = NSMaxY(bgRect);
        float radius = 25.0; 
        NSBezierPath *bgPath = [NSBezierPath bezierPath];
        
        // Bottom edge and bottom-right curve
        [bgPath moveToPoint:NSMakePoint(midX, minY)];
        [bgPath appendBezierPathWithArcFromPoint:NSMakePoint(maxX, minY)
                                         toPoint:NSMakePoint(maxX, midY)
                                          radius:radius];
        
        // Right edge and top-right curve
        [bgPath appendBezierPathWithArcFromPoint:NSMakePoint(maxX, maxY)
                                         toPoint:NSMakePoint(midX, maxY)
                                          radius:radius];
        
        // Top edge and top-left curve
        [bgPath appendBezierPathWithArcFromPoint:NSMakePoint(minX, maxY)
                                         toPoint:NSMakePoint(minX, midY)
                                          radius:radius];
        
        // Left edge and bottom-left curve
        [bgPath appendBezierPathWithArcFromPoint:bgRect.origin
                                         toPoint:NSMakePoint(midX, minY)
                                          radius:radius];
        [bgPath closePath];
        
        // [bgPath fill];
        [bgColor set];

        
        [bgPath setLineWidth:borderWidth];
        
        CGFloat arr[2];
        arr[0] = 5.0;
        arr[1] = 2.0;
        
        [bgPath setLineDash:arr count:2 phase:0.0];
        [bgPath setLineCapStyle:NSRoundLineCapStyle];
        [bgPath stroke];
        [self drawStringCenteredIn:[self bounds]];
    }
    else {
        NSRect viewSize = [self bounds];
        NSSize imageSize = [coverImage size];
        NSPoint orig;
        orig.x = (viewSize.size.width - imageSize.width) / 2;
        orig.y = (viewSize.size.height - imageSize.height) / 2;
		
        [coverImage compositeToPoint:orig operation:NSCompositeSourceOver];
    }
    
}

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
{
    if ([sender draggingSource] == self) {
        return NSDragOperationNone;
    }
    
    NSPasteboard *paste = [sender draggingPasteboard];
    //gets the dragging-specific pasteboard from the sender
    NSArray *types = [NSArray arrayWithObjects:NSTIFFPboardType, 
                      NSFilenamesPboardType, nil];
    //a list of types that we can accept
    NSString *desiredType = [paste availableTypeFromArray:types];
    NSData *carriedData = [paste dataForType:desiredType];
    
    if (nil == carriedData)
        return NSDragOperationNone;

    if ([desiredType isEqualToString:NSFilenamesPboardType])
    {
        //we have a list of file names in an NSData object
        NSArray *fileArray = [paste propertyListForType:@"NSFilenamesPboardType"];
        if ([fileArray count] > 1) {
            NSLog(@"multiple files");
            return NSDragOperationNone;
        }
    }
    
    highlighted = YES;
    [self setNeedsDisplay:YES];
    NSLog(@"draggingEntered: %d", highlighted);

    return NSDragOperationGeneric;
}

- (void)draggingExited:(id <NSDraggingInfo>)sender
{
    NSLog(@"draggingExited:");
    highlighted = NO;
    [self setNeedsDisplay:YES];
}

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender
{
    return YES;
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
    NSLog(@"performDragOperation");
    NSPasteboard *paste = [sender draggingPasteboard];
    //gets the dragging-specific pasteboard from the sender
    NSArray *types = [NSArray arrayWithObjects:NSTIFFPboardType, 
                      NSFilenamesPboardType, nil];
    //a list of types that we can accept
    NSString *desiredType = [paste availableTypeFromArray:types];
    NSData *carriedData = [paste dataForType:desiredType];
    
    if (nil == carriedData)
    {
        //the operation failed for some reason
        NSRunAlertPanel(@"Paste Error", @"Sorry, but the past operation failed", 
                        nil, nil, nil);
        return NO;
    }
    else
    {
        NSImage *newImage = nil;
        //the pasteboard was able to give us some meaningful data
        if ([desiredType isEqualToString:NSTIFFPboardType])
        {
            //we have TIFF bitmap data in the NSData object
            newImage = [[NSImage alloc] initWithData:carriedData];
        }
        else if ([desiredType isEqualToString:NSFilenamesPboardType])
        {
            //we have a list of file names in an NSData object
            NSArray *fileArray = [paste propertyListForType:@"NSFilenamesPboardType"];
            //be caseful since this method returns id.  
            //We just happen to know that it will be an array.
            NSString *path = [fileArray objectAtIndex:0];
            //assume that we can ignore all but the first path in the list
            newImage = [[NSImage alloc] initWithContentsOfFile:path];
            
            if (nil == newImage)
                return NO;
        }
        else
        {
            //this can't happen
            NSAssert(NO, @"This can't happen");
            return NO;
        }

        self.coverImage = newImage;

        [newImage release];
    }
    
    return YES;
}

- (void)concludeDragOperation:(id <NSDraggingInfo>)sender
{
    NSLog(@"concludeDragOperation:");
    highlighted = NO;
    [self setNeedsDisplay:YES];
}

- (void)keyDown:(NSEvent*)event_ {
    BOOL isDeleteKey = FALSE;
    
    NSString *eventCharacters = [event_ characters];        
    if ([eventCharacters length]) {
        switch ([eventCharacters characterAtIndex:0]) {
            case NSDeleteFunctionKey:
            case NSDeleteCharFunctionKey:
            case NSDeleteCharacter:                                
                isDeleteKey = YES;
                break;
            default:
                break;
        }
    }
    
    if (isDeleteKey) {
        self.coverImage = nil;
        [self setNeedsDisplay:YES];
    } else {
        [super keyDown:event_];
    }
}

- (BOOL)acceptsFirstResponder
{
    return YES;
}

@end
