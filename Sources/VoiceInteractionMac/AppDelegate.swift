import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let controller = VoiceTypingController()
    private var statusItemController: StatusItemController?
    private var controlWindowController: ControlWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        statusItemController = StatusItemController(controller: controller)
        controlWindowController = ControlWindowController(controller: controller)
        controlWindowController?.show()
        controller.requestPermissions()
        NSApp.activate(ignoringOtherApps: true)
    }
}
