//
//  PrefsController.m
//  AudioBookBinder
//
//  Created by Oleksandr Tymoshenko on 10-03-29.
//  Copyright 2010 Bluezbox Software. All rights reserved.
//

#import "PrefsController.h"
#import "AudioBinder.h"
#import "ConfigNames.h"

#import "Sparkle/SUUpdater.h"

#define DESTINATION_FOLDER 0
#define DESTINATION_ITUNES 2

#define KVO_CONTEXT_BITRATES_AFFECTED   @"BitratesChanged"

@implementation PrefsController

@synthesize validBitrates;

- (void) awakeFromNib
{
    [_folderPopUp selectItemAtIndex:0];
    
#ifdef APP_STORE_BUILD    
    [updateLabel setHidden:YES];
    [updateButton setHidden:YES];
#else
    [updateButton bind:@"value" toObject:[SUUpdater sharedUpdater] withKeyPath:@"automaticallyChecksForUpdates" options:nil];
#endif

    [self updateValidBitrates];
    
    [[NSUserDefaults standardUserDefaults] addObserver:self
               forKeyPath:kConfigChannels
                  options:0
                  context:KVO_CONTEXT_BITRATES_AFFECTED];
    
    [[NSUserDefaults standardUserDefaults] addObserver:self
                                            forKeyPath:kConfigSampleRate
                                               options:0
                                               context:KVO_CONTEXT_BITRATES_AFFECTED];
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
            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
#ifdef APP_STORE_BUILD
            
            NSData* data = [folderURL bookmarkDataWithOptions:NSURLBookmarkCreationWithSecurityScope includingResourceValuesForKeys:nil relativeToURL:nil error:nil];
            [defaults setObject:data forKey:kConfigDestinationFolderBookmark];
            // Menu item is bound to DestinationFolder key so let AppStore
            // build set it as well
#endif
            NSString * folder = [folderURL path];
            [defaults setObject:folder forKey:kConfigDestinationFolder];
        }
        [_folderPopUp selectItemAtIndex:DESTINATION_FOLDER];
        [_saveAsFolderPopUp selectItemAtIndex:DESTINATION_FOLDER];
    }];
}


- (void) updateValidBitrates
{
    // Initialize samplerate/channels -> avail bitrates
    AudioBinder *tmpBinder = [[AudioBinder alloc] init];
    
    // setup channels/samplerate
    tmpBinder.channels = [[NSUserDefaults standardUserDefaults] integerForKey:kConfigChannels];
    tmpBinder.sampleRate = [[NSUserDefaults standardUserDefaults] floatForKey:kConfigSampleRate];
    self.validBitrates = [tmpBinder validBitrates];
    [self fixupBitrate];
    
}

- (void) fixupBitrate
{
    int bitrate = [[NSUserDefaults standardUserDefaults] integerForKey:kConfigBitrate];
    int newBitrate;
    int distance = bitrate;
    
    for (NSNumber *n in validBitrates) {
        if (labs([n integerValue] - bitrate) < distance) {
            distance = labs([n integerValue] - bitrate);
            newBitrate = [n integerValue];
        }
    }
    
    if (newBitrate != bitrate) {
        [[NSUserDefaults standardUserDefaults] setInteger:newBitrate forKey:kConfigBitrate];
    }
}

//whenever an observed key path changes, this method will be called
- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context;
{
    if (context == KVO_CONTEXT_BITRATES_AFFECTED) {
        [self updateValidBitrates];
    }
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
