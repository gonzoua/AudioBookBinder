import AudioToolbox
import Foundation
import Testing

/// Creates a real one-second mono AAC .m4a using the same CoreAudio path the app uses.
func makeAudioFile(at path: String, seconds: Int = 1) throws {
    let sampleRate = 44100.0
    var outputFormat = AudioStreamBasicDescription()
    outputFormat.mSampleRate = sampleRate
    outputFormat.mFormatID = kAudioFormatMPEG4AAC
    outputFormat.mChannelsPerFrame = 1

    var file: ExtAudioFileRef?
    var status = ExtAudioFileCreateWithURL(URL(fileURLWithPath: path) as CFURL, kAudioFileMPEG4Type,
                                           &outputFormat, nil, AudioFileFlags.eraseFile.rawValue, &file)
    try #require(status == noErr)
    let outFile = try #require(file)
    defer { ExtAudioFileDispose(outFile) }

    var pcm = AudioStreamBasicDescription(
        mSampleRate: sampleRate, mFormatID: kAudioFormatLinearPCM,
        mFormatFlags: kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked,
        mBytesPerPacket: 2, mFramesPerPacket: 1, mBytesPerFrame: 2,
        mChannelsPerFrame: 1, mBitsPerChannel: 16, mReserved: 0)
    status = ExtAudioFileSetProperty(outFile, kExtAudioFileProperty_ClientDataFormat,
                                     UInt32(MemoryLayout.size(ofValue: pcm)), &pcm)
    try #require(status == noErr)

    let frames = UInt32(sampleRate) * UInt32(seconds)
    var samples = [Int16](repeating: 0, count: Int(frames))
    try samples.withUnsafeMutableBytes { raw in
        var list = AudioBufferList(
            mNumberBuffers: 1,
            mBuffers: AudioBuffer(mNumberChannels: 1, mDataByteSize: frames * 2, mData: raw.baseAddress))
        try #require(ExtAudioFileWrite(outFile, frames, &list) == noErr)
    }
}

func withAudioFile<T>(_ body: (String) throws -> T) throws -> T {
    let path = NSTemporaryDirectory() + "abb-test-\(UUID().uuidString).m4b"
    try makeAudioFile(at: path)
    defer { try? FileManager.default.removeItem(atPath: path) }
    return try body(path)
}
