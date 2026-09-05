import Cocoa

@objc(AudioBookBinderAppDelegate)
class AudioBookBinderAppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {

    @IBOutlet private var applicationMenu: NSMenu!

    private var windowControllers: [AudioBinderWindowController] = []

    override init() {
        super.init()
        registerDefaultsAndTransformers()
    }

    private func registerDefaultsAndTransformers() {
        let musicPath = NSSearchPathForDirectoriesInDomains(.musicDirectory, .userDomainMask, true).first
            ?? NSHomeDirectory()

        let appDefaults: [String: Any] = [
            "Channels": 2,
            "AddToiTunes": true,
            "SampleRate": "44100",
            "Bitrate": "128000",
            "MaxVolumeSize": 12,
            "SortAudioFiles": true,
            "ChaptersEnabled": true,
            "DestinationFolder": musicPath
        ]
        UserDefaults.standard.register(defaults: appDefaults)

        ValueTransformer.setValueTransformer(ExpandedPathToPathTransformer(),
                                             forName: NSValueTransformerName("ExpandedPathToPathTransformer"))
        ValueTransformer.setValueTransformer(ExpandedPathToIconTransformer(),
                                             forName: NSValueTransformerName("ExpandedPathToIconTransformer"))
        ValueTransformer.setValueTransformer(VolumeLengthTransformer(),
                                             forName: NSValueTransformerName("VolumeLengthTransformer"))
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let firstItem = applicationMenu?.item(at: 0), let submenu = firstItem.submenu {
            if submenu.numberOfItems > 1 { submenu.removeItem(at: 1) }
        }
        newAudiobookWindow(nil)
    }

    @IBAction func newAudiobookWindow(_ sender: Any?) {
        let controller = AudioBinderWindowController(windowNibName: "AudioBinderWindow")
        controller.showWindow(self)
        controller.window?.makeMain()
        windowControllers.append(controller)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { newAudiobookWindow(nil) }
        return true
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        windowControllers.removeAll { $0.window === window }
    }

    func windowDidResignKey(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        windowControllers.first { $0.window === window }?.updateWindowTitle()
    }
}
