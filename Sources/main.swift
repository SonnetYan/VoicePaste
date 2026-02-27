import AppKit

// Hide from Dock (LSUIElement equivalent for SPM builds)
let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let delegate = AppDelegate()
app.delegate = delegate
app.run()
