import AppKit
import UniformTypeIdentifiers

@objc(ExpandedPathToIconTransformer)
class ExpandedPathToIconTransformer: ValueTransformer {
    override class func transformedValueClass() -> AnyClass { NSImage.self }
    override class func allowsReverseTransformation() -> Bool { false }

    override func transformedValue(_ value: Any?) -> Any? {
        guard let val = value as? String else { return nil }
        let path = (val as NSString).expandingTildeInPath
        let icon: NSImage
        if (path as NSString).pathExtension.isEmpty && !FileManager.default.fileExists(atPath: path) {
            icon = NSWorkspace.shared.icon(for: .folder)
        } else {
            icon = NSWorkspace.shared.icon(forFile: path)
        }
        icon.size = NSSize(width: 16, height: 16)
        return icon
    }
}
