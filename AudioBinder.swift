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
import AudioToolbox


private func makePCMFormat(_ channels: UInt32, _ sampleRate: Float) -> AudioStreamBasicDescription {
    var fmt = AudioStreamBasicDescription()
    fmt.mSampleRate = Float64(sampleRate)
    fmt.mFormatID = kAudioFormatLinearPCM
    fmt.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsBigEndian | kAudioFormatFlagIsPacked
    fmt.mBitsPerChannel = 16
    fmt.mChannelsPerFrame = channels
    fmt.mFramesPerPacket = 1
    fmt.mBytesPerPacket = (fmt.mBitsPerChannel / 8) * fmt.mChannelsPerFrame
    fmt.mBytesPerFrame = fmt.mBytesPerPacket * fmt.mFramesPerPacket
    return fmt
}

func getValidBitrate(_ channels: UInt32, _ sampleRate: Float) -> [UInt32] {
    var result: [UInt32] = [UInt32]()

    let tmpPath = (NSTemporaryDirectory() as NSString)
        .appendingPathComponent(ProcessInfo.processInfo.globallyUniqueString)
    let url = URL(fileURLWithPath: tmpPath) as CFURL

    var outputFormat = AudioStreamBasicDescription()
    outputFormat.mSampleRate = Float64(sampleRate)
    outputFormat.mFormatID = kAudioFormatMPEG4AAC
    outputFormat.mChannelsPerFrame = channels

    var tmpFile: ExtAudioFileRef?
    guard ExtAudioFileCreateWithURL(url, kAudioFileMPEG4Type, &outputFormat,
                                    nil, AudioFileFlags.eraseFile.rawValue, &tmpFile) == noErr,
          let tmpFile else { return result }
    defer {
        ExtAudioFileDispose(tmpFile)
        try? FileManager.default.removeItem(atPath: tmpPath)
    }

    var pcmFormat = makePCMFormat(channels, sampleRate)
    guard ExtAudioFileSetProperty(tmpFile,
                                  kExtAudioFileProperty_ClientDataFormat,
                                  UInt32(MemoryLayout<AudioStreamBasicDescription>.size),
                                  &pcmFormat) == noErr else { return result }

    var conv: AudioConverterRef?
    var convSize = UInt32(MemoryLayout<AudioConverterRef>.size)
    guard ExtAudioFileGetProperty(tmpFile, kExtAudioFileProperty_AudioConverter,
                                  &convSize, &conv) == noErr, let conv else { return result }

    var bitrateListSize: UInt32 = 0
    guard AudioConverterGetPropertyInfo(conv, kAudioConverterApplicableEncodeBitRates,
                                        &bitrateListSize, nil) == noErr,
          bitrateListSize > 0 else { return result }

    let count = Int(bitrateListSize) / MemoryLayout<AudioValueRange>.size
    var ranges = [AudioValueRange](repeating: AudioValueRange(), count: count)
    guard AudioConverterGetProperty(conv, kAudioConverterApplicableEncodeBitRates,
                                    &bitrateListSize, &ranges) == noErr else { return result }

    for range in ranges {
        let minRate = UInt32(range.mMinimum)
        if minRate != 0 {
            result.append(minRate)
        }
    }

    return result
}

private let audioBufferSize = 1 * 1024 * 1024

