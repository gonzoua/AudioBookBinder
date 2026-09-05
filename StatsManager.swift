import AppKit

class StatsManager: NSObject, @unchecked Sendable {
    static let shared = StatsManager()

    private var converters: [AudioBinderWindowController] = []
    private let lock = NSLock()
    private let appIcon = NSImage(named: "NSApplicationIcon")

    private static let maxBars = 5

    static func sharedInstance() -> StatsManager { shared }

    @MainActor
    func updateConverter(_ converter: AudioBinderWindowController) {
        lock.lock()
        if !converters.contains(converter) { converters.append(converter) }
        updateProgress()
        lock.unlock()
    }

    @MainActor
    func removeConverter(_ converter: AudioBinderWindowController) {
        lock.lock()
        if let idx = converters.firstIndex(of: converter) {
            converters.remove(at: idx)
            updateProgress()
        }
        lock.unlock()
    }

    @MainActor
    private func updateProgress() {
        guard !converters.isEmpty else {
            DispatchQueue.main.async { NSApp.applicationIconImage = self.appIcon }
            return
        }

        let progressGradient: NSImage? = {
            if let path = Bundle.main.path(forResource: "MiniProgressGradient", ofType: "png") {
                return NSImage(contentsOfFile: path)
            }
            return nil
        }()

        guard let base = appIcon?.copy() as? NSImage else { return }

        base.lockFocus()
        let barHeight: CGFloat = 4.0 / 32
        let barHeightInIcon: CGFloat = 5.0 / 32
        var yoff: CGFloat = 0
        let bars = min(StatsManager.maxBars, converters.count)

        for i in stride(from: bars - 1, through: 0, by: -1) {
            let s = base.size
            let height = barHeightInIcon
            let bar = NSRect(x: 0,
                             y: yoff + s.height * (height - barHeight / 2),
                             width: s.width - 1,
                             height: s.height * barHeight)
            yoff += s.height * barHeight + 5

            NSColor.white.set()
            NSBezierPath.fill(bar)

            var done = bar
            done.size.width *= CGFloat(converters[i].currentProgress) / 100.0

            if let grad = progressGradient {
                grad.draw(in: done, from: NSRect(origin: .zero, size: grad.size),
                          operation: .copy, fraction: 1.0)
            }

            NSColor.black.set()
            NSBezierPath.stroke(bar)
        }
        base.unlockFocus()

        DispatchQueue.main.async { NSApp.applicationIconImage = base }
    }
}
