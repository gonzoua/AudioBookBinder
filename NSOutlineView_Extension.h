//
//  NSOutlineView_Extension.h
//  AudioBookBinder
//
//  Created by Oleksandr Tymoshenko on 10-02-14.
//  Copyright 2010 Bluezbox Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@protocol ExtendedNSOutlineViewDelegate <NSOutlineViewDelegate>

- (void) delKeyDown:(id)sender;

@end

@interface NSOutlineView (MyExtensions)

- (NSArray *)selectedItems;
- (void)setSelectedItem:(id)item;
- (void)setSelectedItems:(NSArray *)items;
- (void)doExpand;
- (void)doCollapse;

@end