private func stringForOSStatus(_ err: OSStatus) -> String {
    var isOSType = true
    var chars = [UInt8](repeating: 0, count: 4)
    for i in 0..<4 {
        let c = UInt8((err >> (8 * i)) & 0xff)
        if isprint(Int32(c)) != 0 {
            chars[3 - i] = c
        } else {
            isOSType = false
            break
        }
    }

    let knownErrors: [OSStatus: String] = [
        0x7479703f: "Unsupported file type",
        0x666d743f: "Unsupported data format",
        0x7074793f: "Unsupported property",
        0x2173697a: "Bad property size",
        0x70726d3f: "Permission denied",
        0x6f70746d: "Not optimized",
        0x63686b3f: "Invalid chunk",
        0x6f66663f: "Does not allow 64bit data size",
        0x70636b3f: "Invalid packet offset",
        0x6474613f: "Invalid file",
    ]

    if isOSType {
        let osTypeStr = String(bytes: chars, encoding: .macOSRoman) ?? ""
        let desc = knownErrors[err] ?? osTypeStr
        return String(format: "err#%08lx (%@)", Int(err), desc)
    } else {
        let error = NSError(domain: NSOSStatusErrorDomain, code: Int(err))
        let desc = error.description
        return desc.isEmpty
            ? String(format: "err#%08lx ", Int(err))
            : String(format: "err#%08lx (%@)", Int(err), desc)
    }
}

@MainActor
@objc protocol AudioBinderDelegate: AnyObject {
    func updateStatus(_ file: AudioFile, handled handledFrames: UInt64, total totalFrames: UInt64)
    func conversionStart(_ file: AudioFile,
                         format: UnsafeMutablePointer<AudioStreamBasicDescription>?,
                         formatDescription description: String?,
                         length frames: UInt64)
    func continueFailedConversion(_ file: AudioFile, reason: String?) -> Bool
    func conversionFinished(_ file: AudioFile, duration: UInt32)
    func audiobookReady(_ seconds: UInt32)
    nonisolated func volumeFailed(_ filename: String, reason: String?)
    func volumeReady(_ volumeName: String, duration seconds: UInt32)
}

/// Carries the (main-actor-only) delegate and file objects across the actor boundary
private struct DelegateBox: @unchecked Sendable {
    let delegate: any AudioBinderDelegate
    let file: AudioFile?
}

