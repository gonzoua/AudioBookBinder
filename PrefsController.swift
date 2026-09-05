import Cocoa

class VolumeLengthTransformer: ValueTransformer {
    override class func transformedValueClass() -> AnyClass { NSString.self }
    override class func allowsReverseTransformation() -> Bool { false }
    override func transformedValue(_ value: Any?) -> Any? {
        guard let n = value as? NSNumber else { return "" }
        let len = n.intValue
        return len == 25 ? "--" : "\(len)"
    }
}

@objc(PrefsController)
class PrefsController: NSWindowController {
    @IBOutlet private var folderPopUp: NSPopUpButton!

    @objc dynamic var validBitrates: [UInt32] = []

    // Accessed from nonisolated awakeFromNib and deinit; only touched on the main thread in practice.
    nonisolated(unsafe) private var isConfigured = false

    // The controller is instantiated from MainMenu.xib as a custom object rather
    // than via windowNibName, so windowDidLoad is never called; set up here instead.
    override func awakeFromNib() {
        super.awakeFromNib()
        guard !isConfigured else { return }
        DispatchQueue.main.async { [weak self] in
            self?.isConfigured = true
            self?.folderPopUp.selectItem(at: 0)
            self?.updateValidBitrates()
        }
        UserDefaults.standard.addObserver(self, forKeyPath: "Channels", options:    [], context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: "SampleRate", options: [], context: nil)
    }

    deinit {
        guard isConfigured else { return }
        UserDefaults.standard.removeObserver(self, forKeyPath: "Channels")
        UserDefaults.standard.removeObserver(self, forKeyPath: "SampleRate")
    }

    @IBAction func folderSheetShow(_ sender: Any) {
        let panel = NSOpenPanel()
        panel.prompt = NSLocalizedString("Select", comment: "Preferences -> Open panel prompt")
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.beginSheetModal(for: window!) { [weak self] result in
            guard let self else { return }
            if result == .OK, let url = panel.url {
                UserDefaults.standard.set(url.path, forKey: "DestinationFolder")
            }
            self.folderPopUp.selectItem(at: 0)
        }
    }

    func updateValidBitrates() {
        let channels = UInt32(UserDefaults.standard.integer(forKey: "Channels"))
        let sampleRate = UserDefaults.standard.float(forKey: "SampleRate")

        validBitrates = getValidBitrate(channels, sampleRate)
        fixupBitrate()
    }

    func fixupBitrate() {
        let bitrate = UserDefaults.standard.integer(forKey: "Bitrate")
        var newBitrate = bitrate
        var distance = bitrate
        for n in validBitrates {
            let diff = abs(Int(n) - bitrate)
            if diff < distance { distance = diff; newBitrate = Int(n) }
        }
        if newBitrate != bitrate {
            UserDefaults.standard.set(newBitrate, forKey: "Bitrate")
        }
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?,
                               change: [NSKeyValueChangeKey: Any]?,
                               context: UnsafeMutableRawPointer?) {
        if keyPath == "Channels" || keyPath == "SampleRate" {
            Task { @MainActor in
                updateValidBitrates()
            }
        } else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }
}
