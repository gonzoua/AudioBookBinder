import Cocoa

private let iTunesCoverSize: CGFloat = 300

@objc(CoverImageView)
class CoverImageView: NSView {

    @objc var coverImage: NSImage? {
        didSet { updateScaledImage() }
    }

    @objc var coverImageFilename: String? {
        didSet {
            guard let path = coverImageFilename else {
                coverImage = nil
                return
            }
            guard let img = NSImage(contentsOfFile: path) else {
                coverImageFilename = nil
                return
            }
            // Avoid infinite didSet loop by setting coverImage directly
            _coverImage = img
            updateScaledImage()
        }
    }

    private var _coverImage: NSImage?
    private var scaledImage: NSImage?
    private var highlighted = false
    private let highlightedColor = NSColor.black
    private let normalColor = NSColor(calibratedWhite: 0.4, alpha: 1.0)
    private let placeholderText = NSLocalizedString("⌘ + I\nor\nDrag Image Here", comment:"")
    private var textAttributes: [NSAttributedString.Key: Any] = [:]

    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        textAttributes = [
            .font: NSFont(name: "Helvetica", size: 24) ?? NSFont.systemFont(ofSize: 24),
            .paragraphStyle: style
        ]
        registerForDraggedTypes([.tiff, NSPasteboard.PasteboardType("NSFilenamesPboardType")])
    }

    @objc func resetImage() {
        _coverImage = nil
        scaledImage = nil
        coverImageFilename = nil
        needsDisplay = true
    }

    @objc var haveCover: Bool { _coverImage != nil }

    @objc var shouldConvert: Bool {
        guard let filename = coverImageFilename else { return true }
        let ext = (filename as NSString).pathExtension.lowercased()
        return ext != "jpg" && ext != "jpeg" && ext != "png"
    }

    private func updateScaledImage() {
        let image = coverImage ?? _coverImage
        guard let image else {
            scaledImage = nil
            needsDisplay = true
            return
        }
        let copy = image.copy() as! NSImage
        guard let rep = copy.representations.first else {
            scaledImage = copy
            needsDisplay = true
            return
        }
        let origSize = NSSize(width: rep.pixelsWide, height: rep.pixelsHigh)
        copy.size = origSize

        if origSize.width > iTunesCoverSize || origSize.height > iTunesCoverSize {
            let scaledSize: NSSize
            if origSize.width > origSize.height {
                scaledSize = NSSize(width: iTunesCoverSize,
                                   height: origSize.height * iTunesCoverSize / origSize.width)
            } else {
                scaledSize = NSSize(width: origSize.width * iTunesCoverSize / origSize.height,
                                   height: iTunesCoverSize)
            }
            let scaled = NSImage(size: scaledSize)
            scaled.lockFocus()
            NSGraphicsContext.current?.imageInterpolation = .high
            copy.draw(in: NSRect(origin: .zero, size: scaledSize),
                      from: NSRect(origin: .zero, size: origSize),
                      operation: .sourceOver, fraction: 1.0)
            scaled.unlockFocus()
            scaledImage = scaled
        } else {
            scaledImage = copy.copy() as? NSImage
        }
        _coverImage = image
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        if let img = scaledImage {
            let imgSize = img.size
            let origin = NSPoint(x: (bounds.width - imgSize.width) / 2,
                                 y: (bounds.height - imgSize.height) / 2)
            img.draw(at: origin, from: NSRect(origin: .zero, size: imgSize),
                     operation: .sourceOver, fraction: 1.0)
        } else {
            let color = highlighted ? highlightedColor : normalColor
            var attrs = textAttributes
            attrs[.foregroundColor] = color

            let borderWidth: CGFloat = 4.0
            var bgRect = bounds.insetBy(dx: borderWidth / 2, dy: borderWidth / 2).integral
            bgRect.origin.x += 0.5
            bgRect.origin.y += 0.5

            let minX = bgRect.minX, midX = bgRect.midX, maxX = bgRect.maxX
            let minY = bgRect.minY, midY = bgRect.midY, maxY = bgRect.maxY
            let radius: CGFloat = 25.0

            let path = NSBezierPath()
            path.move(to: NSPoint(x: midX, y: minY))
            path.appendArc(from: NSPoint(x: maxX, y: minY), to: NSPoint(x: maxX, y: midY), radius: radius)
            path.appendArc(from: NSPoint(x: maxX, y: maxY), to: NSPoint(x: midX, y: maxY), radius: radius)
            path.appendArc(from: NSPoint(x: minX, y: maxY), to: NSPoint(x: minX, y: midY), radius: radius)
            path.appendArc(from: bgRect.origin, to: NSPoint(x: midX, y: minY), radius: radius)
            path.close()

            color.set()
            path.lineWidth = borderWidth
            path.setLineDash([5.0, 2.0], count: 2, phase: 0.0)
            path.lineCapStyle = .round
            path.stroke()

            let str = placeholderText as NSString
            let strSize = str.size(withAttributes: attrs)
            let strRect = NSRect(x: bounds.origin.x + (bounds.width - strSize.width) / 2,
                                 y: bounds.origin.y + (bounds.height - strSize.height) / 2,
                                 width: strSize.width, height: strSize.height)
            str.draw(in: strRect, withAttributes: attrs)
        }
    }

    // MARK: - Drag & Drop

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard sender.draggingSource as? NSView !== self else { return [] }
        let pb = sender.draggingPasteboard
        let types: [NSPasteboard.PasteboardType] = [.tiff, .init("NSFilenamesPboardType")]
        guard let type = pb.availableType(from: types),
              pb.data(forType: type) != nil else { return [] }
        if type == .init("NSFilenamesPboardType") {
            let files = pb.propertyList(forType: type) as? [String] ?? []
            if files.count > 1 { return [] }
        }
        highlighted = true
        needsDisplay = true
        return .generic
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        highlighted = false
        needsDisplay = true
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool { true }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pb = sender.draggingPasteboard
        let types: [NSPasteboard.PasteboardType] = [.tiff, .init("NSFilenamesPboardType")]
        guard let type = pb.availableType(from: types),
              pb.data(forType: type) != nil else { return false }

        if type == .tiff {
            guard let data = pb.data(forType: .tiff),
                  let img = NSImage(data: data) else { return false }
            resetImage()
            _coverImage = img
            updateScaledImage()
        } else {
            guard let files = pb.propertyList(forType: type) as? [String],
                  let path = files.first else { return false }
            coverImageFilename = path
            if _coverImage == nil { return false }
        }
        return true
    }

    override func concludeDragOperation(_ sender: NSDraggingInfo?) {
        highlighted = false
        needsDisplay = true
    }

    override func keyDown(with event: NSEvent) {
        guard let chars = event.characters, let scalar = chars.unicodeScalars.first else {
            super.keyDown(with: event)
            return
        }
        let ch = Int(scalar.value)
        if ch == NSDeleteFunctionKey || ch == NSDeleteCharFunctionKey || ch == 0x7F {
            resetImage()
        } else {
            super.keyDown(with: event)
        }
    }

    override var acceptsFirstResponder: Bool { true }
}
