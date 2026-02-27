import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var coordinator: AppCoordinator?

    func applicationDidFinishLaunching(_ notification: Notification) {
        coordinator = AppCoordinator()
        print("[VoicePaste] App launched. Hold Right Option key to record.")
    }
}
