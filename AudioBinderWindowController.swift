import Cocoa
@preconcurrency import UserNotifications

private struct ColumnDef {
    let id: String
    let title: String
    var enabled: Bool
}

private let columnsConfiguration = "ColumnsConfiguration"

@objc(AudioBinderWindowController)
class AudioBinderWindowController: NSWindowController, NSSoundDelegate, NSTextFieldDelegate, AudioBinderDelegate {

    // MARK: - IBOutlets
    @IBOutlet private var fileListView: AudioFileOutlineView!
    @IBOutlet private var bindButton: NSButton!
    @IBOutlet private var fileProgress: NSProgressIndicator!
    @IBOutlet private var progressPanel: NSPanel!
    @IBOutlet private var currentFile: NSTextField!
    @IBOutlet private var tabs: NSTabView!
    @IBOutlet private var coverImageView: CoverImageView!
    @IBOutlet private var playButton: NSButton!
    @IBOutlet private var authorField: NSTextField!
    @IBOutlet private var titleField: NSTextField!
    @IBOutlet private var actorField: NSTextField!
    @IBOutlet private var genresButton: NSPopUpButton!
    @IBOutlet private var genresField: NSTextField!
    @IBOutlet private var saveAsPanel: NSPanel!
    @IBOutlet private var saveAsFilename: NSTextField!
    @IBOutlet private var saveAsFolderPopUp: NSPopUpButton!

    // MARK: - Properties

    @objc var currentProgress: Int = 0
    @objc var author: String = ""
    @objc var title: String = ""
    @objc var actor: String = ""
    @objc var genre: String = ""
    @objc var windowTitle: String = ""

    // MARK: - Private state

    private var fileList = AudioFileList()
    private var binder = AudioBinder()
    private var sound: NSSound?
    private var playingFile: String?
    private var outFile: String = ""
    private var conversionResult = false
    private var converting = false
    private var knownGenres: [String] = []

    private var playImg: NSImage?
    private var stopImg: NSImage?

    private var currentFileProgress: Int = 0
    private var totalBookProgress: Int = 0
    private var totalBookDuration: Int = 0

    private var columnDefs: [ColumnDef] = [
        ColumnDef(id: "file",     title: NSLocalizedString("File", comment:""),   enabled: false),
        ColumnDef(id: "artist",   title: NSLocalizedString("Author", comment:""), enabled: false),
        ColumnDef(id: "album",    title: NSLocalizedString("Album", comment: ""),  enabled: false),
        ColumnDef(id: "duration", title: NSLocalizedString("Time", comment: ""),   enabled: false),
    ]

    // MARK: - Init / Deinit

    override init(window: NSWindow?) {
        super.init(window: window)
        updateWindowTitle()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    deinit {
        fileList.removeObserver(self, forKeyPath: "hasFiles")
        fileList.removeObserver(self, forKeyPath: "canPlay")
        fileList.removeObserver(self, forKeyPath: "commonAuthor")
        fileList.removeObserver(self, forKeyPath: "commonAlbum")
    }

    // MARK: - Window Loading

    override func windowDidLoad() {
        super.windowDidLoad()

        fileListView.dataSource = fileList
        fileListView.delegate = fileList
        fileListView.allowsMultipleSelection = true
        fileListView.registerForDraggedTypes([.string, NSPasteboard.PasteboardType("NSFilenamesPboardType")])
        fileListView.setDraggingSourceOperationMask(.every, forLocal: true)
        fileListView.setDraggingSourceOperationMask(.copy, forLocal: false)
        fileListView.autoresizesOutlineColumn = false
        fileListView.expandItem(nil, expandChildren: true)

        if let path = Bundle.main.path(forResource: "Play", ofType: "png") {
            playImg = NSImage(contentsOfFile: path)
        }
        if let path = Bundle.main.path(forResource: "Stop", ofType: "png") {
            stopImg = NSImage(contentsOfFile: path)
        }
        playButton.image = playImg
        playButton.isEnabled = false

        fileList.addObserver(self, forKeyPath: "canPlay",      options: [], context: nil)
        fileList.addObserver(self, forKeyPath: "hasFiles",     options: [], context: nil)
        fileList.addObserver(self, forKeyPath: "commonAuthor", options: [], context: nil)
        fileList.addObserver(self, forKeyPath: "commonAlbum",  options: [], context: nil)

        updateWindowTitle()
        setupColumns()
        setupGenres()
        bindButton.isEnabled = false

        if let delegate = NSApp.delegate as? AudioBookBinderAppDelegate {
            window?.delegate = delegate
        }
    }

    // MARK: - Column Setup

    private func setupColumns() {
        let saved = UserDefaults.standard.array(forKey: columnsConfiguration) as? [[String: Any]]

        if saved == nil {
            if let first = fileListView.tableColumns.first {
                first.identifier = NSUserInterfaceItemIdentifier("name")
            }
            let timeCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("duration"))
            fileListView.addTableColumn(timeCol)
            timeCol.width = 150
        } else {
            let existing = Array(fileListView.tableColumns)
            for (idx, info) in (saved ?? []).enumerated() {
                guard let identifier = info["identifier"] as? String,
                      let width = info["width"] as? CGFloat else { continue }
                if idx == 0 {
                    existing[0].identifier = NSUserInterfaceItemIdentifier(identifier)
                    existing[0].width = width
                } else {
                    let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(identifier))
                    col.width = width
                    fileListView.addTableColumn(col)
                }
            }
        }

