import Cocoa

private let simplePboardType = NSPasteboard.PasteboardType("MyCustomOutlineViewPboardType")
private let filenamesPboardType = NSPasteboard.PasteboardType("NSFilenamesPboardType")
private let filesPromisePboardType = NSPasteboard.PasteboardType("NSFilesPromisePboardType")

private let columnName = "name"
private let columnFile = "file"
private let columnAuthor = "artist"
private let columnAlbum = "album"
private let columnTime = "duration"

class AudioFileList: NSObject, @unchecked Sendable {

    @objc dynamic var chapterMode: Bool = true
    @objc dynamic var canPlay: Bool = false
    @objc dynamic var commonAuthor: String? = nil
    @objc dynamic var commonAlbum: String? = nil

    @objc dynamic var hasFiles: Bool { !_files.isEmpty }

    private var _files: [AudioFile] = []
    private var _chapters: [Chapter] = []
    private var _draggedNodes: [Any]? = nil
    private var _sortAscending = true
    private var _sortKey: String? = nil

    override init() {
        super.init()
        if let modeObj = UserDefaults.standard.object(forKey: "ChaptersEnabled") as? NSNumber {
            chapterMode = modeObj.boolValue
        }
    }

    func addFile(_ fileName: String) {
        guard let file = AudioFile(path: fileName), file.valid else { return }
        willChangeValue(forKey: "hasFiles")
        _files.append(file)
        if chapterMode {
            let chapter = Chapter()
            chapter.name = !file.name.isEmpty ? file.name : file.file
            chapter.addFile(file)
            _chapters.append(chapter)
        }
        didChangeValue(forKey: "hasFiles")
    }

    func addFilesInDirectory(_ dirName: String) {
        var entries: [String] = []

        if let enumerator = FileManager.default.enumerator(atPath: dirName) {
            for case let filePath as String in enumerator {
                entries.append(filePath)
            }
        }

        let sortFiles = UserDefaults.standard.bool(forKey: "SortAudioFiles")
        let ordered = sortFiles ? entries.sorted() : entries
        for entry in ordered {
            let path = (dirName as NSString).appendingPathComponent(entry)
            addFile(path)
        }
    }

    func files() -> [AudioFile] {
        if chapterMode {
            return _chapters.flatMap { $0.files.compactMap { $0 as? AudioFile } }
        }
        return _files
    }

    func chapters() -> [Chapter] { Array(_chapters) }

    func switchChapterMode() {
        if !chapterMode {
            if !_files.isEmpty {
                let newChapter = Chapter()
                newChapter.name = NSLocalizedString("Chapter", comment: "")
                _chapters.removeAll()
                for file in _files { newChapter.addFile(file) }
                _chapters.append(newChapter)
            }
            chapterMode = true
        } else {
            _files.removeAll()
            for ch in _chapters {
                _files.append(contentsOf: ch.files.compactMap { $0 as? AudioFile })
            }
            chapterMode = false
        }
    }

    func renumberChapters() {
        guard chapterMode else { return }
        for (idx, ch) in _chapters.enumerated() {
            ch.name = String(format: NSLocalizedString("Chapter %d", comment: ""), idx + 1)
        }
    }

    func orphanFile(_ file: AudioFile) {
        for ch in _chapters {
            if ch.containsFile(file) { ch.removeFile(file) }
        }
    }

    func cleanupChapters() {
        var idx = 0
        while idx < _chapters.count {
            let ch = _chapters[idx]
            if ch.totalFiles() == 0 && _chapters.count > 1 {
                _chapters.remove(at: idx)
            } else {
                idx += 1
            }
        }
    }

    @MainActor
    func removeAllFiles(_ outlineView: NSOutlineView) {
        willChangeValue(forKey: "hasFiles")
        _files.removeAll()
        _chapters.removeAll()
        outlineView.deselectAll(self)
        outlineView.reloadData()
        if chapterMode { outlineView.expandItem(nil, expandChildren: true) }
        didChangeValue(forKey: "hasFiles")
    }

