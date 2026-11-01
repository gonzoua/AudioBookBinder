import Foundation
import Testing
@testable import AudioBookBinder

// MARK: - Helpers

/// Opens `path` with mp4v2 and hands the fetched iTunes tags to `body`.
private func withTags<T>(_ path: String, _ body: (MP4Tags) throws -> T) throws -> T {
    let handle = try #require(MP4Read(path), "mp4v2 could not open the file")
    defer { MP4Close(handle, 0) }
    let tags = try #require(MP4TagsAlloc())
    defer { MP4TagsFree(tags) }
    try #require(MP4TagsFetch(tags, handle))
    return try body(tags.pointee)
}

private func str(_ p: UnsafePointer<CChar>?) -> String? {
    p.map { String(cString: $0) }
}

private struct Stream: Equatable {
    var tracks: UInt32
    var samples: UInt32
    var firstSample: [UInt8]
}

/// Audio payload fingerprint, so tests can verify mdat/stco survived the update.
private func streamInfo(_ path: String) throws -> Stream {
    let handle = try #require(MP4Read(path))
    defer { MP4Close(handle, 0) }
    let tracks = MP4GetNumberOfTracks(handle, nil, 0)
    let track = MP4FindTrackId(handle, 0, nil, 0)
    let samples = MP4GetTrackNumberOfSamples(handle, track)

    var data: UnsafeMutablePointer<UInt8>?
    var size: UInt32 = 0
    try #require(MP4ReadSample(handle, track, samples, &data, &size, nil, nil, nil, nil))
    defer { free(data) }
    let bytes = data.map { Array(UnsafeBufferPointer(start: $0, count: Int(size))) } ?? []
    return Stream(tracks: tracks, samples: samples, firstSample: bytes)
}

// MARK: - Tests

struct MP4FileTests {
    @Test func initFailsForMissingFile() {
        #expect(MP4File(fileName: "/nonexistent/dir/missing.m4b") == nil)
    }

    @Test func defaults() throws {
        try withAudioFile { path in
            let file = try #require(MP4File(fileName: path))
            #expect(file.genre == "Audiobooks")
            #expect(file.track == 0)
            #expect(file.tracksTotal == 0)
            #expect(file.gaplessPlay == false)
            #expect(file.title == nil)
        }
    }

    @Test func updateWritesTextTags() throws {
        try withAudioFile { path in
            let file = try #require(MP4File(fileName: path))
            file.title = "My Title"
            file.album = "My Album"
            file.artist = "My Artist"
            file.update()

            try withTags(path) { tags in
                #expect(str(tags.name) == "My Title")
                #expect(str(tags.album) == "My Album")
                #expect(str(tags.artist) == "My Artist")
                #expect(str(tags.genre) == "Audiobooks")
            }
        }
    }

    @Test func narratorIsStoredAsComposerAndNarratorItems() throws {
        try withAudioFile { path in
            let file = try #require(MP4File(fileName: path))
            file.narrator = "Reader"
            file.update()

            try withTags(path) { tags in
                #expect(str(tags.composer) == "Reader")
            }

            // ©nrt has no field in MP4Tags, so read it via the generic iTMF API.
            let handle = try #require(MP4Read(path))
            defer { MP4Close(handle, 0) }
            let code = "©nrt".cString(using: String.Encoding.macOSRoman)
            let list = try #require(MP4ItmfGetItemsByCode(handle, code))
            defer { MP4ItmfItemListFree(list) }
            #expect(list.pointee.size == 1)
            let data = list.pointee.elements[0].dataList.elements[0]
            let value = try #require(data.value)
            let size = Int(data.valueSize)
            #expect(String(decoding: UnsafeBufferPointer(start: value, count: size), as: UTF8.self) == "Reader")
        }
    }

    @Test func genreCanBeOverriddenOrOmitted() throws {
        try withAudioFile { path in
            let file = try #require(MP4File(fileName: path))
            file.genre = "Fiction"
            file.update()
            try withTags(path) { #expect(str($0.genre) == "Fiction") }
        }
        try withAudioFile { path in
            let file = try #require(MP4File(fileName: path))
            file.genre = nil
            file.update()
            try withTags(path) { #expect($0.genre == nil) }
        }
    }

    @Test func trackNumberWrittenOnlyForMultiTrackBooks() throws {
        try withAudioFile { path in
            let file = try #require(MP4File(fileName: path))
            file.track = 2
            file.tracksTotal = 5
            file.update()
            try withTags(path) { tags in
                let track = try #require(tags.track)
                #expect(track.pointee.index == 2)
                #expect(track.pointee.total == 5)
            }
        }
        try withAudioFile { path in
            let file = try #require(MP4File(fileName: path))
            file.track = 1
            file.tracksTotal = 1
            file.update()
            try withTags(path) { #expect($0.track == nil) }
        }
    }

    @Test func gaplessPlayFlag() throws {
        try withAudioFile { path in
            let file = try #require(MP4File(fileName: path))
            file.gaplessPlay = true
            file.update()
            try withTags(path) { tags in
                #expect(tags.gapless?.pointee == 1)
            }
        }
        try withAudioFile { path in
            let file = try #require(MP4File(fileName: path))
            file.update()
            try withTags(path) { #expect($0.gapless == nil) }
        }
    }

    @Test func coverImageEmbedded() throws {
        let cover = Data([0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3, 4])
        let coverPath = NSTemporaryDirectory() + "cover-\(UUID().uuidString).jpg"
        try cover.write(to: URL(fileURLWithPath: coverPath))
        defer { try? FileManager.default.removeItem(atPath: coverPath) }

        try withAudioFile { path in
            let file = try #require(MP4File(fileName: path))
            file.coverFile = coverPath
            file.update()
            try withTags(path) { tags in
                #expect(tags.artworkCount == 1)
                let art = tags.artwork.pointee
                #expect(Data(bytes: art.data, count: Int(art.size)) == cover)
            }
        }
    }

    @Test func missingCoverFileIsIgnored() throws {
        try withAudioFile { path in
            let file = try #require(MP4File(fileName: path))
            file.coverFile = "/nonexistent/cover.jpg"
            file.update()
            try withTags(path) { #expect($0.artworkCount == 0) }
        }
    }

    @Test func unicodeStringsRoundTrip() throws {
        try withAudioFile { path in
            let file = try #require(MP4File(fileName: path))
            file.title = "Тореадори з Васюківки"
            file.update()
            try withTags(path) { #expect(str($0.name) == "Тореадори з Васюківки") }
        }
    }
}