        let menu = NSMenu(title: "")
        fileListView.headerView?.menu = menu

        for col in fileListView.tableColumns {
            if let defIdx = columnDefs.firstIndex(where: { $0.id == col.identifier.rawValue }) {
                columnDefs[defIdx].enabled = true
                col.headerCell.stringValue = NSLocalizedString(columnDefs[defIdx].title, comment: "")
            } else if col.identifier.rawValue == "name" {
                col.headerCell.stringValue = NSLocalizedString("Name", comment: "")
                fileListView.outlineTableColumn = col
            }
        }

        for def in columnDefs {
            let item = menu.addItem(withTitle: NSLocalizedString(def.title, comment: ""),
                                    action: #selector(contextMenuSelected(_:)),
                                    keyEquivalent: "")
            item.target = self
            item.representedObject = def.id
            item.state = def.enabled ? .on : .off
        }

        NotificationCenter.default.addObserver(self, selector: #selector(saveTableColumns),
                                               name: NSOutlineView.columnDidMoveNotification,
                                               object: fileListView)
        NotificationCenter.default.addObserver(self, selector: #selector(saveTableColumns),
                                               name: NSOutlineView.columnDidResizeNotification,
                                               object: fileListView)
    }

    private func setupGenres() {
        genresField.stringValue = NSLocalizedString("Audiobooks", comment: "")
        knownGenres = ["Art","Biography","Business","Chick Lit","Children's","Christian",
                       "Classics","Comics","Contemporary","Cookbooks","Crime","Ebooks",
                       "Fantasy","Fiction","Gay And Lesbian","Historical Fiction","History",
                       "Horror","Humor And Comedy","Memoir","Music","Mystery","Non Fiction",
                       "Paranormal","Philosophy","Poetry","Psychology","Religion","Romance",
                       "Science","Science Fiction","Self Help","Suspense","Spirituality",
                       "Sports","Thriller","Travel","Young Adult"]
        genresButton.removeAllItems()
        genresButton.addItems(withTitles: knownGenres)
        genresButton.target = self
        genresButton.action = #selector(genresButtonChanged(_:))
        genresField.delegate = self
    }

    @objc private func saveTableColumns() {
        let cols = fileListView.tableColumns.map { col -> [String: Any] in
            ["identifier": col.identifier.rawValue, "width": col.width]
        }
        UserDefaults.standard.set(cols, forKey: columnsConfiguration)
    }

    // MARK: - IBActions

    @IBAction func addFiles(_ sender: Any) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK else { return }

        let sortFiles = UserDefaults.standard.bool(forKey: "SortAudioFiles")
        let urls = sortFiles ? panel.urls.sorted { $0.path < $1.path } : panel.urls

        for url in urls {
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) {
                if isDir.boolValue { fileList.addFilesInDirectory(url.path) }
                else { fileList.addFile(url.path) }
            }
        }
        fileList.tryGuessingAuthorAndAlbum()
        fileListView.reloadData()
    }

    @IBAction func delFiles(_ sender: Any) {
        fileList.deleteSelected(fileListView)
    }

    @IBAction func bind(_ sender: Any) {
        let authorStr = authorField.stringValue
        let titleStr = titleField.stringValue
        var filename = ""
        let a = authorStr
            .replacingOccurrences(of: "/", with: " ")
            .replacingOccurrences(of: ":", with: " -")
        let t = titleStr
            .replacingOccurrences(of: "/", with: " ")
            .replacingOccurrences(of: ":", with: " -")
        if !a.isEmpty { filename += a }
        if !t.isEmpty {
            if !filename.isEmpty { filename += " - " }
            filename += t
        }
        if filename.isEmpty { filename = "audiobook" }
        filename += ".m4b"

        let savePanel = NSSavePanel()
        let dir = UserDefaults.standard.string(forKey: "DestinationFolder") ?? NSHomeDirectory()
        savePanel.directoryURL = URL(fileURLWithPath: dir)
        savePanel.nameFieldStringValue = filename
        guard savePanel.runModal() == .OK, let url = savePanel.url else { return }

        bindButton.isEnabled = false
        outFile = url.path
        converting = true
        // The heavy lifting happens inside the AudioBinder actor, so the main thread stays free
        Task { [weak self] in
            await self?.bindToFileThread()
        }
    }

    @IBAction func saveAsOk(_ sender: Any) {
        self.window?.endSheet(saveAsPanel)
        saveAsPanel.orderOut(nil)

        let destPath = UserDefaults.standard.string(forKey: "DestinationFolder") ?? NSHomeDirectory()
        outFile = (destPath as NSString).appendingPathComponent(saveAsFilename.stringValue)

        if FileManager.default.fileExists(atPath: outFile) {
            let alert = NSAlert()
            alert.addButton(withTitle: NSLocalizedString("Replace", comment: ""))
            alert.addButton(withTitle: NSLocalizedString("Cancel", comment: ""))
            alert.messageText = NSLocalizedString("File exists", comment: "")
            alert.informativeText = String(format: NSLocalizedString("File %@ already exists, replace?", comment: ""), outFile)
            alert.alertStyle = .warning
            if alert.runModal() == .alertSecondButtonReturn { return }
        }

        bindButton.isEnabled = false
        converting = true
        // The heavy lifting happens inside the AudioBinder actor, so the main thread stays free
        Task { [weak self] in
            await self?.bindToFileThread()
        }
    }

    @IBAction func saveAsCancel(_ sender: Any) {
        self.window?.endSheet(saveAsPanel)
        saveAsPanel.orderOut(nil)
    }

    @IBAction func setCover(_ sender: Any) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), !isDir.boolValue {
            coverImageView.coverImageFilename = url.path
            tabs.selectTabViewItem(at: 1)
        }
        fileListView.reloadData()
    }

    @IBAction func toggleChapters(_ sender: Any) {
        fileList.switchChapterMode()
        fileListView.reloadData()
        fileListView.expandItem(nil, expandChildren: true)
    }

    @IBAction func renumberChapters(_ sender: Any) {
        fileList.renumberChapters()
        fileListView.reloadData()
    }

    @IBAction func joinFiles(_ sender: Any) {
        fileList.joinSelectedFiles(fileListView)
    }

    @IBAction func splitFiles(_ sender: Any) {
        fileList.splitSelectedFiles(fileListView)
    }

    @IBAction func resetToDefaults(_ sender: Any) {
        authorField.stringValue = ""
        titleField.stringValue = ""
        actorField.stringValue = ""
        genresField.stringValue = "Audiobooks"
        fileList.removeAllFiles(fileListView)
        coverImageView.resetImage()
    }

    @IBAction func cancel(_ sender: Any) {
        Task {
            await binder.cancel()
        }
    }

    @IBAction func playStop(_ sender: Any) {
        if let snd = sound, snd.isPlaying {
            snd.stop()
            return
        }
        guard fileListView.selectedItems.count == 1,
              let file = fileListView.selectedItems[0] as? AudioFile else { return }

        playButton.image = stopImg
        playingFile = file.filePath
        let snd = NSSound(contentsOfFile: file.filePath, byReference: false)
        snd?.delegate = self
        sound = snd
        if snd?.play() == false {
            playButton.image = playImg
            sound = nil
            playButton.isEnabled = fileList.canPlay
            playFailed()
        }
    }

    @IBAction func genresButtonChanged(_ sender: Any) {
        genresField.stringValue = genresButton.selectedItem?.title ?? ""
    }

    @IBAction func folderSheetShow(_ sender: Any) {
        let panel = NSOpenPanel()
        panel.prompt = NSLocalizedString("Select", comment: "")
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.beginSheetModal(for: saveAsPanel) { [weak self] result in
            if result == .OK, let url = panel.url {
                UserDefaults.standard.set(url.path, forKey: "DestinationFolder")
            }
            self?.saveAsFolderPopUp.selectItem(at: 0)
        }
    }

    @objc private func contextMenuSelected(_ sender: NSMenuItem) {
        if sender.state == .off {
            sender.state = .on
            if let defId = sender.representedObject as? String,
               let def = columnDefs.first(where: { $0.id == defId }) {
                let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(defId))
                fileListView.addTableColumn(col)
                col.headerCell.stringValue = NSLocalizedString(def.title, comment: "")
            }
        } else {
            if let defId = sender.representedObject as? String,
               let col = fileListView.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier(defId)) {
                fileListView.removeTableColumn(col)
            }
            sender.state = .off
        }
    }

    // MARK: - Window Title

    @objc func updateWindowTitle() {
        author = authorField?.stringValue.trimmingCharacters(in: .whitespaces) ?? ""
        title  = titleField?.stringValue.trimmingCharacters(in: .whitespaces) ?? ""
        actor  = actorField?.stringValue.trimmingCharacters(in: .whitespaces) ?? ""
        genre  = genresField?.stringValue.trimmingCharacters(in: .whitespaces) ?? ""

        let t: String
        if author.isEmpty && title.isEmpty {
            t = NSLocalizedString("Audiobook", comment: "")
        } else {
            t = "\(title) - \(author)"
        }
        windowTitle = t
        if window?.title != windowTitle { window?.title = windowTitle }
    }

    // MARK: - Progress helpers

    private func updateProgressString(_ message: String) {
        DispatchQueue.main.async { [weak self] in self?.currentFile.stringValue = message }
    }

    private func updateProgress(_ handled: Double, total: Double) {
        DispatchQueue.main.async { [weak self] in
            self?.fileProgress.maxValue = total
            self?.fileProgress.doubleValue = handled
        }
    }

    private func recalculateProgress() {
        guard totalBookDuration > 0 else { return }
        let newProgress = Int(floor(Double(currentFileProgress + totalBookProgress) * 100.0 / Double(totalBookDuration)))
        if newProgress != currentProgress {
            currentProgress = newProgress
            StatsManager.shared.updateConverter(self)
        }
    }

    // MARK: - Binding thread

    private func bindToFileThread() async {
        let coverImage = coverImageView.coverImage
        var coverImageFilename: String? = nil
        let hours = UserDefaults.standard.integer(forKey: "MaxVolumeSize")
        let maxVolumeDuration: Int = (hours > 0 && hours < 25) ? hours * 3600 : 0

        conversionResult = false
        await binder.reset()
        await binder.setDelegate(self)
        let channels  = UInt32(UserDefaults.standard.integer(forKey: "Channels"))
        let sampleRate = UserDefaults.standard.float(forKey: "SampleRate")
        let bitrate   = UInt32(UserDefaults.standard.integer(forKey: "Bitrate"))
        await binder.configure(channels: channels, sampleRate: sampleRate, bitrate: bitrate)

        let outBase = (outFile as NSString).deletingPathExtension
        let outExt  = (outFile as NSString).pathExtension
        let files   = fileList.files()
        var inputFiles: [String] = []
        var estVolumeDuration = 0
        var currentVolumeName = outFile
        var volumeChapters: [[Chapter]] = []
        var curChapters: [Chapter] = []
        var curChapter: Chapter? = nil
        var chapterIdx = 0
        let hasChapters = fileList.chapterMode
        let chapters = fileList.chapters()

        if hasChapters && !chapters.isEmpty {
            curChapter = chapters[chapterIdx].copy() as? Chapter
            chapterIdx += 1
            if let cc = curChapter { curChapters.append(cc) }
        }

        var totalVolumes = 0
        currentFileProgress = 0
        totalBookDuration   = 0
        totalBookProgress   = 0
        currentProgress     = 0

        StatsManager.shared.updateConverter(self)

        var onChapterBoundary = true
        for file in files {
            if hasChapters, let cc = curChapter, !cc.containsFile(file) {
                if chapterIdx < chapters.count {
                    curChapter = chapters[chapterIdx].copy() as? Chapter
                    chapterIdx += 1
                }
                onChapterBoundary = true
                if let nc = curChapter { curChapters.append(nc) }
            }

            if maxVolumeDuration > 0 {
                let fileDur = file.duration.intValue
                if (estVolumeDuration + fileDur) > maxVolumeDuration * 1000 {
                    if !inputFiles.isEmpty {
                        await binder.addVolume(currentVolumeName, files: inputFiles)
                        inputFiles.removeAll()
                        estVolumeDuration = 0
                        totalVolumes += 1
                        currentVolumeName = "\(outBase)-\(totalVolumes).\(outExt)"
                        if hasChapters {
                            volumeChapters.append(curChapters)
                            if !onChapterBoundary, let cc = curChapter {
                                curChapter = cc.split(atFile: file) ?? cc
                            }
                            curChapters = []
                            if let nc = curChapter { curChapters.append(nc) }
                        }
                    } else {
                        let msg = String(format: NSLocalizedString("%@: duration (%d sec) is larger than the maximum volume duration (%lld sec.)", comment:""),
                                        file.filePath, file.duration.intValue / 1000, maxVolumeDuration)
                        DispatchQueue.main.async {
                            let alert = NSAlert()
                            alert.addButton(withTitle: "OK")
                            alert.messageText = NSLocalizedString("Failed to split audiobook into volumes", comment: "")
                            alert.informativeText = msg
                            alert.alertStyle = .warning
                            alert.runModal()
                        }
                        StatsManager.shared.removeConverter(self)
                        return
                    }
                }
            }

            onChapterBoundary = false
            inputFiles.append(file.filePath)
            let fileDur = file.duration.intValue
            estVolumeDuration += fileDur
            totalBookDuration += fileDur
        }

        await binder.addVolume(currentVolumeName, files: inputFiles)
        volumeChapters.append(curChapters)

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.window!.beginSheet(self.progressPanel)
        }
        updateProgress(0, total: 100)

        conversionResult = await binder.convert()

        if conversionResult {
            updateProgressString(NSLocalizedString("Adding artist/title tags", comment: ""))

            var temporaryFile = false
            if coverImageView.haveCover {
                if coverImageView.shouldConvert {
                    let tmpName = (NSTemporaryDirectory() as NSString)
                        .appendingPathComponent("coverimg_\(arc4random()).png")
                    if let tiff = coverImage?.tiffRepresentation,
                       let rep = NSBitmapImageRep(data: tiff),
                       let png = rep.representation(using: .png, properties: [:]) {
                        try? png.write(to: URL(fileURLWithPath: tmpName))
                        coverImageFilename = tmpName
                        temporaryFile = true
                    }
                } else {
                    coverImageFilename = coverImageView.coverImageFilename
                }
            }

            let volumes = await binder.volumeFiles()
            let trackCount = volumes.count
            for (idx, v) in volumes.enumerated() {
                guard let mp4 = MP4File(fileName: v) else { continue }
                mp4.artist  = author
                mp4.title   = trackCount > 1 ? String(format: "%@ #%02d", title, idx + 1) : title
                mp4.album   = title
                mp4.narrator = actor
                mp4.genre   = genre
                mp4.gaplessPlay = trackCount > 1
                mp4.track   = UInt16(idx + 1)
                mp4.tracksTotal = UInt16(trackCount)
                if let cp = coverImageFilename { mp4.coverFile = cp }
                mp4.update()
            }

            if fileList.chapterMode {
                updateProgressString(NSLocalizedString("Adding chapter markers", comment: ""))
                for (idx, v) in volumes.enumerated() {
                    let editor = MetaEditor()
                    if idx < volumeChapters.count {
                        editor.addChapters(volumeChapters[idx], toFile: v)
                    }
                }
            }

            if temporaryFile, let cp = coverImageFilename {
                try? FileManager.default.removeItem(atPath: cp)
            }

            updateProgressString("Done")
        }

        StatsManager.shared.removeConverter(self)

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.window?.endSheet(self.progressPanel)
            self.progressPanel.orderOut(nil)
            self.converting = false
            if self.conversionResult {
                let subtitle = (self.outFile as NSString).lastPathComponent
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
                    guard granted else { return }
                    let content = UNMutableNotificationContent()
                    content.title = NSLocalizedString("Audiobook is ready", comment: "")
                    content.subtitle = subtitle
                    content.sound = .default
                    let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
                    UNUserNotificationCenter.current().add(request)
                }
            }
            self.bindButton.isEnabled = true
        }
    }

    private func playFailed() {
        let alert = NSAlert()
        let msg = String(format: NSLocalizedString("Failed to play: %@", comment: ""), playingFile ?? "")
        alert.addButton(withTitle: "OK")
        alert.messageText = NSLocalizedString("Failed to play", comment: "")
        alert.informativeText = msg
        alert.alertStyle = .warning
        alert.runModal()
    }

    // MARK: - NSSoundDelegate

    func sound(_ sound: NSSound, didFinishPlaying flag: Bool) {
        playButton.image = playImg
        self.sound = nil
        playButton.isEnabled = fileList.canPlay
    }

    // MARK: - NSTextFieldDelegate

    func controlTextDidEndEditing(_ obj: Notification) {
        if let ctrl = obj.object as? NSTextField,
           ctrl === authorField || ctrl === titleField || ctrl === actorField {
            updateWindowTitle()
        }
    }

    func control(_ control: NSControl, textView: NSTextView,
                 completions words: [String], forPartialWordRange charRange: NSRange,
                 indexOfSelectedItem index: UnsafeMutablePointer<Int>) -> [String] {
        let partial = (textView.string as NSString).substring(with: charRange)
        let matches = knownGenres.filter {
            ($0 as NSString).compare(partial, options: .caseInsensitive,
                                     range: NSRange(location: 0, length: partial.utf16.count)) == .orderedSame
        }
        index.pointee = 0
        return matches
    }

    // MARK: - KVO

    override func observeValue(forKeyPath keyPath: String?, of object: Any?,
                               change: [NSKeyValueChangeKey: Any]?,
                               context: UnsafeMutableRawPointer?) {
        Task { @MainActor in
            switch keyPath {
            case "canPlay":
                if sound == nil { playButton.isEnabled = fileList.canPlay }
            case "hasFiles":
                bindButton.isEnabled = fileList.hasFiles
            case "commonAuthor":
                if authorField.stringValue.isEmpty,
                   let guessed = fileList.commonAuthor, !guessed.isEmpty {
                    authorField.stringValue = guessed
                }
                updateWindowTitle()
            case "commonAlbum":
                if titleField.stringValue.isEmpty,
                   let guessed = fileList.commonAlbum, !guessed.isEmpty {
                    titleField.stringValue = guessed
                }
                updateWindowTitle()
            default:
                break;
                // super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
            }
        }
    }

    // MARK: - AudioBinderDelegate

    func conversionStart(_ file: AudioFile,
                         format: UnsafeMutablePointer<AudioStreamBasicDescription>?,
                         formatDescription description: String?,
                         length frames: UInt64) {
        updateProgressString(String(format: NSLocalizedString("Converting %@", comment: ""), file.filePath))
        updateProgress(0, total: Double(frames))
    }

    func updateStatus(_ file: AudioFile, handled handledFrames: UInt64, total totalFrames: UInt64) {
        updateProgress(Double(handledFrames), total: Double(totalFrames))
        if totalFrames > 0 {
            currentFileProgress = Int(file.duration.intValue) * Int(handledFrames) / Int(totalFrames)
            recalculateProgress()
        }
    }

    func continueFailedConversion(_ file: AudioFile, reason: String?) -> Bool {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.addButton(withTitle: "OK")
            alert.messageText = NSLocalizedString("Audiofile conversion failed", comment: "")
            alert.informativeText = reason ?? ""
            alert.alertStyle = .warning
            alert.runModal()
        }
        return false
    }

    func conversionFinished(_ file: AudioFile, duration: UInt32) {
        file.valid = true
        file.duration = NSNumber(value: duration)
        if totalBookDuration > 0 {
            totalBookProgress += Int(duration)
            currentFileProgress = 0
            recalculateProgress()
        }
    }

    func volumeFailed(_ filename: String, reason: String?) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.addButton(withTitle: "OK")
            alert.messageText = NSLocalizedString("Audiobook binding failed", comment: "")
            alert.informativeText = reason ?? ""
            alert.alertStyle = .warning
            alert.runModal()
        }
    }

    func volumeReady(_ volumeName: String, duration seconds: UInt32) {}
    func audiobookReady(_ seconds: UInt32) {}
}
