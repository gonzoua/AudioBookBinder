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

#import "QueueController.h"
#import "AudioBinderWindowController.h"

#define FILENAME_HEIGHT         20
#define FILENAME_TOP_MARGIN     1
#define PROGRESS_BAR_HEIGHT     12
#define STATUS_HEIGHT           16
#define STATUS_TOP_MARGIN       1
#define RIGHT_MARGIN            10
#define ICON_SIZE               NSMakeSize(32, 32)

@interface QueueController () {
    IBOutlet NSTableView *queuedControllers;
}
@property (nonatomic) NSMutableArray *controllers;
@end

@implementation QueueItemCell

- (id)init
{
    self = [super init];
    if (self) {
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    QueueItemCell* c = [[QueueItemCell alloc] init];
    c.audiobook = _audiobook;;
    c.progressBar = _progressBar;
    return c;
}

- (void)drawInteriorWithFrame:(NSRect)frame inView:(NSView*)view
{

    
    int offset = _progressBar ? 0 : (PROGRESS_BAR_HEIGHT / 3);
    
    NSString* fname = self.stringValue;
    
    NSRect fnameRect = frame;
    fnameRect.origin.x += fnameRect.size.height;
    fnameRect.origin.y += FILENAME_TOP_MARGIN + offset;
    fnameRect.size.width -= fnameRect.size.height + RIGHT_MARGIN;
    fnameRect.size.height = FILENAME_HEIGHT - FILENAME_TOP_MARGIN;
    
    NSColor* fnameColor;
    if (self.isHighlighted && [view.window isMainWindow] && [view.window firstResponder] == view) {
        fnameColor = [NSColor whiteColor];
    }
    else {
        fnameColor = [NSColor blackColor];
    }
    
    NSDictionary* fnameAttrs = [NSDictionary dictionaryWithObjectsAndKeys:
                                [[self class] fileNameStyle], NSParagraphStyleAttributeName,
                                [NSFont systemFontOfSize:12], NSFontAttributeName,
                                fnameColor, NSForegroundColorAttributeName,
                                nil];
    
    [fname drawInRect:fnameRect withAttributes:fnameAttrs];
    
    if (_progressBar) {
        NSRect progressRect = frame;
        progressRect.origin.x += progressRect.size.height;
        progressRect.origin.y += FILENAME_HEIGHT;
        progressRect.size.width -= progressRect.size.height + RIGHT_MARGIN;
        progressRect.size.height = PROGRESS_BAR_HEIGHT;
        _progressBar.frame = progressRect;
    }
    
    NSRect statusRect = frame;
    statusRect.origin.x += statusRect.size.height;
    statusRect.origin.y += FILENAME_HEIGHT + PROGRESS_BAR_HEIGHT + STATUS_TOP_MARGIN - offset;
    statusRect.size.width -= statusRect.size.height + RIGHT_MARGIN;
    statusRect.size.height = STATUS_HEIGHT - STATUS_TOP_MARGIN;
    
    NSColor* statusColor;
    statusColor = [NSColor grayColor];
    
    NSDictionary* statusAttrs = [NSDictionary dictionaryWithObjectsAndKeys:
                                 [[self class] statusStyle], NSParagraphStyleAttributeName,
                                 [NSFont systemFontOfSize:11], NSFontAttributeName,
                                 statusColor, NSForegroundColorAttributeName,
                                 nil];
    
    NSMutableString* statusStr = [NSMutableString string];
    
    [statusStr appendString:@"Books, books, books, books"];

    [statusStr drawInRect:statusRect withAttributes:statusAttrs];
}



+ (NSParagraphStyle*)fileNameStyle
{
    static NSMutableParagraphStyle* fileNameStyle = nil;
    if (!fileNameStyle) {
        fileNameStyle = [NSMutableParagraphStyle new];
        [fileNameStyle setAlignment:NSLeftTextAlignment];
        [fileNameStyle setLineBreakMode:NSLineBreakByTruncatingMiddle];
    }
    return fileNameStyle;
}

+ (NSParagraphStyle*)statusStyle
{
    static NSMutableParagraphStyle* statusStyle = nil;
    if (!statusStyle) {
        statusStyle = [NSMutableParagraphStyle new];
        [statusStyle setAlignment:NSLeftTextAlignment];
        [statusStyle setLineBreakMode:NSLineBreakByTruncatingTail];
    }
    return statusStyle;
}

@end

@implementation QueueController

- (instancetype)initWithWindowNibName:(NSString *)windowNibName
{
    self = [super initWithWindowNibName:windowNibName];
    NSLog(@"awake from NIB");
    if (self)
        self.controllers = [NSMutableArray new];
    return self;
}

- (void)windowDidLoad {
    [super windowDidLoad];
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
    [self.window setExcludedFromWindowsMenu:YES];
}

- (void)addBookWindowController:(AudioBinderWindowController*)controller {

    [self.controllers addObject:controller];
    [queuedControllers reloadData];
    [self showWindow:nil];
}

- (void)removeBookWindowController:(AudioBinderWindowController*)controller {
    [self.controllers removeObject:controller];
    [queuedControllers reloadData];
    [self showWindow:nil];
}

// NSTableViewDataSource
- (NSInteger) numberOfRowsInTableView:(NSTableView *)tableView
{

    return [self.controllers count];
}

//- (id) tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
//{
//    AudioBinderWindowController *controller = [controllers objectAtIndex:row];
//    return controller.title;
//}

//- (void)tableView:(NSTableView *)table willDisplayCell:(QueueItemCell*)cell forTableColumn:(NSTableColumn *)column row:(NSInteger)row
//{
//    NSLog(@"--> %@", cell);
//}

- (void)tableView:(NSTableView *)tableView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    NSLog(@"--> %@", cell);
}
@end
