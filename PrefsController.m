//
//  PrefsController.m
//  AudioBookBinder
//
//  Created by Oleksandr Tymoshenko on 10-03-29.
//  Copyright 2010 Bluezbox Software. All rights reserved.
//

#import "PrefsController.h"
#import "Sparkle/SUUpdater.h"
#define DESTINATION_FOLDER 0
#define DESTINATION_ITUNES 2

@implementation PrefsController

- (void) awakeFromNib
{
    [_folderPopUp selectItemAtIndex:0];
    
#ifdef APP_STORE_BUILD    
    [updateLabel setHidden:YES];
    [updateButton setHidden:YES];
#else
    [updateButton bind:@"value" toObject:[SUUpdater sharedUpdater] withKeyPath:@"automaticallyChecksForUpdates" options:nil];
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
    
    [panel beginSheetModalForWindow:[self window] completionHandler:^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton) {
            NSURL *folderURL = [panel URL];

#ifdef APP_STORE_BUILD
            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
            
            NSData* data = [folderURL bookmarkDataWithOptions:NSURLBookmarkCreationWithSecurityScope includingResourceValuesForKeys:nil relativeToURL:nil error:nil];
            [defaults setObject:data forKey: @"DestinationFolderBookmark"];
            // Menu item is bound to DestinationFolder key so let AppStore
            // build set it as well
#endif
            NSString * folder = [folderURL path];
            [defaults setObject:folder forKey: @"DestinationFolder"];
        }
        [_folderPopUp selectItemAtIndex:DESTINATION_FOLDER];
        [_saveAsFolderPopUp selectItemAtIndex:DESTINATION_FOLDER];
    }];
}

@end


@implementation VolumeLengthTransformer

+ (Class)transformedValueClass {
    return [NSString class];
}

+ (BOOL)allowsReverseTransformation {
    return NO;
}

- (id)transformedValue:(id)value {
	if (value != nil)
	{
        NSInteger len = [value intValue];
        if (len == 25)
            return @"--";
        else
            return [NSString stringWithFormat:@"%ld", (long)len];
	}
	
    return @"";
}
@end
