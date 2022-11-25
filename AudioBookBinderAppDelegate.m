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


#import "AudioBookBinderAppDelegate.h"
#import "ExpandedPathToPathTransformer.h"
#import "ExpandedPathToIconTransformer.h"
#import "AudioBinderWindowController.h"
#import "QueueController.h"
#import "ConfigNames.h"

#define TEXT_ACTION_REQUIRED    NSLocalizedString(@"User action required", nil)

#define TEXT_UPGRADE_HACK \
NSLocalizedString(@"It seems you are upgrading from previous version of Audiobook Binder. This upgrade introduces change in configuration format that requires your action: please confirm destination folder for audiobook files. This is one-time operation.", nil)

BOOL requiresUpdateHack = NO;
static BOOL hackChecked = NO;

@interface AudioBookBinderAppDelegate() {
    IBOutlet NSMenu *applicationMenu;

    NSMutableArray *windowControllers;
}

@end

@implementation AudioBookBinderAppDelegate

+ (void) initialize
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    // make sure it's ran only once
    if (!hackChecked) {
        NSString *dir = [defaults stringForKey:kConfigDestinationFolder];
        NSURL *url = [NSURL URLByResolvingBookmarkData:[defaults objectForKey:kConfigDestinationFolderBookmark] options:NSURLBookmarkResolutionWithSecurityScope relativeToURL:nil bookmarkDataIsStale:nil error:nil];

        if ((dir != nil) && (url == nil)) {
            requiresUpdateHack = YES;
        }
        hackChecked = YES;
    }
    
    NSMutableDictionary *appDefaults = [NSMutableDictionary
                                        dictionaryWithObject:[NSNumber numberWithInt:2] forKey:kConfigChannels];
    // for checkbox "add to itunes"
    [appDefaults setObject:[NSNumber numberWithBool:YES] forKey:kConfigAddToITunes];
    [appDefaults setObject:@"44100" forKey:kConfigSampleRate];
    [appDefaults setObject:@"128000" forKey:kConfigBitrate];
    [appDefaults setObject:[NSNumber numberWithInt:12] forKey:kConfigMaxVolumeSize];
    [appDefaults setObject:[NSNumber numberWithBool:YES] forKey:kConfigSortAudioFiles];
    [appDefaults setObject:[NSNumber numberWithBool:YES] forKey:kConfigChaptersEnabled];
    
    // for pop-up button Destination Folder
	NSArray* paths = NSSearchPathForDirectoriesInDomains(
                                                         NSMusicDirectory,
                                                         NSUserDomainMask,
                                                         YES);
    
    NSString *musicPath;
    if ([paths count])
        musicPath = [paths objectAtIndex:0];
    else // just use something
        musicPath = NSHomeDirectory();
    
    [appDefaults setObject:musicPath forKey:kConfigDestinationFolder];
    

    [defaults registerDefaults:appDefaults];    
    
    //set custom value transformers    
    ExpandedPathToPathTransformer * pathTransformer = [[ExpandedPathToPathTransformer alloc] init];
    [NSValueTransformer setValueTransformer: pathTransformer forName: @"ExpandedPathToPathTransformer"];
    ExpandedPathToIconTransformer * iconTransformer = [[ExpandedPathToIconTransformer alloc] init];
    [NSValueTransformer setValueTransformer: iconTransformer forName: @"ExpandedPathToIconTransformer"];
}

- (id) init
{
    self = [super init];
    if (self) {
        windowControllers = [NSMutableArray new];
    }
    
    return self;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {

    NSURL *url;
    NSMenu *firstSubmenu = [[applicationMenu itemAtIndex:0] submenu];
    [firstSubmenu removeItemAtIndex:1];
    
    if (requiresUpdateHack) {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSString *currentDest = [defaults stringForKey:kConfigDestinationFolder];
        while ((url = [NSURL URLByResolvingBookmarkData:[defaults objectForKey:kConfigDestinationFolderBookmark] options:NSURLBookmarkResolutionWithSecurityScope relativeToURL:nil bookmarkDataIsStale:nil error:nil]) == nil) {
            
            NSAlert *a = [[NSAlert alloc] init];
            [a setMessageText:TEXT_ACTION_REQUIRED];

            [a setInformativeText:TEXT_UPGRADE_HACK];
            [a setAlertStyle:NSWarningAlertStyle];
            
            [a runModal];
            
            NSOpenPanel * panel = [NSOpenPanel openPanel];
            
            [panel setPrompt: NSLocalizedString(@"Select", nil)];
            [panel setAllowsMultipleSelection: NO];
            [panel setCanChooseFiles: NO];
            [panel setCanChooseDirectories: YES];
            [panel setCanCreateDirectories: YES];
            [panel setDirectoryURL:[NSURL fileURLWithPath:currentDest]];
            NSInteger result = [panel runModal];
            if (result == NSOKButton)
            {                
                NSURL *folderURL = [panel URL];
                NSData* data = [folderURL bookmarkDataWithOptions:NSURLBookmarkCreationWithSecurityScope includingResourceValuesForKeys:nil relativeToURL:nil error:nil];
                [defaults setObject:data forKey:kConfigDestinationFolderBookmark];
                [defaults synchronize];
                break;
            }
        }
    }
    self.queueController = [[QueueController alloc] initWithWindowNibName:@"QueueWindow"];
    
    [self newAudiobookWindow:nil];
}

- (void)openChaptersHowTo:(id)sender
{
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://bluezbox.com/audiobookbinder/chapters.html"]];
}

- (void) checkForUpdates:(id)sender
{

}
- (IBAction) newAudiobookWindow: (id)sender
{
    AudioBinderWindowController *controller = [[AudioBinderWindowController alloc] initWithWindowNibName:@"AudioBinderWindow"];
    
    [controller showWindow:self];
    
    [[controller window] makeMainWindow];
    [windowControllers addObject:controller];
}

- (BOOL) applicationShouldHandleReopen:(NSApplication *)theApplication
                     hasVisibleWindows:(BOOL)flag
{
    if (!flag)
        [self newAudiobookWindow:nil];
    
    return YES;
}

// Window delegate part

- (void)windowWillClose:(NSNotification *)notification
{
    AudioBinderWindowController *controller = nil;
    for (AudioBinderWindowController *c in windowControllers) {
        if (c.window == notification.object) {
            controller = c;
            break;
        }
    }
    
    if (controller)
        [windowControllers removeObject:controller];
}

- (void)windowDidResignKey:(NSNotification *)notification
{
    AudioBinderWindowController *controller = nil;
    for (AudioBinderWindowController *c in windowControllers) {
        if (c.window == notification.object) {
            controller = c;
            break;
        }
    }
    
    if (controller)
        [controller updateWindowTitle];
}

- (IBAction)showQueueWindow: (id)sender
{
    [self.queueController showWindow:nil];
}

@end
