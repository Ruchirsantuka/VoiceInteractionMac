import AppKit
import SwiftUI

@MainActor
final class ControlWindowController {
    private let window: NSWindow

    init(controller: VoiceTypingController) {
        let hostingController = NSHostingController(rootView: ContentView(controller: controller))
        self.window = NSWindow(contentViewController: hostingController)
        window.title = "Voice Interaction"
        window.setContentSize(NSSize(width: 360, height: 320))
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.center()
    }

    func show() {
        window.makeKeyAndOrderFront(nil)
    }
}
