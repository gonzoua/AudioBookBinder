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

@synthesize length;
@synthesize offset;
@synthesize name;

-(id) initWithName: (NSString*)atom andLength:(UInt32)len;
{
    [super init];

    self.offset = 0;
    self.name = atom;
    self.length = len;

    return self;
}

-(id) initWithHeaderData: (NSData*)data andOffset: (UInt64)off
{
    UInt32 lLength;
    [super init];

    self.offset = off;
    NSRange range;
    range.length = 4;
    range.location = 0;
    [data getBytes:&lLength range:range];
    
    // convert from BE byte order
    self.length = ntohl(lLength);
    
    range.location = 4;
    NSString *lName = [[NSString alloc] initWithData:[data subdataWithRange:range]
                                            encoding:NSMacOSRomanStringEncoding];
    self.name = lName;
    [lName release];
    
    return self;
}

-(void) dealloc
{
    self.name = nil;
    [super dealloc];
}

-(NSData*)encode
{
    struct {
        UInt32 beLength;
        char name[5];
    } hdr;

    hdr.beLength = htonl(self.length);
    NSAssert([name getCString:hdr.name maxLength:5 encoding:NSMacOSRomanStringEncoding],
            @"Failed to convert tag name");
    NSData *data = [NSData dataWithBytes:&hdr length:8];
    return data;
}

@end