@objc actor AudioBinder: NSObject {
    private var channels: UInt32 = 2
    private var sampleRate: Float = 44100
    private var bitrate: UInt32 = 0

    private(set) var volumes: [AudioBookVolume] = [AudioBookVolume]()

    private var outAudioFile: ExtAudioFileRef?
    private var outFileLength: Int64 = 0
    private var outBookLength: Int64 = 0
    private weak var delegate: (any AudioBinderDelegate)?
    private var canceled = false
    private var bitrateSet = false

    override init() {
        super.init()
    }

    func reset() {
        volumes.removeAll()
        channels = 2
        sampleRate = 44100
        bitrate = 0
        outAudioFile = nil
        outFileLength = 0
        outBookLength = 0
        canceled = false
        bitrateSet = false
    }

    func configure(channels: UInt32, sampleRate: Float, bitrate: UInt32) {
        self.channels = channels
        self.sampleRate = sampleRate
        self.bitrate = bitrate
    }

    func cancel() async {
        canceled = true
    }

    func setDelegate(_ delegate: (any AudioBinderDelegate)?) {
        self.delegate = delegate
    }

    func addVolume(_ filename: String, files: [String]) {
        let volume = AudioBookVolume(filename: filename, inputFiles: files)
        volumes.append(volume)
    }

    func volumeFiles() -> [String] {
        return volumes.map { $0.filename }
    }

    /// Runs `body` on the main actor with the delegate, if one is set
    private func onMain(_ file: AudioFile? = nil,
                        _ body: @escaping @MainActor @Sendable (any AudioBinderDelegate, AudioFile?) -> Void) async {
        guard let delegate else { return }
        let box = DelegateBox(delegate: delegate, file: file)
        await MainActor.run { body(box.delegate, box.file) }
    }

    private func notifyVolumeFailed(_ volume: String, reason: String) {
        delegate?.volumeFailed(volume, reason: reason)
    }

    func convert() async -> Bool  {
        var failed = false
        var filesConverted = 0

        for v in volumes {
            guard v.inputFiles.count > 0 else {
                self.notifyVolumeFailed(v.filename, reason: "No input files")
                return false
            }

            guard openOutFile(v.filename) else {
                self.notifyVolumeFailed(v.filename, reason: "Can't create output file")
                return false
            }

            for filePath in v.inputFiles {
                do {
                    try await convertOneFile(filePath)
                    filesConverted += 1
                } catch {
                    guard let delegate, let file = AudioFile(path: filePath) else {
                        failed = true
                        break
                    }
                    let reason = error.localizedDescription
                    let box = DelegateBox(delegate: delegate, file: file)
                    let decision = await MainActor.run {
                        box.delegate.continueFailedConversion(box.file!, reason: reason)
                    }
                    if !decision {
                        failed = true
                        break
                    }
                }
                if canceled { break }
            }

            outBookLength += outFileLength
            closeOutFile()

            if failed || canceled { break }
            let name = v.filename
            let volumeSeconds = UInt32(Double(outFileLength) / Double(sampleRate))
            await onMain { delegate, _ in
                delegate.volumeReady(name, duration: volumeSeconds)
            }
        }

        if failed || canceled {
            let fm = FileManager.default
            for v in volumes {
                try? fm.removeItem(atPath: v.filename)
            }
        }

        let succeeded = !failed && filesConverted > 0 && !canceled
        if succeeded {
            let bookSeconds = UInt32(Double(outBookLength) / Double(sampleRate))
            await onMain { delegate, _ in
                delegate.audiobookReady(bookSeconds)
            }
        }
        canceled = false
        return succeeded
    }

    func validBitrates() -> [NSNumber]? {
        let tmpPath = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent(ProcessInfo.processInfo.globallyUniqueString)
        let url = URL(fileURLWithPath: tmpPath) as CFURL

        var outputFormat = AudioStreamBasicDescription()
        outputFormat.mSampleRate = Float64(sampleRate)
        outputFormat.mFormatID = kAudioFormatMPEG4AAC
        outputFormat.mChannelsPerFrame = channels

        var tmpFile: ExtAudioFileRef?
        guard ExtAudioFileCreateWithURL(url, kAudioFileMPEG4Type, &outputFormat,
                                        nil, AudioFileFlags.eraseFile.rawValue, &tmpFile) == noErr,
              let tmpFile else { return [] }
        defer {
            ExtAudioFileDispose(tmpFile)
            try? FileManager.default.removeItem(atPath: tmpPath)
        }

        var pcmFormat = makePCMFormat(self.channels, self.sampleRate)
        guard ExtAudioFileSetProperty(tmpFile,
                                      kExtAudioFileProperty_ClientDataFormat,
                                      UInt32(MemoryLayout<AudioStreamBasicDescription>.size),
                                      &pcmFormat) == noErr else { return [] }

        var conv: AudioConverterRef?
        var convSize = UInt32(MemoryLayout<AudioConverterRef>.size)
        guard ExtAudioFileGetProperty(tmpFile, kExtAudioFileProperty_AudioConverter,
                                      &convSize, &conv) == noErr, let conv else { return [] }

        var bitrateListSize: UInt32 = 0
        guard AudioConverterGetPropertyInfo(conv, kAudioConverterApplicableEncodeBitRates,
                                            &bitrateListSize, nil) == noErr,
              bitrateListSize > 0 else { return [] }

        let count = Int(bitrateListSize) / MemoryLayout<AudioValueRange>.size
        var ranges = [AudioValueRange](repeating: AudioValueRange(), count: count)
        guard AudioConverterGetProperty(conv, kAudioConverterApplicableEncodeBitRates,
                                        &bitrateListSize, &ranges) == noErr else { return [] }

        return ranges.compactMap { range in
            let minRate = UInt(range.mMinimum)
            return minRate != 0 ? NSNumber(value: minRate) : nil
        }
    }

    // MARK: - Private helpers


    private func openOutFile(_ path: String) -> Bool {
        let fm = FileManager.default
        if fm.fileExists(atPath: path) {
            guard (try? fm.removeItem(atPath: path)) != nil else { return false }
        }

        let url = URL(fileURLWithPath: path) as CFURL
        var outputFormat = AudioStreamBasicDescription()
        outputFormat.mSampleRate = Float64(sampleRate)
        outputFormat.mFormatID = kAudioFormatMPEG4AAC
        outputFormat.mChannelsPerFrame = channels

        var file: ExtAudioFileRef?
        let status = ExtAudioFileCreateWithURL(url, kAudioFileMPEG4Type, &outputFormat,
                                               nil, AudioFileFlags.eraseFile.rawValue, &file)
        guard status == noErr, let file else { return false }
        outAudioFile = file
        outFileLength = 0
        return true
    }

    private func closeOutFile() {
        if let f = outAudioFile { ExtAudioFileDispose(f) }
        outAudioFile = nil
    }

    private func setConverterBitrate() -> Bool {
        guard let outAudioFile else { return false }
        var conv: AudioConverterRef?
        var size = UInt32(MemoryLayout<AudioConverterRef>.size)
        guard ExtAudioFileGetProperty(outAudioFile, kExtAudioFileProperty_AudioConverter,
                                      &size, &conv) == noErr, let conv else { return false }
        var br = bitrate
        return AudioConverterSetProperty(conv, kAudioConverterEncodeBitRate,
                                         UInt32(MemoryLayout<UInt32>.size), &br) == noErr
    }

    private func convertOneFile(_ inFilePath: String) async throws {
        struct ConvertError: Error {
            let message: String
            var localizedDescription: String { message }
        }

        let url = URL(fileURLWithPath: inFilePath) as CFURL
        var inAudioFile: ExtAudioFileRef?
        var status = ExtAudioFileOpenURL(url, &inAudioFile)
        guard status == noErr, let inAudioFile else {
            throw ConvertError(message: "ExtAudioFileOpenURL failed: \(stringForOSStatus(status))")
        }
        defer { ExtAudioFileDispose(inAudioFile) }

        var format = AudioStreamBasicDescription()
        var propSize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        status = ExtAudioFileGetProperty(inAudioFile, kExtAudioFileProperty_FileDataFormat,
                                         &propSize, &format)
        guard status == noErr else {
            throw ConvertError(message: "AudioFileGetProperty failed: \(stringForOSStatus(status))")
        }

        // Get human-readable format name for delegate
        let formatNamePtr = UnsafeMutablePointer<Unmanaged<CFString>?>.allocate(capacity: 1)
        formatNamePtr.initialize(to: nil)
        defer { formatNamePtr.deallocate() }
        var specSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        status = AudioFormatGetProperty(kAudioFormatProperty_FormatName,
                                        UInt32(MemoryLayout<AudioStreamBasicDescription>.size),
                                        &format, &specSize, formatNamePtr)
        guard status == noErr else {
            throw ConvertError(message: "AudioFormatGetProperty failed: \(stringForOSStatus(status))")
        }

        var framesTotal: Int64 = 0
        propSize = UInt32(MemoryLayout<Int64>.size)
        status = ExtAudioFileGetProperty(inAudioFile, kExtAudioFileProperty_FileLengthFrames,
                                         &propSize, &framesTotal)
        guard status == noErr else {
            throw ConvertError(message: "can't get input file length: \(stringForOSStatus(status))")
        }

        // AudioFile is only touched from the main actor once handed to the delegate
        let inFile = AudioFile(path: inFilePath)
        let formatName = formatNamePtr.pointee?.takeRetainedValue() as String?
        if inFile != nil {
            let startFormat = format
            let frames = UInt64(framesTotal)
            await onMain(inFile) { delegate, file in
                var fmt = startFormat
                delegate.conversionStart(file!, format: &fmt, formatDescription: formatName, length: frames)
            }
        }

        // Rescale framesTotal to output sample rate for accurate progress reporting
        framesTotal = Int64(Double(framesTotal) * Double(sampleRate) / format.mSampleRate)

        var pcmFormat = makePCMFormat(self.channels, self.sampleRate)
        status = ExtAudioFileSetProperty(inAudioFile, kExtAudioFileProperty_ClientDataFormat,
                                         UInt32(MemoryLayout<AudioStreamBasicDescription>.size), &pcmFormat)
        guard status == noErr else {
            throw ConvertError(message: "ExtAudioFileSetProperty(ClientDataFormat) failed: \(stringForOSStatus(status))")
        }

        var conv: AudioConverterRef?
        var convSize = UInt32(MemoryLayout<AudioConverterRef>.size)
        status = ExtAudioFileGetProperty(inAudioFile, kExtAudioFileProperty_AudioConverter,
                                         &convSize, &conv)
        guard status == noErr else {
            throw ConvertError(message: "can't get AudioConverter: \(stringForOSStatus(status))")
        }

        // Duplicate mono channel to stereo when needed
        if format.mChannelsPerFrame == 1 && channels == 2 {
            guard let conv else {
                throw ConvertError(message: "Can't get AudioConverter ref")
            }
            var channelMap: [Int32] = [0, 0]
            status = AudioConverterSetProperty(conv, kAudioConverterChannelMap,
                                               UInt32(channelMap.count * MemoryLayout<Int32>.size),
                                               &channelMap)
            guard status == noErr else {
                throw ConvertError(message: "Can't set ChannelMap: \(stringForOSStatus(status))")
            }
        }

        guard let outAudioFile else {
            throw ConvertError(message: "Output file not open")
        }
        status = ExtAudioFileSetProperty(outAudioFile, kExtAudioFileProperty_ClientDataFormat,
                                         UInt32(MemoryLayout<AudioStreamBasicDescription>.size), &pcmFormat)
        guard status == noErr else {
            throw ConvertError(message: "can't set ClientDataFormat: \(stringForOSStatus(status))")
        }

        if bitrate > 0 && !bitrateSet {
            guard setConverterBitrate() else {
                throw ConvertError(message: "can't set output bit rate")
            }
            bitrateSet = true
        }

        let audioBuffer = UnsafeMutableRawPointer.allocate(byteCount: audioBufferSize, alignment: 1)
        defer { audioBuffer.deallocate() }

        var bufferList = AudioBufferList()
        bufferList.mNumberBuffers = 1
        bufferList.mBuffers.mNumberChannels = pcmFormat.mChannelsPerFrame
        bufferList.mBuffers.mData = audioBuffer
        bufferList.mBuffers.mDataByteSize = UInt32(audioBufferSize)

        var framesConverted: UInt64 = 0
        var framesToRead: UInt32 = 0
        repeat {
            framesToRead = bufferList.mBuffers.mDataByteSize / pcmFormat.mBytesPerFrame
            status = ExtAudioFileRead(inAudioFile, &framesToRead, &bufferList)
            guard status == noErr else {
                throw ConvertError(message: "ExtAudioFileRead failed: \(stringForOSStatus(status))")
            }

            if framesToRead > 0 {
                status = ExtAudioFileWrite(outAudioFile, framesToRead, &bufferList)
                guard status == noErr else {
                    throw ConvertError(message: "ExtAudioFileWrite failed: \(stringForOSStatus(status))")
                }
            }

            framesConverted += UInt64(framesToRead)
            if inFile != nil {
                let handled = framesConverted
                let total = UInt64(framesTotal)
                await onMain(inFile) { delegate, file in
                    delegate.updateStatus(file!, handled: handled, total: total)
                }
            }

            status = ExtAudioFileTell(outAudioFile, &outFileLength)
            guard status == noErr else {
                throw ConvertError(message: "ExtAudioFileTell failed: \(stringForOSStatus(status))")
            }

            if canceled { break }
        } while framesToRead > 0

        if inFile != nil {
            let duration = UInt32(Double(framesConverted) * 1000.0 / Double(sampleRate))
            await onMain(inFile) { delegate, file in
                delegate.conversionFinished(file!, duration: duration)
            }
        }
    }
}
