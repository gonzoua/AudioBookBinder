//
//  PrefsController.m
//  AudioBookBinder
//
//  Created by Oleksandr Tymoshenko on 10-03-29.
//  Copyright 2010 Bluezbox Software. All rights reserved.
//

#import "PrefsController.h"

#define DESTINATION_FOLDER 0
#define DESTINATION_ITUNES 2

@implementation PrefsController

- (void) awakeFromNib
{
    [_folderPopUp selectItemAtIndex:0];
#ifdef notyet    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [_folderPopUp selectItemAtIndex: [defaults boolForKey: @"DestinationiTunes"] ? DESTINATION_ITUNES : DESTINATION_FOLDER];
#endif
    
#ifdef APP_STORE_BUILD    
    [updateLabel setHidden:YES];
    [updateButton setHidden:YES];
#endif
}    

- (void) folderSheetShow: (id) sender
{
    NSOpenPanel * panel = [NSOpenPanel openPanel];
    
    [panel setPrompt: NSLocalizedString(@"Select", "Preferences -> Open panel prompt")];
    [panel setAllowsMultipleSelection: NO];
    [panel setCanChooseFiles: NO];
    [panel setCanChooseDirectories: YES];
    [panel setCanCreateDirectories: YES];
    
    [panel beginSheetForDirectory: nil file: nil types: nil
                   modalForWindow: [self window] modalDelegate: self didEndSelector:
     @selector(folderSheetClosed:returnCode:contextInfo:) contextInfo: nil];
}

- (void) folderSheetClosed: (NSOpenPanel *) openPanel returnCode: (int) code contextInfo: (void *) info
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if (code == NSOKButton)
    {
        [_folderPopUp selectItemAtIndex:DESTINATION_FOLDER];
        
        NSString * folder = [[openPanel filenames] objectAtIndex:0];
        [defaults setObject:folder forKey: @"DestinationFolder"];
#ifdef notyet
        [defaults setBool:NO forKey: @"DestinationiTunes"];
#endif
    }
    else
    {
        //reset if cancelled
        [_folderPopUp selectItemAtIndex:DESTINATION_FOLDER];
#ifdef notyet        
         [defaults boolForKey:@"DestinationiTunes"] ? DESTINATION_ITUNES : DESTINATION_FOLDER];    
#endif
    }
}

- (void) destinationiTunes: (id) sender
{
    [[NSUserDefaults standardUserDefaults] 
     setBool:([_folderPopUp indexOfSelectedItem] == DESTINATION_ITUNES ? YES : NO)
          forKey: @"DestinationiTunes"];
}


@end