    func tryGuessingAuthorAndAlbum() {
        if _files.isEmpty {
            commonAlbum = nil
            commonAuthor = nil
            return
        }
        var author: String? = _files[0].artist
        var album: String? = _files[0].album
        for f in _files {
            if author != f.artist { author = nil; break }
        }
        for f in _files {
            if album != f.album { album = nil; break }
        }
        commonAuthor = author
        commonAlbum = album
    }

    // MARK: - Selection operations

    @MainActor
    func deleteSelected(_ outlineView: NSOutlineView) -> Void {
        willChangeValue(forKey: "hasFiles")
        for item in outlineView.selectedItems {
            if let ch = item as? Chapter {
                for f in ch.files.compactMap({ $0 as? AudioFile }) {
                    _files.removeAll { $0 === f }
                }
                _chapters.removeAll { $0 === ch }
            } else if let file = item as? AudioFile {
                _files.removeAll { $0 === file }
                for ch in _chapters {
                    if ch.containsFile(file) { ch.removeFile(file) }
                }
            }
        }
        cleanupChapters()
        didChangeValue(forKey: "hasFiles")
        outlineView.deselectAll(self)
        outlineView.reloadData()
    }

    @MainActor
    func joinSelectedFiles(_ outlineView: NSOutlineView) -> Void {
        guard chapterMode, !outlineView.selectedItems.isEmpty else { return }

        let newChapter = Chapter()
        let first = outlineView.selectedItems[0]
        var chapterIndex: Int

        if let ch = first as? Chapter {
            chapterIndex = _chapters.firstIndex(where: { $0 === ch }) ?? 0
            newChapter.name = ch.name
        } else if let file = first as? AudioFile {
            newChapter.name = !file.name.isEmpty ? file.name : file.file
            var foundCh: Chapter? = nil
            for ch in _chapters {
                if ch.containsFile(file) { foundCh = ch; break }
            }
            chapterIndex = _chapters.firstIndex(where: { $0 === foundCh }) ?? 0
        } else {
            return
        }

        for item in outlineView.selectedItems {
            if let ch = item as? Chapter {
                for f in ch.files.compactMap({ $0 as? AudioFile })
                    where !newChapter.containsFile(f) { newChapter.addFile(f) }
                _chapters.removeAll { $0 === ch }
            } else if let file = item as? AudioFile {
                if !newChapter.containsFile(file) {
                    orphanFile(file)
                    newChapter.addFile(file)
                }
            }
        }

        _chapters.insert(newChapter, at: chapterIndex)
        cleanupChapters()
        outlineView.deselectAll(self)
        outlineView.reloadData()
        outlineView.setSelectedItem(newChapter)
        outlineView.expandItem(newChapter)
    }

    @MainActor
    func splitSelectedFiles(_ outlineView: NSOutlineView) -> Void {
        guard chapterMode, !outlineView.selectedItems.isEmpty else { return }

        var newChapters: [Chapter] = []
        for item in outlineView.selectedItems {
            guard let ch = item as? Chapter else { continue }
            var insertIdx = (_chapters.firstIndex(where: { $0 === ch }) ?? 0) + 1
            for file in ch.files.compactMap({ $0 as? AudioFile }) {
                let nc = Chapter()
                nc.name = !file.name.isEmpty ? file.name : file.file
                nc.addFile(file)
                _chapters.insert(nc, at: insertIdx)
                insertIdx += 1
                newChapters.append(nc)
            }
            _chapters.removeAll { $0 === ch }
        }
        cleanupChapters()
        outlineView.deselectAll(self)
        outlineView.reloadData()
        for nc in newChapters { outlineView.expandItem(nc) }
        if let first = newChapters.first { outlineView.setSelectedItem(first) }
    }
}

// MARK: - NSOutlineViewDataSource

