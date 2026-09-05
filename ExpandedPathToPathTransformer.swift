import Foundation

@objc(ExpandedPathToPathTransformer)
class ExpandedPathToPathTransformer: ValueTransformer {
    override class func transformedValueClass() -> AnyClass { NSString.self }
    override class func allowsReverseTransformation() -> Bool { false }

    override func transformedValue(_ value: Any?) -> Any? {
        guard let path = value as? String else { return nil }
        return FileManager.default.displayName(atPath: path)
    }
}
