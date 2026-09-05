//
//  Copyright (c) 2009-2026 Oleksandr Tymoshenko <gonzo@bluezbox.com>
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

import Foundation

struct MP4Atom {
    var name: String
    var length: UInt32
    var offset: UInt64

    init(name: String, length: UInt32) {
        self.name = name
        self.length = length
        self.offset = 0
    }

    init?(headerData: Data, offset: UInt64) {
        guard headerData.count >= 8 else { return nil }
        self.offset = offset
        self.length = UInt32(bigEndian: headerData.withUnsafeBytes { $0.load(as: UInt32.self) })
        self.name = String(data: headerData.subdata(in: 4..<8), encoding: .macOSRoman) ?? ""
    }

    func encode() -> Data {
        var result = Data([
            UInt8(length >> 24),
            UInt8(length >> 16 & 0xFF),
            UInt8(length >> 8  & 0xFF),
            UInt8(length       & 0xFF),
        ])
        let nameBytes = (name.data(using: .macOSRoman) ?? Data(name.utf8)).prefix(4)
        result.append(contentsOf: nameBytes + Data(repeating: 0, count: 4 - nameBytes.count))
        return result
    }
}
