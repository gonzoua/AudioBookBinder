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
        coverImageFilename = nil;

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

- (void) resetImage
{
    self.coverImageFilename = nil;
    self.coverImage = nil;
}

- (BOOL) haveCover
{
    
    return (coverImage != nil);
}

- (BOOL) shouldConvert
{
    NSString *ext;
	char ext_temp;
    int ch;
        
    // we care only about filename. If image was brough by dragging 
    // picture - it's converted to PNG
    if (coverImageFilename == nil)
        return YES;
    
    for (ch = [coverImageFilename length]; 
         ((ext_temp = [coverImageFilename characterAtIndex:(ch - 1)]) != '.') && (ch >= 0); ch--)
		;
	ext = [[coverImageFilename lowercaseString] substringFromIndex:ch];
    

	if ([ext isEqualToString:@"jpg"] || [ext isEqualToString:@"jpeg"])
		return NO;
	else if ([ext isEqualToString:@"png"])
		return NO;
	else // none of the above
		return YES;
}

- (NSImage *) coverImage
{
    return [coverImage retain];
}

- (NSString*) coverImageFilename {
    return [coverImageFilename retain];
}


- (void) setCoverImageFilename:(NSString *)imagePath
{
    if (coverImageFilename) {
        [coverImageFilename release];
        coverImageFilename = nil;
    }
    
    if (imagePath) {
        NSImage *img = [[NSImage alloc] initWithContentsOfFile:imagePath]; 
        self.coverImage = img;
        [img release];
        // invalid image, do not set image path
        if (img == nil)
            return;
    
        coverImageFilename = [imagePath retain];
    }
}


- (void) setCoverImage:(NSImage *)image
{
    [coverImage release];
    [scaledImage release];
    
    if (image == nil)
    {
        coverImage = nil;
        scaledImage = nil;
        return;
    }
    
    coverImage = [image copy];
   
    NSImageRep *rep = [[coverImage representations] objectAtIndex:0]; 
    [coverImage setScalesWhenResized:YES]; 
    [coverImage setSize:NSMakeSize([rep pixelsWide], [rep pixelsHigh])]; 
    
    NSSize origSize = NSMakeSize([rep pixelsWide], [rep pixelsHigh]);
    
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

        scaledImage = [[[NSImage alloc] initWithSize:scaledSize] retain];
        
        // Composite image appropriately
        [scaledImage lockFocus];
        [[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];
        [coverImage drawInRect:NSMakeRect(0, 0, scaledSize.width, scaledSize.height) 
                    fromRect:NSMakeRect(0, 0, origSize.width, origSize.height)
                   operation:NSCompositeSourceOver 
                    fraction:1.0];
        [scaledImage unlockFocus];
    }
    else {
        scaledImage = [coverImage copy];
    }

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
    if (scaledImage == nil) {
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
        NSSize imageSize = [scaledImage size];
        NSRect imageRect = NSMakeRect(0, 0, imageSize.width, imageSize.height);
        NSPoint orig;
        orig.x = (viewSize.size.width - imageSize.width) / 2;
        orig.y = (viewSize.size.height - imageSize.height) / 2;
        
        [scaledImage drawAtPoint:orig fromRect:imageRect operation:NSCompositeSourceOver fraction:1.0];
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
            [self resetImage];
            //we have TIFF bitmap data in the NSData object
            newImage = [[NSImage alloc] initWithData:carriedData];
            self.coverImage = newImage;
            [newImage release];
            if (newImage == nil)
                return NO;
        }
        else if ([desiredType isEqualToString:NSFilenamesPboardType])
        {
            //we have a list of file names in an NSData object
            NSArray *fileArray = [paste propertyListForType:@"NSFilenamesPboardType"];
            //be caseful since this method returns id.  
            //We just happen to know that it will be an array.
            NSString *path = [fileArray objectAtIndex:0];
            //assume that we can ignore all but the first path in the list
            
            self.coverImageFilename = path;
            
            if (coverImageFilename == nil)
                return NO;
        }
        else
        {
            //this can't happen
            NSAssert(NO, @"This can't happen");
            return NO;
        }

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
        [self resetImage];
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
