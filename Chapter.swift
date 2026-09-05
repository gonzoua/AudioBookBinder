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

@objc class Chapter: NSObject, @unchecked Sendable {
    @objc var name: String = ""
    @objc var files: NSMutableArray = NSMutableArray()

    @objc override func copy() -> Any {
        let c = Chapter()
        c.name = name
        c.addFiles(files as! [AudioFile])
        return c
    }

    func addFile(_ file: AudioFile) {
        files.add(file)
    }

    func addFiles(_ newFiles: [AudioFile]) {
        files.addObjects(from: newFiles)
    }

    func containsFile(_ file: AudioFile) -> Bool {
        files.contains(file)
    }

    func indexOfFile(_ file: AudioFile) -> Int {
        files.index(of: file)
    }

    func fileAtIndex(_ index: Int) -> AudioFile {
        files[index] as! AudioFile
    }

    func removeFile(_ file: AudioFile) {
        files.remove(file)
    }

    func insertFile(_ file: AudioFile, atIndex index: Int) {
        files.insert(file, at: index)
    }

    func totalFiles() -> Int {
        files.count
    }

    func totalDuration() -> UInt32 {
        var duration: UInt32 = 0
        for file in files {
            duration += UInt32((file as! AudioFile).duration.intValue)
        }
        return duration
    }

    // Splits chapter at given file: files before it stay here, files from it onward go to new chapter.
    func split(atFile file: AudioFile) -> Chapter? {
        let idx = files.index(of: file)
        guard idx != NSNotFound else { return nil }
        let c = Chapter()
        c.name = name
        while idx < files.count {
            let f = files[idx] as! AudioFile
            c.addFile(f)
            files.removeObject(at: idx)
        }
        return c
    }

    func sortUsingDescriptor(_ descriptor: NSSortDescriptor) {
        files.sort(using: [descriptor])
    }
}
