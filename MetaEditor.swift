//
//  Copyright (c) 2011-2026 Oleksandr Tymoshenko <gonzo@bluezbox.com>
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

@objc class MetaEditor: NSObject {

    /// Writes QuickTime chapter markers into the MP4 file using mp4v2.
    /// Returns 0 on success (or when there is nothing to do), -1 on failure.
    @objc @discardableResult
    func addChapters(_ chapters: [Any], toFile filename: String) -> Int {
        let chapters = chapters.compactMap { $0 as? Chapter }
        if chapters.isEmpty {
            return 0
        }

        guard let handle = MP4Modify(filename, 0) else {
            return -1
        }
        defer { MP4Close(handle, 0) }

        // Chapters are attached to the first audio track
        var hasAudioTrack = false
        for i in 0..<MP4GetNumberOfTracks(handle, nil, 0) {
            let trackId = MP4FindTrackId(handle, UInt16(i), nil, 0)
            if let type = MP4GetTrackType(handle, trackId), strcasecmp(type, MP4_AUDIO_TRACK_TYPE) == 0 {
                hasAudioTrack = true
                break
            }
        }
        if !hasAudioTrack {
            return -1
        }

        var mp4chapters = chapters.map { chapter -> MP4Chapter_t in
            var chap = MP4Chapter_t()
            chap.duration = MP4Duration(chapter.totalDuration())
            withUnsafeMutableBytes(of: &chap.title) { buf in
                // Keep the last byte zero so the title stays NUL-terminated
                let utf8 = Array(chapter.name.utf8.prefix(buf.count - 1))
                buf.copyBytes(from: utf8)
            }
            return chap
        }

        MP4SetChapters(handle, &mp4chapters, UInt32(mp4chapters.count), MP4ChapterTypeQt)
        return 0
    }
}
