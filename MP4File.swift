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
import UniformTypeIdentifiers

@objc class MP4File : NSObject {
    @objc var artist: String?
    @objc var narrator: String?
    @objc var album: String?
    @objc var title: String?
    @objc var coverFile: String?
    @objc var genre: String? = "Audiobooks"
    @objc var track: UInt16 = 0
    @objc var tracksTotal: UInt16 = 0
    @objc var gaplessPlay = false

    private let fileName: String

    @objc init?(fileName: String) {
        // Make sure mp4v2 can parse the file before handing out an instance
        guard let handle = MP4Read(fileName) else { return nil }
        MP4Close(handle, 0)
        self.fileName = fileName
    }

    @objc func update() -> Void {
        guard let handle = MP4Modify(fileName, 0) else {
            fatalError("Failed to open \(fileName) for modification")
        }
        defer { MP4Close(handle, 0) }
        guard let tags = MP4TagsAlloc() else {
            fatalError("Failed to allocate MP4 tags")
        }
        defer { MP4TagsFree(tags) }
        MP4TagsFetch(tags, handle)

        if let v = title { MP4TagsSetName(tags, v) }
        if let v = album { MP4TagsSetAlbum(tags, v) }
        if let v = artist { MP4TagsSetArtist(tags, v) }
        if let v = narrator { MP4TagsSetComposer(tags, v) }
        if track > 0 && tracksTotal > 1 {
            var trackTag = MP4TagTrack(index: track, total: tracksTotal)
            MP4TagsSetTrack(tags, &trackTag)
        }
        if gaplessPlay {
            var gapless: UInt8 = 1
            MP4TagsSetGapless(tags, &gapless)
        }
        if let v = genre { MP4TagsSetGenre(tags, v) }
        if let path = coverFile, let imageData = try? Data(contentsOf: URL(fileURLWithPath: path)) {
            setArtwork(imageData, type: Self.artworkType(forPath: path), in: tags)
        }

        MP4TagsStore(tags, handle)

        // MP4Tags has no field for the narrator item, so use the generic iTMF API
        if let v = narrator {
            setNarrator(v, in: handle)
        }
    }

    // MARK: - Private helpers

    private func setArtwork(_ imageData: Data, type: MP4TagArtworkType, in tags: UnsafePointer<MP4Tags>) {
        var bytes = [UInt8](imageData)
        bytes.withUnsafeMutableBytes { buf in
            var artwork = MP4TagArtwork(data: buf.baseAddress,
                                        size: UInt32(buf.count),
                                        type: type)
            MP4TagsAddArtwork(tags, &artwork)
        }
    }

    private static func artworkType(forPath path: String) -> MP4TagArtworkType {
        guard let type = UTType(filenameExtension: URL(fileURLWithPath: path).pathExtension) else {
            return MP4_ART_UNDEFINED
        }
        if type.conforms(to: .jpeg) { return MP4_ART_JPEG }
        if type.conforms(to: .png) { return MP4_ART_PNG }
        if type.conforms(to: .gif) { return MP4_ART_GIF }
        if type.conforms(to: .bmp) { return MP4_ART_BMP }
        return MP4_ART_UNDEFINED
    }

    // Stores the narrator in the ©nrt item, replacing any existing one
    private func setNarrator(_ value: String, in handle: MP4FileHandle) {
        guard let code = "©nrt".cString(using: .macOSRoman) else { return }

        if let existing = MP4ItmfGetItemsByCode(handle, code) {
            for i in 0..<Int(existing.pointee.size) {
                MP4ItmfRemoveItem(handle, &existing.pointee.elements[i])
            }
            MP4ItmfItemListFree(existing)
        }

        guard let item = MP4ItmfItemAlloc(code, 1) else { return }
        defer { MP4ItmfItemFree(item) }

        // MP4ItmfItemFree releases the value with free(), so hand it a malloc'ed copy
        let utf8 = Array(value.utf8)
        let buffer = malloc(max(utf8.count, 1))!.assumingMemoryBound(to: UInt8.self)
        buffer.update(from: utf8, count: utf8.count)

        item.pointee.dataList.elements[0].typeCode = MP4_ITMF_BT_UTF8
        item.pointee.dataList.elements[0].value = buffer
        item.pointee.dataList.elements[0].valueSize = UInt32(utf8.count)
        MP4ItmfAddItem(handle, item)
    }
}
