//
//  Copyright (c) 2010-2016 Oleksandr Tymoshenko <gonzo@bluezbox.com>
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
        [self selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
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
        [(id)self.delegate delKeyDown:self];
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
    }
}

@end
