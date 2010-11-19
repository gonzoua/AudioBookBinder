//
//  NSOutlineView_Extension.m
//  AudioBookBinder
//
//  Created by Oleksandr Tymoshenko on 10-02-14.
//  Copyright 2010 Bluezbox Software. All rights reserved.
//

#import "NSOutlineView_Extension.h"

@implementation NSOutlineView(MyExtensions)

- (NSArray *) selectedItems {
    NSMutableArray *items = [NSMutableArray array];
    NSIndexSet *selectedRows = [self selectedRowIndexes];

    if (selectedRows != nil) {
        for (NSInteger row = [selectedRows firstIndex]; 
             row != NSNotFound; row = [selectedRows indexGreaterThanIndex:row]) {
            [items addObject:[self itemAtRow:row]];
        }
    }

    return items;
}

- (void)setSelectedItem:(id)item {    
    NSInteger row = [self rowForItem:item];
    if (row >= 0)
        [self selectRow:row byExtendingSelection:NO];
}

- (void)setSelectedItems:(NSArray *)items {
    NSMutableIndexSet *newSelection = [[NSMutableIndexSet alloc] init];
    
    for (NSInteger i = 0; i < [items count]; i++) {
        NSInteger row = [self rowForItem:[items objectAtIndex:i]];
        if (row >= 0) {
            [newSelection addIndex:row];
        }
    }
    
    [self selectRowIndexes:newSelection byExtendingSelection:NO];
    
    [newSelection release];
}

- (void)keyDown:(NSEvent*)event_ {
    BOOL isDeleteKey = NO;
    BOOL isCollapseKey = NO;
    BOOL isExpandKey = NO;
    
    NSString *eventCharacters = [event_ characters];        
    if ([eventCharacters length]) {
        switch ([eventCharacters characterAtIndex:0]) {
            case NSDeleteFunctionKey:
            case NSDeleteCharFunctionKey:
            case NSDeleteCharacter:                                
                isDeleteKey = YES;
                break;
            case NSLeftArrowFunctionKey:
                isCollapseKey = YES;
                break;
            case NSRightArrowFunctionKey:
                isExpandKey = YES;
                break;
            default:
                break;
        }
    }
    
    if (isDeleteKey)
        [self.delegate delKeyDown:self];
    else if (isCollapseKey)
        [self doCollapse];
    else if (isExpandKey)
        [self doExpand];
    else
        [super keyDown:event_];
}

- (void)doExpand
{
    NSIndexSet *selectedRows = [self selectedRowIndexes];
    
    if (selectedRows == nil)
        return;
    
    NSMutableArray *items = [[NSMutableArray alloc] init];
    for (NSInteger row = [selectedRows firstIndex]; 
         row != NSNotFound; row = [selectedRows indexGreaterThanIndex:row]) {
        id item = [self itemAtRow:row];
        if([self isExpandable:item])
            [items addObject:item];
    }
    
    for(id item in items)
        [self expandItem:item];
    
    [items release];
}

- (void)doCollapse
{
    NSIndexSet *selectedRows = [self selectedRowIndexes];
    
    if (selectedRows == nil)
        return;
    
    if ([selectedRows count] == 1) {
        NSInteger row = [selectedRows firstIndex];
        id item = [self itemAtRow:row];
        // select chapter row if it's a file and if it's a chapter - collapse
        if ([self isExpandable:item])
            [self collapseItem:item];
        else {
            id parent = [self parentForItem:item];
            if (parent != nil)
                [self setSelectedItem:parent];
        }
    }   
    else {
        // multiple selection rules:
        //    - if only !expandable items - ignore
        //    - collapse and select all expandable items
        
        NSMutableArray *items = [[NSMutableArray alloc] init];

        for (NSInteger row = [selectedRows firstIndex]; 
             row != NSNotFound; row = [selectedRows indexGreaterThanIndex:row]) {
            id item = [self itemAtRow:row];
            if([self isExpandable:item])
                [items addObject:item];
        }
        if ([items count]) {
            for(id item in items)
                [self collapseItem:item];
            [self setSelectedItems:items];
        }
        [items release];
    }
}

@end