extension AudioFileList: NSOutlineViewDataSource {

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if item == nil {
            return chapterMode ? _chapters.count : _files.count
        }
        if let ch = item as? Chapter { return ch.totalFiles() }
        return 0
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        item is Chapter
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if item == nil {
            return chapterMode ? _chapters[index] : _files[index]
        }
        if let ch = item as? Chapter { return ch.fileAtIndex(index) as Any }
        return NSNull()
    }

    func outlineView(_ outlineView: NSOutlineView, objectValueFor tableColumn: NSTableColumn?, byItem item: Any?) -> Any? {
        guard let item else { return nil }

        if let file = item as? AudioFile {
            switch tableColumn?.identifier.rawValue {
            case columnFile: return file.file
            case columnName: return !file.name.isEmpty ? file.name : file.file
            case columnAuthor: return file.artist
            case columnAlbum: return file.album
            case columnTime:
                let dur = UInt32(file.duration.intValue) / 1000
                let h = dur / 3600; let m = (dur - h * 3600) / 60; let s = dur % 60
                return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
            default: return ""
            }
        } else if let ch = item as? Chapter {
            switch tableColumn?.identifier.rawValue {
            case columnName: return ch.name
            case columnTime:
                let dur = ch.totalDuration() / 1000
                let h = dur / 3600; let m = (dur - h * 3600) / 60; let s = dur % 60
                return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
            default: return ""
            }
        }
        return nil
    }

    func outlineView(_ outlineView: NSOutlineView, setObjectValue object: Any?,
                     for tableColumn: NSTableColumn?, byItem item: Any?) {
        guard let ch = item as? Chapter,
              tableColumn?.identifier.rawValue == columnName,
              let name = object as? String else { return }
        ch.name = name
    }

    // MARK: Drag source

    func outlineView(_ outlineView: NSOutlineView, writeItems items: [Any], to pasteboard: NSPasteboard) -> Bool {
        _draggedNodes = items
        pasteboard.declareTypes([simplePboardType, .string, filesPromisePboardType], owner: self)
        pasteboard.setData(Data(), forType: simplePboardType)
        pasteboard.setString(items.description, forType: .string)
        pasteboard.setPropertyList(["txt"], forType: filesPromisePboardType)
        return true
    }

    func outlineView(_ outlineView: NSOutlineView, validateDrop info: NSDraggingInfo,
                     proposedItem item: Any?, proposedChildIndex childIndex: Int) -> NSDragOperation {
        guard childIndex != NSOutlineViewDropOnItemIndex else { return [] }

        if info.draggingSource as? NSOutlineView === outlineView {
            if chapterMode {
                let draggingChapters = _draggedNodes?.allSatisfy { $0 is Chapter } ?? true
                if item == nil && !draggingChapters { return [] }
                if let dragged = _draggedNodes {
                    for node in dragged where node as AnyObject === item as AnyObject { return [] }
                }
            }
        } else {
            _draggedNodes = nil
        }
        return .generic
    }

    func outlineView(_ outlineView: NSOutlineView, acceptDrop info: NSDraggingInfo,
                     item: Any?, childIndex index: Int) -> Bool {
        var childIndex = index
        var newSelection: [Any] = []

        if info.draggingSource as? NSOutlineView === outlineView {
            if chapterMode {
                let dropChapter = item as? Chapter
                if let dropCh = dropChapter {
                    for node in _draggedNodes ?? [] {
                        if let ch = node as? Chapter {
                            for f in ch.files.compactMap({ $0 as? AudioFile }) {
                                dropCh.insertFile(f, atIndex: childIndex)
                                childIndex += 1
                            }
                            _chapters.removeAll { $0 === ch }
                        } else if let file = node as? AudioFile {
                            if dropCh.containsFile(file) {
                                let idx = dropCh.indexOfFile(file)
                                if idx <= childIndex { childIndex -= 1 }
                            }
                            orphanFile(file)
                            dropCh.insertFile(file, atIndex: childIndex)
                            childIndex += 1
                        }
                    }
                } else {
                    for node in _draggedNodes ?? [] {
                        if let ch = node as? Chapter {
                            _chapters.removeAll { $0 === ch }
                            _chapters.insert(ch, at: childIndex)
                            childIndex += 1
                        }
                    }
                }
                cleanupChapters()
            } else {
                for node in _draggedNodes ?? [] {
                    if let file = node as? AudioFile {
                        let oldIndex = _files.firstIndex(where: { $0 === file }) ?? NSNotFound
                        var newIndex = childIndex
                        if oldIndex != NSNotFound {
                            _files.remove(at: oldIndex)
                            if childIndex > oldIndex { newIndex -= 1 }
                        }
                        _files.insert(file, at: newIndex)
                        newIndex += 1
                        newSelection.append(file)
                    }
                }
            }
            _draggedNodes = nil
        } else {
            let pb = info.draggingPasteboard
            guard pb.availableType(from: [filenamesPboardType]) == filenamesPboardType,
                  pb.data(forType: filenamesPboardType) != nil else { return false }

            let sortFiles = UserDefaults.standard.bool(forKey: "SortAudioFiles")
            var fileArray = pb.propertyList(forType: filenamesPboardType) as? [String] ?? []
            if sortFiles { fileArray.sort() }

            for path in fileArray {
                var isDir: ObjCBool = false
                if FileManager.default.fileExists(atPath: path, isDirectory: &isDir) {
                    if isDir.boolValue { addFilesInDirectory(path) } else { addFile(path) }
                }
            }
            tryGuessingAuthorAndAlbum()
        }

        outlineView.reloadData()
        outlineView.setSelectedItems(newSelection)
        return true
    }
}

