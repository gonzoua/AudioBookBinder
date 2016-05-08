//
//  QueueController.m
//  AudioBookBinder
//
//  Created by Oleksandr Tymoshenko on 5/8/16.
//  Copyright © 2016 Bluezbox Software. All rights reserved.
//

#import "QueueController.h"

@interface QueueController ()

@end

@implementation QueueController

- (void)windowDidLoad {
    [super windowDidLoad];
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
    [self.window setExcludedFromWindowsMenu:YES];
}

// NSTableViewDataSource
- (NSInteger) numberOfRowsInTableView:(NSTableView *)tableView
{
    return 3;
}

- (id) tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    return @"XXX";
}

@end
