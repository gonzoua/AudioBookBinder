//
//  Copyright (c) 2009-2016 Oleksandr Tymoshenko <gonzo@bluezbox.com>
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

class ConsoleDelegate: NSObject, AudioBinderDelegate {
    var verbose = false
    var quiet = false
    var skipErrors = false
    private let istty: Bool

    override init() {
        istty = isatty(fileno(stdout)) != 0
        super.init()
    }

    func updateStatus(_ file: AudioFile, handled handledFrames: UInt64, total totalFrames: UInt64) {
        guard !quiet && istty else { return }
        let percent = handledFrames * 100 / totalFrames
        print("\r\(file.filePath): [\(String(format: "%3llu", percent))%] \(handledFrames)/\(totalFrames)", terminator: "")
        fflush(stdout)
    }

    func conversionStart(_ file: AudioFile, format asbd: UnsafeMutablePointer<AudioStreamBasicDescription>?, formatDescription description: String?, length frames: UInt64) {
        guard !quiet else { return }
        if verbose, let ptr = asbd {
            let desc = ptr.pointee
            var formatID = desc.mFormatID
            let formatStr = withUnsafeBytes(of: &formatID) { bytes in
                String(bytes: bytes, encoding: .macOSRoman) ?? ""
            }
            print("Stream info for \(file.filePath):")
            print("\tFormatID: \(formatStr), FormatFlags: \(String(format: "%08x", desc.mFormatFlags))")
            print("\tBytesPerPacket: \(desc.mBytesPerPacket), FramesPerPacket: \(desc.mFramesPerPacket), BytesPerFrame: \(desc.mBytesPerFrame)")
            print("\tChannelsPerFrame: \(desc.mChannelsPerFrame), BitsPerChannel: \(desc.mBitsPerChannel)")
            print("\tFormat description: \(description ?? "")")
            print("\tTotal frames: \(frames)")
        }
        print("\(file.filePath): ", terminator: "")
        fflush(stdout)
    }

    func continueFailedConversion(_ file: AudioFile, reason: String?) -> Bool {
        if !quiet {
            print("failed, \(reason ?? "unknown error")", terminator: "")
            if skipErrors {
                print(", skipping...", terminator: "")
            }
            print()
        }
        file.duration = NSNumber(value: 0)
        file.valid = false
        return skipErrors
    }

    func conversionFinished(_ file: AudioFile, duration: UInt32) {
        if !quiet {
            if istty {
                print("\r\(file.filePath): [100%]                              ")
            } else {
                print("done")
            }
        }
        file.duration = NSNumber(value: duration)
        file.valid = true
    }

    func volumeReady(_ volumeName: String, duration seconds: UInt32) {
        guard !quiet else { return }
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        var msg = "Finished: \(volumeName) ("
        if h > 0 { msg += "\(h)h " }
        msg += "\(m)m \(s)s)"
        print(msg)
    }

    func audiobookReady(_ seconds: UInt32) {
        guard !quiet else { return }
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        var msg = "Total: "
        if h > 0 { msg += "\(h)h " }
        msg += "\(m)m \(s)s"
        print(msg)
    }

    func volumeFailed(_ filename: String, reason: String?) {
    }
}
