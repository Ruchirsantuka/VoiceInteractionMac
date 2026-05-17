import AppKit
import Combine
import SwiftUI

@MainActor
final class StatusItemController {
    private let controller: VoiceTypingController
    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private let monitor: EventMonitor
    private var cancellables: Set<AnyCancellable> = []

    init(controller: VoiceTypingController) {
        self.controller = controller
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.popover = NSPopover()
        self.monitor = EventMonitor(mask: [.leftMouseDown, .rightMouseDown])
        self.popover.behavior = .transient
        self.popover.contentSize = NSSize(width: 340, height: 280)
        self.popover.contentViewController = NSHostingController(rootView: ContentView(controller: controller))
        self.monitor.handler = { [weak self] event in
            self?.handleGlobalMouse(event)
        }

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(togglePopover(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        bindState()
        updateButtonAppearance()
    }

    @objc
    private func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem.button else {
            return
        }

        if popover.isShown {
            closePopover(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            monitor.start()
        }
    }

    @objc
    private func closePopover(_ sender: AnyObject?) {
        popover.performClose(sender)
        monitor.stop()
    }

    private func handleGlobalMouse(_ event: NSEvent) {
        guard popover.isShown else {
            return
        }

        if let button = statusItem.button, event.window == button.window {
            return
        }
        closePopover(nil)
    }

    private func bindState() {
        controller.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] in
                self?.updateButtonAppearance()
            }
            .store(in: &cancellables)
    }

    private func updateButtonAppearance() {
        guard let button = statusItem.button else {
            return
        }

        button.image = NSImage(systemSymbolName: controller.statusSymbolName, accessibilityDescription: controller.statusTitle)
        button.imagePosition = .imageOnly
        button.toolTip = "Voice Interaction - \(controller.statusTitle)"
    }
}

@MainActor
final class EventMonitor {
    private let mask: NSEvent.EventTypeMask
    var handler: ((NSEvent) -> Void)?
    private var monitor: Any?

    init(mask: NSEvent.EventTypeMask) {
        self.mask = mask
    }

    func start() {
        guard monitor == nil else {
            return
        }
        monitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
            self?.handler?(event)
        }
    }

    func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
}
