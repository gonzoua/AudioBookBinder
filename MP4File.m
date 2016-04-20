//
//  Copyright (c) 2009, Oleksandr Tymoshenko <gonzo@bluezbox.com>
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

#import "ABLog.h"
#import "MP4Atom.h"
#import "MP4File.h"

// 4M seems to be reasonable buffer
#define TMP_BUFFER_SIZE 16*1024*1024

@implementation MP4File

@synthesize artist, album, title, coverFile, genre;
@synthesize track, tracksTotal, gaplessPlay;


-(id) initWithFileName: (NSString*)fileName
{
    if (!(self = [super init])) return nil;
    
    _fh = [NSFileHandle fileHandleForUpdatingAtPath:fileName];
    self.artist = nil;
    self.album = nil;
    self.title = nil;
    self.coverFile = nil;
    self.genre = @"Audiobooks";
    
    track = tracksTotal = 0;
    gaplessPlay = NO;

    UInt64 pos = 0;
    NSData *buffer;
    UInt64 end = [_fh seekToEndOfFile];
    [_fh seekToFileOffset:0]; 
    
    while (pos < end) {
        // load atoms
        buffer = [_fh readDataOfLength:8];
        MP4Atom *atom = [[MP4Atom alloc] initWithHeaderData:buffer 
                                                  andOffset:pos];
        pos += [atom length];
        [_fh seekToFileOffset:pos];
    }

    return self;
}


-(id) findAtom: (NSString*)atomName
{
    UInt64 pos = 0;
    UInt64 end = 0;
    NSData *buffer;
    id result = nil;
    
    NSMutableArray *chunks = [[NSMutableArray alloc] 
        initWithArray:[atomName componentsSeparatedByString: @"."]];

    end = [_fh seekToEndOfFile];
    [_fh seekToFileOffset:0]; 
    
    while (pos < end) {
        // load atoms
        buffer = [_fh readDataOfLength:8];
        MP4Atom *atom = [[MP4Atom alloc] initWithHeaderData:buffer 
                                                  andOffset:pos];
        if ([[atom name] isEqualToString: [chunks objectAtIndex:0]])
        {
            end = pos + [atom length];
            // meta header has 4 bytes of data after header
            if ([[atom name] isEqualToString: @"meta"])
                pos += 12;
            else
                // skip only atom header and start with content
                pos += 8;
            [chunks removeObjectAtIndex:0];
            if ([chunks count] == 0)
            {
                result = atom;
                break;
            }
        }
        else
            pos += [atom length];

        [_fh seekToFileOffset:pos];
    }

    return result;
}



/*
 * This function assumes that we work with fresh, newly-created file,
 * there should be no "meta" atom 
 */
