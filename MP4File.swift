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

    private static let bufferSize = 16 * 1024 * 1024

    // iTunes metadata well-known type classes
    private static let typeImplicit: UInt32 = 0x00
    private static let typeString:   UInt32 = 0x01
    private static let typeImage:    UInt32 = 0x0e
    private static let typeUInt8:    UInt32 = 0x15

    private let fh: FileHandle

    @objc init?(fileName: String) {
        guard let handle = FileHandle(forUpdatingAtPath: fileName) else { return nil }
        self.fh = handle

        // Scan top-level atoms to validate file structure
        var pos: UInt64 = 0
        let end = fh.seekToEndOfFile()
        fh.seek(toFileOffset: 0)
        while pos < end {
            let buf = fh.readData(ofLength: 8)
            guard buf.count == 8, let atom = MP4Atom(headerData: buf, offset: pos) else { break }
            pos += UInt64(atom.length)
            fh.seek(toFileOffset: pos)
        }
    }

    @objc func update() -> Void {
        let hdlrData = encodeHDLRAtom()

        guard var moovAtom = findAtom("moov") else {
            fatalError("File contains no moov atom")
        }
        guard var freeAtom = findAtom("free") else {
            fatalError("File contains no free atom")
        }
        let udtaAtom = findAtom("moov.udta")
        let metaAtom = findAtom("moov.udta.meta")
        let ilstAtom = findAtom("moov.udta.meta.ilst")

        let hadUdta = udtaAtom != nil
        let hadMeta = metaAtom != nil
        let hadIlst = ilstAtom != nil

        // Build the new iTunes metadata items
        var newItems = Data()
        if let v = title {
            newItems.append(encodeMetaDataAtom("©nam", value: Data(v.utf8), type: Self.typeString))
        }
        if let v = album {
            newItems.append(encodeMetaDataAtom("©alb", value: Data(v.utf8), type: Self.typeString))
        }
        if let v = artist {
            newItems.append(encodeMetaDataAtom("©ART", value: Data(v.utf8), type: Self.typeString))
        }
        if let v = narrator {
            newItems.append(encodeMetaDataAtom("©nrt", value: Data(v.utf8), type: Self.typeString))
            newItems.append(encodeMetaDataAtom("©wrt", value: Data(v.utf8), type: Self.typeString))
        }
        if track > 0 && tracksTotal > 1 {
            // trkn payload: [0, track, tracksTotal, 0] as big-endian UInt16s (8 bytes)
            let words: [UInt16] = [0, track.bigEndian, tracksTotal.bigEndian, 0]
            let data = words.withUnsafeBufferPointer { Data(buffer: $0) }
            newItems.append(encodeMetaDataAtom("trkn", value: data, type: Self.typeImplicit))
        }
        if gaplessPlay {
            newItems.append(encodeMetaDataAtom("pgap", value: Data([1]), type: Self.typeUInt8))
        }
        if let v = genre {
            newItems.append(encodeMetaDataAtom("©gen", value: Data(v.utf8), type: Self.typeString))
        }
        if let path = coverFile, let imageData = try? Data(contentsOf: URL(fileURLWithPath: path)) {
            newItems.append(encodeMetaDataAtom("covr", value: imageData, type: Self.typeImage))
        }

        // Accumulate how many bytes will be inserted in total. Each missing wrapper
        // atom adds its own 8-byte header (plus the hdlr block for meta).
        var additionalLength = UInt32(newItems.count)

        let finalIlst: MP4Atom
        if var atom = ilstAtom {
            atom.length += additionalLength
            fixupAtom(atom)
            finalIlst = atom
        } else {
            additionalLength += 8  // ilst header
            finalIlst = MP4Atom(name: "ilst", length: additionalLength)
        }

        let finalMeta: MP4Atom
        if var atom = metaAtom {
            atom.length += additionalLength
            fixupAtom(atom)
            finalMeta = atom
        } else {
            // meta header (8) + version/flags (4) + hdlr atom
            additionalLength += UInt32(hdlrData.count) + 12
            finalMeta = MP4Atom(name: "meta", length: additionalLength)
        }

        let finalUdta: MP4Atom
        if var atom = udtaAtom {
            atom.length += additionalLength
            fixupAtom(atom)
            finalUdta = atom
        } else {
            additionalLength += 8  // udta header
            finalUdta = MP4Atom(name: "udta", length: additionalLength)
        }

        // Build the bytes to write after the moov atom
        var atomData = Data()
        if !hadUdta { atomData.append(finalUdta.encode()) }
        if !hadMeta {
            atomData.append(finalMeta.encode())
            var flags: UInt32 = 0
            withUnsafeBytes(of: &flags) { atomData.append(contentsOf: $0) }
            atomData.append(hdlrData)
        }
        if !hadIlst { atomData.append(finalIlst.encode()) }
        atomData.append(newItems)

        let insertOffset = moovAtom.offset + UInt64(moovAtom.length)

        if freeAtom.length >= additionalLength {
            // Shrink the existing free atom to absorb the new bytes
            freeAtom.length -= additionalLength
            freeAtom.offset += UInt64(additionalLength)
            fixupAtom(freeAtom)
        } else {
            // Not enough free space: insert room by shifting the rest of the file
            guard let mdatAtom = findAtom("mdat") else {
                fatalError("Failed to find mdat atom")
            }
            reserveSpace(UInt64(additionalLength), at: insertOffset)
            if mdatAtom.offset > moovAtom.offset {
                fixSTCOAtom(by: UInt64(additionalLength))
            }
        }

        fh.seek(toFileOffset: insertOffset)
        fh.write(atomData)

        moovAtom.length += additionalLength
        fixupAtom(moovAtom)
    }

    // MARK: - Private helpers

    private func fixupAtom(_ atom: MP4Atom) {
        fh.seek(toFileOffset: atom.offset)
        fh.write(atom.encode())
    }

    private func findAtom(_ path: String) -> MP4Atom? {
        var components = path.components(separatedBy: ".")
        var pos: UInt64 = 0
        var end = fh.seekToEndOfFile()
        fh.seek(toFileOffset: 0)

        while pos < end {
            let buf = fh.readData(ofLength: 8)
            guard buf.count == 8, let atom = MP4Atom(headerData: buf, offset: pos) else { break }

            if atom.name == components[0] {
                end = pos + UInt64(atom.length)
                // meta carries a 4-byte version/flags field before its children
                pos += atom.name == "meta" ? 12 : 8
                components.removeFirst()
                if components.isEmpty { return atom }
            } else {
                pos += UInt64(atom.length)
            }
            fh.seek(toFileOffset: pos)
        }
        return nil
    }

    private func encodeMetaDataAtom(_ name: String, value: Data, type: UInt32) -> Data {
        // Layout: [outer atom header (8)] [data atom header (8)] [type (4)] [zero (4)] [value]
        let dataAtomSize = UInt32(value.count) + 16
        let outerSize    = dataAtomSize + 8
        var result = MP4Atom(name: name, length: outerSize).encode()
        result.append(MP4Atom(name: "data", length: dataAtomSize).encode())
        var beType = type.bigEndian
        withUnsafeBytes(of: &beType) { result.append(contentsOf: $0) }
        var zero: UInt32 = 0
        withUnsafeBytes(of: &zero) { result.append(contentsOf: $0) }
        result.append(value)
        return result
    }

    // Without this atom iTunes refuses to accept file metadata
    private func encodeHDLRAtom() -> Data {
        // Total: 8 (header) + 4+4+4+4+4+4+2 = 34 bytes
        var result = MP4Atom(name: "hdlr", length: 34).encode()
        var zero32: UInt32 = 0
        var zero16: UInt16 = 0
        withUnsafeBytes(of: &zero32) { result.append(contentsOf: $0) }
        withUnsafeBytes(of: &zero32) { result.append(contentsOf: $0) }
        result.append(contentsOf: "mdir".utf8)
        result.append(contentsOf: "appl".utf8)
        withUnsafeBytes(of: &zero32) { result.append(contentsOf: $0) }
        withUnsafeBytes(of: &zero32) { result.append(contentsOf: $0) }
        withUnsafeBytes(of: &zero16) { result.append(contentsOf: $0) }
        return result
    }

    // Inserts `size` zero bytes at `offset` by shifting everything after it toward the end.
    private func reserveSpace(_ size: UInt64, at offset: UInt64) {
        var end = fh.seekToEndOfFile()
        while end > offset {
            let chunkSize = min(end - offset, UInt64(Self.bufferSize))
            fh.seek(toFileOffset: end - chunkSize)
            let buffer = fh.readData(ofLength: Int(chunkSize))
            guard !buffer.isEmpty else { break }
            fh.seek(toFileOffset: end - UInt64(buffer.count) + size)
            fh.write(buffer)
            end -= UInt64(buffer.count)
        }
    }

    // stco holds a table of absolute file offsets into mdat. After inserting bytes
    // before mdat we must add `shift` to every entry.
    // Atom layout: [size(4)] [tag(4)] [version/flags(4)] [nentries(4)] [entry...](4 each)
    private func fixSTCOAtom(by shift: UInt64) {
        guard let stco = findAtom("moov.trak.mdia.minf.stbl.stco") else {
            fatalError("Failed to find moov.trak.mdia.minf.stbl.stco atom")
        }
        fh.seek(toFileOffset: stco.offset + 12)  // skip size, tag, version/flags
        var table = fh.readData(ofLength: Int(stco.length) - 12)

        let entryCount = UInt32(bigEndian: table.withUnsafeBytes { $0.load(as: UInt32.self) })
        for i in 0..<Int(entryCount) {
            let byteOffset = 4 + i * 4
            let entry = UInt32(bigEndian: table.withUnsafeBytes {
                $0.load(fromByteOffset: byteOffset, as: UInt32.self)
            })
            var updated = (entry + UInt32(shift)).bigEndian
            let replacement = Swift.withUnsafeBytes(of: &updated) { Data($0) }
            table.replaceSubrange(byteOffset..<(byteOffset + 4), with: replacement)
        }

        fh.seek(toFileOffset: stco.offset + 12)
        fh.write(table)
    }
}