// MARK: - ExtendedNSOutlineViewDelegate

extension AudioFileList: ExtendedNSOutlineViewDelegate {
    func delKeyDown(_ sender: AnyObject) {
        if let ov = sender as? NSOutlineView {
            Task { @MainActor in
                deleteSelected(ov)
            }
        }
    }

    func outlineView(_ outlineView: NSOutlineView, shouldEdit tableColumn: NSTableColumn?,
                     item: Any) -> Bool {
        item is Chapter && tableColumn?.identifier.rawValue == columnName
    }

    func outlineView(_ outlineView: NSOutlineView, isGroupItem item: Any) -> Bool {
        item is Chapter
    }

    func outlineView(_ outlineView: NSOutlineView, shouldExpandItem item: Any) -> Bool {
        item is Chapter
    }

    func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool { true }

    func outlineView(_ outlineView: NSOutlineView, dataCellFor tableColumn: NSTableColumn?,
                     item: Any) -> NSCell? {
        tableColumn?.dataCell as? NSCell
    }

    func outlineViewSelectionDidChange(_ notification: Notification) {
        guard let ov = notification.object as? NSOutlineView else { return }
        var playable = false
        if ov.selectedItems.count == 1, ov.selectedItems[0] is AudioFile { playable = true }
        canPlay = playable
    }

    func outlineView(_ outlineView: NSOutlineView, didClick tableColumn: NSTableColumn) {
        let cols = outlineView.tableColumns
        if _sortKey != nil {
            for c in cols { outlineView.setIndicatorImage(nil, in: c) }
            if _sortKey == tableColumn.identifier.rawValue { _sortAscending = !_sortAscending }
            else { _sortAscending = true }
        }
        _sortKey = tableColumn.identifier.rawValue
        let descriptor = NSSortDescriptor(key: _sortKey, ascending: _sortAscending)
        if chapterMode {
            for ch in _chapters { ch.sortUsingDescriptor(descriptor) }
        } else {
            let sorted = (_files as NSArray).sortedArray(using: [descriptor])
            _files = sorted.compactMap { $0 as? AudioFile }
        }
        let img = _sortAscending ? NSImage(named: "NSAscendingSortIndicator")
                                 : NSImage(named: "NSDescendingSortIndicator")
        outlineView.setIndicatorImage(img, in: tableColumn)
        outlineView.reloadData()
    }
}