-(BOOL) updateFile
{
    NSMutableData *hdlrContent = [NSMutableData dataWithData:[self encodeHDLRAtom]];
    MP4Atom *freeAtom = [self findAtom:@"free"];
    BOOL haveIlstAtom, haveMetaAtom, haveUdtaAtom;
    MP4Atom *moovAtom = [self findAtom:@"moov"];
    MP4Atom *udtaAtom = [self findAtom:@"moov.udta"];
    MP4Atom *metaAtom = [self findAtom:@"moov.udta.meta"];
    MP4Atom *ilstAtom = [self findAtom:@"moov.udta.meta.ilst"];
    
    NSAssert(moovAtom != nil, 
            @"File contains no moov atom");
    NSAssert(freeAtom != nil, 
             @"File contains no free atom");

    haveUdtaAtom = (udtaAtom != nil);
    haveMetaAtom = (metaAtom != nil);
    haveIlstAtom = (ilstAtom != nil);
    
    NSMutableData *newAtomsData = [[NSMutableData alloc] init];
    if (title != nil)
        [newAtomsData appendData:[self encodeMetaDataAtom:@"©nam" 
                                                value:[title dataUsingEncoding:NSUTF8StringEncoding]
                                                 type:ITUNES_METADATA_STRING_CLASS]];

    if (album != nil)
        [newAtomsData appendData:[self encodeMetaDataAtom:@"©alb" 
                                                value:[album dataUsingEncoding:NSUTF8StringEncoding] 
                                                 type:ITUNES_METADATA_STRING_CLASS]];    
    if (artist != nil)
        [newAtomsData appendData:[self encodeMetaDataAtom:@"©ART" 
                                                value:[artist dataUsingEncoding:NSUTF8StringEncoding] 
                                                 type:ITUNES_METADATA_STRING_CLASS]];


    if (track && (tracksTotal > 1)) {
        short bytes[4];
        bytes[0] = bytes[3] = 0;
        bytes[1] = htons(track);
        bytes[2] = htons(tracksTotal);
        NSData * data = [[NSData alloc] initWithBytes:bytes length:8];
        [newAtomsData appendData:[self encodeMetaDataAtom:@"trkn" 
                                                value:data
                                                 type:ITUNES_METADATA_IMPLICIT_CLASS]];
    }
    
    if (gaplessPlay) {        
        char pgap = 1;
        NSData * data = [[NSData alloc] initWithBytes:&pgap length:1];
        [newAtomsData appendData:[self encodeMetaDataAtom:@"pgap" 
                                                    value:data
                                                     type:ITUNES_METADATA_UINT8_CLASS]];
    }

    if (genre != nil)
        [newAtomsData appendData:[self encodeMetaDataAtom:@"©gen" 
                                            value:[genre dataUsingEncoding:NSUTF8StringEncoding] 
                                             type:ITUNES_METADATA_STRING_CLASS]];
    
    if (coverFile != nil)
    {
        NSData *fileData = [NSData dataWithContentsOfFile:coverFile];
        if (fileData)
            [newAtomsData appendData:[self encodeMetaDataAtom:@"covr" 
                                                value:fileData 
                                                 type:ITUNES_METADATA_IMAGE_CLASS]];
    }
    
    UInt32 additionalLength = [newAtomsData length];
 
    if (ilstAtom)
    {
        [ilstAtom setLength:[ilstAtom length] + additionalLength];
        [self fixupAtom:ilstAtom];
    }
    else
    {
        additionalLength += 4 + 4; // length and name
        ilstAtom = [[MP4Atom alloc] initWithName:@"ilst" andLength:additionalLength];
    }
    
    if (metaAtom)
    {
        [metaAtom setLength:[metaAtom length] + additionalLength];
        [self fixupAtom:metaAtom];
    }
    else 
    {
        // length, name and misterious junk
        additionalLength += [hdlrContent length] + 4 + 4 + 4;
        metaAtom = [[MP4Atom alloc] initWithName:@"meta" andLength:additionalLength];
    }
    if (udtaAtom)
    {
        [udtaAtom setLength:[udtaAtom length] + additionalLength];
        [self fixupAtom:udtaAtom];
    }
    else {
        additionalLength += 4 + 4; // length and name
        udtaAtom = [[MP4Atom alloc] initWithName:@"udta" andLength:additionalLength];        
    }

    NSMutableData *atomData = [NSMutableData data];
    if (!haveUdtaAtom)
        [atomData appendData:[udtaAtom encode]];
    
    if (!haveMetaAtom)
    {
        [atomData appendData:[metaAtom encode]];
        UInt32 flags = 0;
        // append 
        [atomData appendBytes:&flags length:4];
        [atomData appendData:hdlrContent];
    }
    
    if (!haveIlstAtom)
        [atomData appendData:[ilstAtom encode]];
    
    [atomData appendData:newAtomsData];

    UInt64 newAtomsOffset = [moovAtom offset] + [moovAtom length];

    // is there enough free space for udta tag?
    if ((freeAtom == nil) || ([freeAtom length] < additionalLength))
    {
        MP4Atom *mdatAtom = [self findAtom:@"mdat"];
        NSAssert(mdatAtom != nil, @"Failed to find mdat atom");
        [self reserveSpace:additionalLength at:newAtomsOffset];
        // Make sure mdat atom comes after moov atom
        if ([mdatAtom offset] > [moovAtom offset])
                [self fixSTCOAtomBy:additionalLength];
    }
    else
    {
        // update free atom
        [freeAtom setLength:[freeAtom length] - additionalLength];
        [freeAtom setOffset:[freeAtom offset] + additionalLength];
        [self fixupAtom:freeAtom];
    }
            
    // write newly created atoms
    [_fh seekToFileOffset:newAtomsOffset];
    [_fh writeData:atomData];

    // update moov atom
    [moovAtom setLength:[moovAtom length] + additionalLength];    
    [self fixupAtom:moovAtom];
    return TRUE;
}

