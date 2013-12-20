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
#import "Sparkle/SUUpdater.h"
#import "AudioBinderWindowController.h"

#ifdef APP_STORE_BUILD
static BOOL requiresUpdateHack = NO;
static BOOL hackChecked = NO;
#endif

@implementation AudioBookBinderAppDelegate

+ (void) initialize
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
#ifdef APP_STORE_BUILD
    // make sure it's ran only once
    if (!hackChecked) {
        NSString *dir = [defaults stringForKey:@"DestinationFolder"];
        NSURL *url = [[NSURL URLByResolvingBookmarkData:[defaults objectForKey:@"DestinationFolderBookmark"] options:NSURLBookmarkResolutionWithSecurityScope relativeToURL:nil bookmarkDataIsStale:nil error:nil] retain];

        if ((dir != nil) && (url == nil)) {
            requiresUpdateHack = YES;
        }
        hackChecked = YES;
    }
#endif
    
    NSMutableDictionary *appDefaults = [NSMutableDictionary
                                        dictionaryWithObject:[NSNumber numberWithInt:2] forKey:@"Channels"];
    // for checkbox "add to itunes"
    [appDefaults setObject:[NSNumber numberWithBool:YES] forKey:@"AddToiTunes"];
    [appDefaults setObject:@"44100" forKey:@"SampleRate"];
    [appDefaults setObject:@"128000" forKey:@"Bitrate"];
    [appDefaults setObject:[NSNumber numberWithInt:12] forKey:@"MaxVolumeSize"];
    [appDefaults setObject:[NSNumber numberWithBool:YES] forKey:@"SortAudioFiles"];
    
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
    
    [appDefaults setObject:musicPath forKey:@"DestinationFolder"];
    

#ifdef notyet
    [appDefaults setObject:[NSNumber numberWithBool:YES] forKey:@"DestinationiTunes"];
#endif    
    [defaults registerDefaults:appDefaults];    
    
    //set custom value transformers    
    ExpandedPathToPathTransformer * pathTransformer = [[[ExpandedPathToPathTransformer alloc] init] autorelease];
    [NSValueTransformer setValueTransformer: pathTransformer forName: @"ExpandedPathToPathTransformer"];
    ExpandedPathToIconTransformer * iconTransformer = [[[ExpandedPathToIconTransformer alloc] init] autorelease];
    [NSValueTransformer setValueTransformer: iconTransformer forName: @"ExpandedPathToIconTransformer"];
}


- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {

 
#ifdef APP_STORE_BUILD     
    NSMenu *firstSubmenu = [[applicationMenu itemAtIndex:0] submenu];
    [firstSubmenu removeItemAtIndex:1];
    
    if (requiresUpdateHack) {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSString *currentDest = [defaults stringForKey:@"DestinationFolder"];
        while ((url = [[NSURL URLByResolvingBookmarkData:[defaults objectForKey:@"DestinationFolderBookmark"] options:NSURLBookmarkResolutionWithSecurityScope relativeToURL:nil bookmarkDataIsStale:nil error:nil] retain]) == nil) {
            
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
                [defaults setObject:data forKey: @"DestinationFolderBookmark"];
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
    AudioBinderWindowController *controller = [[[AudioBinderWindowController alloc] initWithWindowNibName:@"AudioBinderWindow"] retain];
    
    [controller showWindow:self];
    
    [[controller window] makeMainWindow];
}



@end
