/*
 *  MetaEditor.cpp
 *  AudioBookBinder
 *
 *  Created by Oleksandr Tymoshenko on 10-06-09.
 *  Copyright 2010 Bluezbox Software. All rights reserved.
 *
 */

extern "C" {
#include "MetaEditor.h"
};
#include <vector>
#include <mp4v2/mp4v2.h>

using namespace std;
const double CHAPTERTIMESCALE = 1000.0;

extern "C" int setBookInfo(const char *mp4, const char *author, const char *title)
{
    MP4FileHandle h = MP4Modify( mp4 );
    fprintf( stderr, "Begin\n");
    if ( h == MP4_INVALID_FILE_HANDLE ) {
        fprintf( stderr, "Could not open '%s'... aborting\n", mp4 );
        return -1;
    }
    /* Read out the existing metadata */
    const MP4Tags* mdata = MP4TagsAlloc();
    MP4TagsFetch(mdata, h);
    MP4TagsSetArtist(mdata, author);
    /* Write out all tag modifications, free and close */
    MP4TagsStore( mdata, h );
    MP4TagsFree( mdata );
    MP4Close( h ); 
    fprintf( stderr, "Done\n");
    
    return 0;
}

int addChapters(const char *mp4, Chapter *chapters, int count)
{ 
    MP4FileHandle h = MP4Modify( mp4 );
    
    if( h == MP4_INVALID_FILE_HANDLE )
        return -1;

    
    MP4TrackId refTrackId = MP4_INVALID_TRACK_ID;
    uint32_t trackCount = MP4GetNumberOfTracks( h );

    for( uint32_t i = 0; i < trackCount; ++i )
    {
        MP4TrackId    id = MP4FindTrackId( h, i );
        const char* type = MP4GetTrackType( h, id );
        if( MP4_IS_AUDIO_TRACK_TYPE( type ) )
        {
            refTrackId = id;
            break;
        }
    }
    
    if( !MP4_IS_VALID_TRACK_ID(refTrackId) )
        return -1;

    MP4Duration trackDuration = MP4GetTrackDuration( h, refTrackId ); 
    uint32_t trackTimeScale = MP4GetTrackTimeScale( h, refTrackId );
    NSLog(@"duration: %ld scale: %d", trackDuration, trackTimeScale);
    trackDuration /= trackTimeScale;
    vector<MP4Chapter_t> mp4chapters;
    
    for (int i = 0; i < count; i++) 
    {
        MP4Chapter_t chap;
        chap.duration = chapters[i].duration;
        strncpy(chap.title, chapters[i].title, sizeof(chap.title)-1);
        
        mp4chapters.push_back( chap );
    }
    
    MP4SetChapters(h, &mp4chapters[0], mp4chapters.size(), MP4ChapterTypeQt);
    MP4Close(h);
    
    return 0;
}
