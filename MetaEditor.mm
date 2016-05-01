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

extern "C" {
#include "MetaEditor.h"
};

#include <vector>
#include <mp4v2/mp4v2.h>
#import "Chapter.h"

using namespace std;

int addChapters(const char *mp4, NSArray *chapters)
{ 
    MP4FileHandle h = MP4Modify( mp4 );
    
    if( h == MP4_INVALID_FILE_HANDLE )
        return -1;

    
    MP4TrackId refTrackId = MP4_INVALID_TRACK_ID;
    uint32_t trackCount = MP4GetNumberOfTracks( h );

    for( uint32_t i = 0; i < trackCount; ++i ) {
        MP4TrackId    id = MP4FindTrackId( h, i );
        const char* type = MP4GetTrackType( h, id );
        if( MP4_IS_AUDIO_TRACK_TYPE( type ) ) {
            refTrackId = id;
            break;
        }
    }
    
    if( !MP4_IS_VALID_TRACK_ID(refTrackId) )
        return -1;

    MP4Duration trackDuration = MP4GetTrackDuration( h, refTrackId ); 
    uint32_t trackTimeScale = MP4GetTrackTimeScale( h, refTrackId );
    trackDuration /= trackTimeScale;
    vector<MP4Chapter_t> mp4chapters;
    
    for (Chapter *chapter in chapters) {
        MP4Chapter_t chap;
        chap.duration = [chapter totalDuration];
        strncpy(chap.title, 
                [chapter.name UTF8String], sizeof(chap.title)-1);
        
        mp4chapters.push_back( chap );
    }
    
    MP4SetChapters(h, &mp4chapters[0], mp4chapters.size(), MP4ChapterTypeQt);
    MP4Close(h);
    
    return 0;
}
