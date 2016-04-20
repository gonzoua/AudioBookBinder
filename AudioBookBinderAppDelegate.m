//
//  AudioBookBinderAppDelegate.m
//  AudioBookBinder
//
//  Created by Oleksandr Tymoshenko on 10-02-04.
//  Copyright 2010 Bluezbox Software. All rights reserved.
//

#import "AudioBookBinderAppDelegate.h"
#import "ExpandedPathToPathTransformer.h"
#import "ExpandedPathToIconTransformer.h"
#import "AudioBinderWindowController.h"
#import "ConfigNames.h"

#import "Sparkle/SUUpdater.h"

#define TEXT_ACTION_REQUIRED    NSLocalizedString(@"User action required", nil)

#define TEXT_UPGRADE_HACK \
NSLocalizedString(@"It seems you are upgrading from previous version of Audiobook Binder. This upgrade introduces change in configuration format that requires your action: please confirm destination folder for audiobook files. This is one-time operation.", nil)

#ifdef APP_STORE_BUILD
BOOL requiresUpdateHack = NO;
static BOOL hackChecked = NO;
#endif

@implementation AudioBookBinderAppDelegate

+ (void) initialize
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
#ifdef APP_STORE_BUILD
    // make sure it's ran only once
    if (!hackChecked) {
        NSString *dir = [defaults stringForKey:kConfigDestinationFolder];
        NSURL *url = [[NSURL URLByResolvingBookmarkData:[defaults objectForKey:kConfigDestinationFolderBookmark] options:NSURLBookmarkResolutionWithSecurityScope relativeToURL:nil bookmarkDataIsStale:nil error:nil] retain];

        if ((dir != nil) && (url == nil)) {
            requiresUpdateHack = YES;
        }
        hackChecked = YES;
    }
#endif
    
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


- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {

#ifdef APP_STORE_BUILD
    NSURL *url;
    NSMenu *firstSubmenu = [[applicationMenu itemAtIndex:0] submenu];
    [firstSubmenu removeItemAtIndex:1];
    
    if (requiresUpdateHack) {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSString *currentDest = [defaults stringForKey:kConfigDestinationFolder];
        while ((url = [[NSURL URLByResolvingBookmarkData:[defaults objectForKey:kConfigDestinationFolderBookmark] options:NSURLBookmarkResolutionWithSecurityScope relativeToURL:nil bookmarkDataIsStale:nil error:nil] retain]) == nil) {
            
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
#else
    // XXX: hack to make autoupdates work
    [SUUpdater sharedUpdater];
#endif
    
    [self newAudiobookWindow:nil];
}

- (void)openChaptersHowTo:(id)sender
{
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://bluezbox.com/audiobookbinder/chapters.html"]];
}

- (void) checkForUpdates:(id)sender
{
#ifndef APP_STORE_BUILD
    [[SUUpdater sharedUpdater] checkForUpdates:sender];
#endif

}
- (IBAction) newAudiobookWindow: (id)sender
{
    AudioBinderWindowController *controller = [[AudioBinderWindowController alloc] initWithWindowNibName:@"AudioBinderWindow"];
    
    [controller showWindow:self];
    
    [[controller window] makeMainWindow];
}

- (BOOL) applicationShouldHandleReopen:(NSApplication *)theApplication
                     hasVisibleWindows:(BOOL)flag
{
    if (!flag)
        [self newAudiobookWindow:nil];
    
    return YES;
}

@end
