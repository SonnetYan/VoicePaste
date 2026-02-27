import CoreGraphics
import Foundation

class HotkeyManager {
    var onKeyDown: (() -> Void)?
    var onKeyUp: (() -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isKeyDown = false

    // Right Option key
    private let rightOptionKeyCode: Int64 = 61

    func register() {
        let eventMask: CGEventMask =
            (1 << CGEventType.flagsChanged.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: hotkeyCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            print("[VoicePaste] Failed to create event tap. Grant Accessibility permission in System Settings → Privacy & Security → Accessibility.")
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        print("[VoicePaste] Global hotkey registered (Right Option key).")
    }

    func unregister() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        eventTap = nil
        runLoopSource = nil
    }

    fileprivate func handleEvent(_ event: CGEvent) {
        let type = event.type

        // Handle tap being disabled by the system (e.g. timeout)
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return
        }

        guard type == .flagsChanged else { return }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags

        // Only react to the right Option key (keyCode 61)
        guard keyCode == rightOptionKeyCode else { return }

        if flags.contains(.maskAlternate) && !isKeyDown {
            // Right Option pressed
            isKeyDown = true
            DispatchQueue.main.async { self.onKeyDown?() }
        } else if !flags.contains(.maskAlternate) && isKeyDown {
            // Right Option released
            isKeyDown = false
            DispatchQueue.main.async { self.onKeyUp?() }
        }
    }

    deinit {
        unregister()
    }
}

private func hotkeyCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo = userInfo else { return Unmanaged.passRetained(event) }
    let manager = Unmanaged<HotkeyManager>.fromOpaque(userInfo).takeUnretainedValue()
    manager.handleEvent(event)
    return Unmanaged.passRetained(event)
}
