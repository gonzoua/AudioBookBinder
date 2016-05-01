//
//  Copyright (c) 2013-2016 Oleksandr Tymoshenko <gonzo@bluezbox.com>
//  All rights reserved.
// 
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions
//  are met:
//  1. Redistributions of source code must retain the above copyright
//     notice unmodified, this list of conditions, and the following
//     disclaimer.
//  2. Redistributions in binary form must reproduce the above copyright
//     notice, this list of conditions and the following disclaimer in the
//     documentation and/or other materials provided with the distribution.
// 
//  THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
//  ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
//  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
//  ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
//  FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
//  DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
//  OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
//  HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
//  LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
//  OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
//  SUCH DAMAGE.
//

#import "StatsManager.h"

#define MAX_BARS 5

@implementation StatsManager {
    NSMutableArray *converters;
    NSLock *lock;
    NSImage *appIcon;
}

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
