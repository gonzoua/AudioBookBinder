import Foundation
import Testing
@testable import AudioBookBinder

// MARK: - Helpers

private func makeChapter(_ name: String, filesDurationsMs: [Int32]) -> Chapter {
    let chapter = Chapter()
    chapter.name = name
    for (i, ms) in filesDurationsMs.enumerated() {
        let file = AudioFile(path: "/nonexistent/\(name)-\(i).mp3")!
        file.duration = NSNumber(value: ms)
        chapter.addFile(file)
    }
    return chapter
}

private struct ChapterInfo: Equatable {
    var title: String
    var durationMs: UInt64
}

/// Reads chapters back via the mp4v2 API.
private func readChapters(_ path: String) throws -> [ChapterInfo] {
    let handle = try #require(MP4Read(path))
    defer { MP4Close(handle, 0) }

    var list: UnsafeMutablePointer<MP4Chapter_t>?
    var count: UInt32 = 0
    let type = MP4GetChapters(handle, &list, &count, MP4ChapterTypeAny)
    guard type != MP4ChapterTypeNone, let list else { return [] }
    defer { MP4Free(list) }

    return (0..<Int(count)).map { i in
        var chap = list[i]
        let title = withUnsafeBytes(of: &chap.title) { buf in
            String(cString: buf.bindMemory(to: CChar.self).baseAddress!)
        }
        return ChapterInfo(title: title, durationMs: UInt64(chap.duration))
    }
}

// MARK: - Tests

struct MetaEditorTests {
    @Test func emptyChapterListIsNoOpEvenForMissingFile() {
        let editor = MetaEditor()
        #expect(editor.addChapters([], toFile: "/nonexistent/file.m4b") == 0)
    }

    @Test func listWithoutChapterObjectsIsNoOp() throws {
        try withAudioFile { path in
            let editor = MetaEditor()
            #expect(editor.addChapters(["not a chapter", 42], toFile: path) == 0)
            let read = try readChapters(path)
            #expect(read.isEmpty)
        }
    }

    @Test func missingFileFails() {
        let editor = MetaEditor()
        let result = editor.addChapters([makeChapter("One", filesDurationsMs: [1000])],
                                        toFile: "/nonexistent/file.m4b")
        #expect(result == -1)
    }

    @Test func nonMP4FileFails() throws {
        let path = NSTemporaryDirectory() + "abb-test-\(UUID().uuidString).m4b"
        try Data("this is not an mp4 file".utf8).write(to: URL(fileURLWithPath: path))
        defer { try? FileManager.default.removeItem(atPath: path) }

        let editor = MetaEditor()
        #expect(editor.addChapters([makeChapter("One", filesDurationsMs: [1000])], toFile: path) == -1)
    }

    @Test func writesChapterTitlesAndDurations() throws {
        try withAudioFile { path in
            let chapters = [
                makeChapter("Chapter One", filesDurationsMs: [300, 200]),
                makeChapter("Chapter Two", filesDurationsMs: [250]),
                makeChapter("Chapter Three", filesDurationsMs: [250]),
            ]
            let editor = MetaEditor()
            #expect(editor.addChapters(chapters, toFile: path) == 0)

            let read = try readChapters(path)
            #expect(read.map(\.title) == ["Chapter One", "Chapter Two", "Chapter Three"])
            #expect(read.map(\.durationMs) == [500, 250, 250])
        }
    }

    @Test func singleChapter() throws {
        try withAudioFile { path in
            let editor = MetaEditor()
            #expect(editor.addChapters([makeChapter("Only", filesDurationsMs: [1000])], toFile: path) == 0)
            let read = try readChapters(path)
            #expect(read.map(\.title) == ["Only"])
        }
    }

    @Test func nonChapterElementsAreSkipped() throws {
        try withAudioFile { path in
            let editor = MetaEditor()
            let items: [Any] = ["junk", makeChapter("Real", filesDurationsMs: [1000]), 7]
            #expect(editor.addChapters(items, toFile: path) == 0)
            let read = try readChapters(path)
            #expect(read.map(\.title) == ["Real"])
        }
    }

    @Test func unicodeTitlesRoundTrip() throws {
        try withAudioFile { path in
            let editor = MetaEditor()
            let chapter = makeChapter("Частина перша", filesDurationsMs: [1000])
            #expect(editor.addChapters([chapter], toFile: path) == 0)
            let read = try readChapters(path)
            #expect(read.map(\.title) == ["Частина перша"])
        }
    }

    @Test func overlongTitleIsTruncatedAndTerminated() throws {
        try withAudioFile { path in
            let editor = MetaEditor()
            let chapter = makeChapter(String(repeating: "x", count: 5000), filesDurationsMs: [1000])
            #expect(editor.addChapters([chapter], toFile: path) == 0)

            let title = try #require(try readChapters(path).first).title
            #expect(!title.isEmpty)
            #expect(title.utf8.count <= 1023)
            #expect(title.allSatisfy { $0 == "x" })
        }
    }
}
