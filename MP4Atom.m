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

#import "MP4Atom.h"


@implementation MP4Atom

-(id) initWithName: (NSString*)atom andLength:(UInt32)length;
{
    [super init];

    _offset = 0;
    _name = [[NSString alloc] initWithString:atom];
    _length = length;

    return self;
}

-(id) initWithHeaderData: (NSData*)data andOffset: (UInt64)offset
{
    [super init];

    _offset = offset;
    NSRange range;
    range.length = 4;
    range.location = 0;
    [data getBytes:&_length range:range];
    
    // convert from BE byte order
    _length = ntohl(_length);
    
    range.location = 4;
    _name = [[NSString alloc] initWithData:[data subdataWithRange:range]
                                  encoding:NSMacOSRomanStringEncoding]; 
    return self;
}

-(NSData*)encode
{
    struct {
        UInt32 beLength;
        char name[5];
    } hdr;

    hdr.beLength = htonl(_length);
    NSAssert([_name getCString:hdr.name maxLength:5 encoding:NSMacOSRomanStringEncoding],
            @"Failed to convert tag name");
    NSData *data = [NSData dataWithBytes:&hdr length:8];
    return data;
}

-(UInt32) length
{
    return _length;
}

-(void) setLength: (UInt32)length
{
    _length = length;
}

-(NSString*) name
{
    NSString *s = [[NSString alloc] initWithString:_name];
    return [s autorelease];
}

-(UInt64) offset
{
    return _offset;
}

@end
