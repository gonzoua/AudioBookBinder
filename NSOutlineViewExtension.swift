import Cocoa

@objc protocol ExtendedNSOutlineViewDelegate: NSOutlineViewDelegate {
    func delKeyDown(_ sender: AnyObject)
}

extension NSOutlineView {
    var selectedItems: [Any] {
        var items: [Any] = []
        selectedRowIndexes.forEach { row in
            if let item = item(atRow: row) { items.append(item) }
        }
        return items
    }

    func setSelectedItem(_ item: Any) {
        let row = row(forItem: item)
        if row >= 0 { selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false) }
    }

    func setSelectedItems(_ items: [Any]) {
        var indexSet = IndexSet()
        for item in items {
            let row = row(forItem: item)
            if row >= 0 { indexSet.insert(row) }
        }
        selectRowIndexes(indexSet, byExtendingSelection: false)
    }

    func doExpand() {
        var expandable: [Any] = []
        selectedRowIndexes.forEach { row in
            if let item = item(atRow: row), isExpandable(item) { expandable.append(item) }
        }
        expandable.forEach { expandItem($0) }
    }

    func doCollapse() {
        let rows = selectedRowIndexes
        guard !rows.isEmpty else { return }

        if rows.count == 1 {
            let row = rows.first!
            guard let item = item(atRow: row) else { return }
            if isExpandable(item) {
                collapseItem(item)
            } else if let parent = parent(forItem: item) {
                setSelectedItem(parent)
            }
        } else {
            var chapters: [Any] = []
            rows.forEach { row in
                if let item = item(atRow: row), isExpandable(item) { chapters.append(item) }
            }
            if !chapters.isEmpty {
                chapters.forEach { collapseItem($0) }
                setSelectedItems(chapters)
            }
        }
    }
}

class AudioFileOutlineView: NSOutlineView {
    override func keyDown(with event: NSEvent) {
        guard let chars = event.characters, let scalar = chars.unicodeScalars.first else {
            super.keyDown(with: event)
            return
        }
        let ch = Int(scalar.value)
        switch ch {
        case NSDeleteFunctionKey, NSDeleteCharFunctionKey, 0x7F:
            (delegate as? ExtendedNSOutlineViewDelegate)?.delKeyDown(self)
        case NSLeftArrowFunctionKey:
            doCollapse()
        case NSRightArrowFunctionKey:
            doExpand()
        default:
            super.keyDown(with: event)
        }
    }

}
