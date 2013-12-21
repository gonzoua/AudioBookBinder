//
//  StatsManager.m
//  AudioBookBinder
//
//  Created by Oleksandr Tymoshenko on 2013-12-18.
//  Copyright (c) 2013 Bluezbox Software. All rights reserved.
//

#import "StatsManager.h"

#define MAX_BARS 5

@implementation StatsManager

- (id)init {
    self = [super init];
    if (self) {
        converters = [[NSMutableArray alloc] init];
        lock = [[NSLock alloc] init];
        appIcon = [NSImage imageNamed: @"NSApplicationIcon"];
    }
    
    return self;
}

+ (StatsManager*)sharedInstance {
    static dispatch_once_t once;
    static StatsManager * sharedInstance;
    dispatch_once(&once, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

// lock should be locked
- (void)updateProgress
{
    if ([converters count] == 0) {
        [NSApp setApplicationIconImage:appIcon];

        return;
    }
    
    static NSImage *sProgressGradient = NULL;
    
    static const double kProgressBarHeight = 4.0/32;
    static const double kProgressBarHeightInIcon = 5.0/32;
    
    if (sProgressGradient == nil)
        sProgressGradient = [[NSImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"MiniProgressGradient" ofType:@"png"]];
    
    NSImage *dockIcon = [appIcon copyWithZone: nil];
    
    [dockIcon lockFocus];
    CGFloat yoff = 0;
    int bars = MIN(MAX_BARS, [converters count]);
    for (int i = bars - 1; i >=0 ; i--) {
        double height = kProgressBarHeightInIcon;
        NSSize s = [dockIcon size];
        NSRect bar = NSMakeRect(0, yoff + s.height * (height - kProgressBarHeight / 2),
                                s.width - 1, s.height * kProgressBarHeight);
        yoff += s.height * kProgressBarHeight + 5;
        
        [[NSColor whiteColor] set];
        [NSBezierPath fillRect: bar];
        
        NSRect done = bar;
        AudioBinderWindowController *c = [converters objectAtIndex:i];
        done.size.width *= c.currentProgress/100.;
        
        NSRect gradRect = NSZeroRect;
        gradRect.size = [sProgressGradient size];
        [sProgressGradient drawInRect: done fromRect: gradRect operation: NSCompositeCopy
                             fraction: 1.0];
        
        [[NSColor blackColor] set];
        [NSBezierPath strokeRect: bar];
    }
    
    [dockIcon unlockFocus];
    [NSApp setApplicationIconImage:dockIcon];
    [dockIcon release];
}

- (void)updateConverter:(id)converter {
    [lock lock];
    if (![converters containsObject:converter])
        [converters addObject:converter];
    [self updateProgress];
    [lock unlock];
}

- (void)removeConverter:(id)converter {
    [lock lock];
    if ([converters containsObject:converter]) {
        [converters removeObject:converter];
        [self updateProgress];
    }
    [lock unlock];
}


@end
