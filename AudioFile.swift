//
//  Copyright (c) 2010-2026 Oleksandr Tymoshenko <gonzo@bluezbox.com>
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
import AudioToolbox

@objc class AudioFile: NSObject {
    @objc var filePath: String
    @objc var file: String
    @objc var duration: NSNumber = NSNumber(value: -1)
    @objc var valid: Bool = false
    @objc var artist: String = ""
    @objc var name: String = ""
    @objc var album: String = ""

    @objc init?(path: String) {
        self.filePath = (path as NSString).expandingTildeInPath
        self.file = (self.filePath as NSString).lastPathComponent
        super.init()
        updateInfo()
    }

    private func updateInfo() {
        let url = URL(fileURLWithPath: filePath) as CFURL
        var audioFile: AudioFileID?
        guard AudioFileOpenURL(url, .readPermission, 0, &audioFile) == noErr,
              let audioFile else { return }
        defer { AudioFileClose(audioFile) }

        var durSize = UInt32(MemoryLayout<TimeInterval>.size)
        var dur: TimeInterval = 0
        if AudioFileGetProperty(audioFile, kAudioFilePropertyEstimatedDuration, &durSize, &dur) == noErr {
            duration = NSNumber(value: Int32(dur * 1000))
        }

        var writable: UInt32 = 0
        var size: UInt32 = 0
        guard AudioFileGetPropertyInfo(audioFile, kAudioFilePropertyInfoDictionary, &size, &writable) == noErr else {
            valid = true
            return
        }

        var infoDict: Unmanaged<CFDictionary>? = nil
        if AudioFileGetProperty(audioFile, kAudioFilePropertyInfoDictionary, &size, &infoDict) == noErr,
           let infoDict {
            let properties = infoDict.takeRetainedValue() as NSDictionary
            // Round-trip through UTF8String to strip embedded null bytes that some encoders add
            if let obj = properties["artist"] as? NSString, let cstr = obj.utf8String {
                artist = String(cString: cstr)
            }
            if let obj = properties["title"] as? NSString, let cstr = obj.utf8String {
                name = String(cString: cstr)
            }
            if let obj = properties["album"] as? NSString, let cstr = obj.utf8String {
                album = String(cString: cstr)
            }
        }

        valid = true
    }
}
