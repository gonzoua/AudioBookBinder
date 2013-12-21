//
//  StatsManager.h
//  AudioBookBinder
//
//  Created by Oleksandr Tymoshenko on 2013-12-18.
//  Copyright (c) 2013 Bluezbox Software. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AudioBinderWindowController.h"

@interface StatsManager : NSObject {
    NSMutableArray *converters;
    NSLock *lock;
    NSImage *appIcon;
}

+ (StatsManager*)sharedInstance;

- (void)updateConverter:(id)converter;
- (void)removeConverter:(id)converter;

@end
