//
//  NSOutlineView_Extension.h
//  AudioBookBinder
//
//  Created by Oleksandr Tymoshenko on 10-02-14.
//  Copyright 2010 Bluezbox Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSOutlineView (MyExtensions)

- (NSArray *)selectedItems;
- (void)setSelectedItems:(NSArray *)items;

@end