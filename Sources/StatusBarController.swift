import AppKit

enum AppState {
    case idle
    case recording
    case processing
    case done
}

class StatusBarController {
    private var statusItem: NSStatusItem!
    private var doneTimer: Timer?

    init() {
        // Ensure creation on main thread
        if Thread.isMainThread {
            setup()
        } else {
            DispatchQueue.main.sync { setup() }
        }
    }

    private func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        guard let button = statusItem.button else {
            print("[VoicePaste] WARNING: Failed to get status bar button")
            return
        }
        let image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "VoicePaste")
        image?.isTemplate = true
        button.image = image
        print("[VoicePaste] Menu bar icon created.")
    }

    func setState(_ state: AppState) {
        let work = { [weak self] in
            guard let self = self, let button = self.statusItem?.button else { return }
            self.doneTimer?.invalidate()
            self.doneTimer = nil

            switch state {
            case .idle:
                let image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "VoicePaste")
                image?.isTemplate = true
                button.image = image
                button.contentTintColor = nil
            case .recording:
                let config = NSImage.SymbolConfiguration(paletteColors: [.white, .systemRed])
                let image = NSImage(systemSymbolName: "mic.circle.fill", accessibilityDescription: "Recording")
                button.image = image?.withSymbolConfiguration(config) ?? image
                button.image?.isTemplate = false
            case .processing:
                let config = NSImage.SymbolConfiguration(paletteColors: [.white, .systemOrange])
                let image = NSImage(systemSymbolName: "mic.circle.fill", accessibilityDescription: "Processing")
                button.image = image?.withSymbolConfiguration(config) ?? image
                button.image?.isTemplate = false
            case .done:
                let config = NSImage.SymbolConfiguration(paletteColors: [.white, .systemGreen])
                let image = NSImage(systemSymbolName: "mic.circle.fill", accessibilityDescription: "Done")
                button.image = image?.withSymbolConfiguration(config) ?? image
                button.image?.isTemplate = false
                self.doneTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
                    self?.setState(.idle)
                }
            }
        }

        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.async { work() }
        }
    }
}