-(void) fixupAtom: (MP4Atom*)atom
{
    [_fh seekToFileOffset:[atom offset]];
    [_fh writeData:[atom encode]];    
}

/*
 * Encode iTunes metadata atoms
 */
-(NSData*) encodeMetaDataAtom: (NSString*)name value:(NSData*)value 
                         type:(UInt32)type
                        
{
    UInt32 dataAtomSize = 
            [value length] + 
            4 + 4 + 4 + 4;
    UInt32 atomSize = dataAtomSize + 4 + 4;
    MP4Atom *atom = [[MP4Atom alloc] initWithName:name andLength:atomSize];
    NSMutableData *data = [NSMutableData dataWithData:[atom encode]];
    MP4Atom *dataAtom = [[MP4Atom alloc] initWithName:@"data" 
                                            andLength:dataAtomSize];
    [data appendData:[dataAtom encode]];
    // version and flags
    type = htonl(type);
    [data appendBytes:&type length:4];
    // null data
    UInt32 zeroData = 0;
    [data appendBytes:&zeroData length:4];
    [data appendData:value]; 

    return [NSData dataWithData: data];
}

/*
 * Create hdlr atom. Without this atom iTunes refuses to accept file metadata 
 */
-(NSData*) encodeHDLRAtom  
{
    MP4Atom *hdlrAtom = [[MP4Atom alloc] initWithName:@"hdlr" andLength:34];
    UInt32 zeroData = 0;
    const char *tmp = "mdir";
    const char *tmp2 = "appl";
    NSMutableData *data = [NSMutableData dataWithData:[hdlrAtom encode]];

    [data appendBytes:&zeroData length:4];    
    [data appendBytes:&zeroData length:4];
    [data appendBytes:tmp length:4];
    [data appendBytes:tmp2 length:4];
    [data appendBytes:&zeroData length:4];
    [data appendBytes:&zeroData length:4];
    [data appendBytes:&zeroData length:2];
    
    return [NSData dataWithData: data];
}


/*
 * Inserts size bytes at offset in file 
 */
-(void) reserveSpace:(UInt64)size at:(UInt64)offset
{
    @autoreleasepool {
        UInt64 end = [_fh seekToEndOfFile];

#if 0
        NSLog(@"size: %lld, start offset: %lld, file size: %lld", 
                size, offset, end);
#endif
        do {
            UInt64 bufferSize = MIN(end - offset, TMP_BUFFER_SIZE);
            [_fh seekToFileOffset:(end - bufferSize)];
            NSData *buffer = [_fh readDataOfLength:bufferSize];
            if ([buffer length] == 0)
                break;
            [_fh seekToFileOffset:(end - [buffer length]) + size];
#if 0
            NSLog(@"from: %lld, to: %lld, %lld bytes", (end - bufferSize),
                  (end - [buffer length]) + size, [buffer length]);
#endif
            [_fh writeData:buffer];
            end -= [buffer length];
        } while(end > offset);

    }
}

/*
 * stco atom is an index table that contains offsets of 
 * mdata "chunks" from the files start. Formar:
 * [length] [atom] [version/flags] [nentries] [offs1] ...
 */
-(void) fixSTCOAtomBy:(UInt64)shift
{
    UInt32 entries, i, offset;
    NSRange r;
    MP4Atom *stcoAtom = [self findAtom:@"moov.trak.mdia.minf.stbl.stco"];
    NSAssert(stcoAtom != nil, 
                    @"Failed to find moov.trak.mdia.minf.stbl.stco atom");

    NSData *origTable;
    [_fh seekToFileOffset:[stcoAtom offset]+12]; // size, tag and vesrion/flags
    origTable = [_fh readDataOfLength:[stcoAtom length] - 12];
    NSMutableData *fixedTable = [[NSMutableData alloc] initWithData:origTable];
    [fixedTable getBytes:&entries length:4];

    entries = ntohl(entries);
    r.location = 4;
    r.length = 4;
    for (i = 0 ; i < entries; i++)
    {
        [fixedTable getBytes:&offset range:r];
        offset = htonl(ntohl(offset) + shift);
        [fixedTable replaceBytesInRange:r withBytes:&offset];
        r.location += 4;
    }

    [_fh seekToFileOffset:[stcoAtom offset]+12]; // size, tag and vesrion/flags
    [_fh writeData:fixedTable];
}

@end
