/*
 *  MetaEditor.h
 *  AudioBookBinder
 *
 *  Created by Oleksandr Tymoshenko on 10-06-09.
 *  Copyright 2010 Bluezbox Software. All rights reserved.
 *
 */
#ifndef __METAEDITOR__
#define __METAEDITOR__

typedef struct {
    uint32_t duration; // milliseconds
    char title[1024];
} Chapter;

int addChapters(const char *mp4, Chapter *chapters, int count);

#endif // __METAEDITOR__
