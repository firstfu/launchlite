//
//  LaunchpadWindowController.swift
//  launchlite
//
//  Created on 2026/3/2.
//

import AppKit
import SwiftUI

/// Manages the LaunchpadPanel lifecycle, including show/hide animations
/// and multi-monitor support.
class LaunchpadWindowController: NSWindowController {

    /// Whether the panel is currently visible.
    private(set) var isPanelVisible = false

    /// Called when the panel is dismissed by user interaction (Esc or click on empty area).
    var onDismiss: (() -> Void)?

    /// Creates a new window controller with the given SwiftUI root view.
    convenience init<Content: View>(rootView: Content) {
        let screen = Self.screenWithMouse() ?? NSScreen.main ?? NSScreen.screens.first!
        let panel = LaunchpadPanel(contentRect: screen.frame)

        self.init(window: panel)

        let hostingView = NSHostingView(rootView: rootView)
        hostingView.frame = panel.contentView?.bounds ?? screen.frame
        hostingView.autoresizingMask = [.width, .height]
        panel.contentView?.addSubview(hostingView)

        // Wire panel dismiss to controller
        panel.onDismiss = { [weak self] in
            self?.hidePanel()
            self?.onDismiss?()
        }
    }

    /// Shows the panel with a fade-in and scale animation on the screen where the mouse is.
    func showPanel() {
        guard let panel = window as? LaunchpadPanel else { return }

        // Position on screen where mouse currently is
        let screen = Self.screenWithMouse() ?? NSScreen.main ?? NSScreen.screens.first!
        panel.setFrame(screen.frame, display: true)

        // Set initial state for animation
        panel.alphaValue = 0.0

        // Apply initial scale transform via the content view layer
        if let contentView = panel.contentView {
            contentView.wantsLayer = true
            contentView.layer?.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            contentView.layer?.position = CGPoint(
                x: contentView.bounds.midX,
                y: contentView.bounds.midY
            )
            contentView.layer?.setAffineTransform(CGAffineTransform(scaleX: 1.1, y: 1.1))
        }

        panel.makeKeyAndOrderFront(nil)
        isPanelVisible = true

        // Animate in: fade + scale
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1.0
            if let contentView = panel.contentView {
                contentView.layer?.setAffineTransform(.identity)
            }
        }
    }

    /// Hides the panel with a fade-out and scale animation.
    func hidePanel() {
        guard let panel = window as? LaunchpadPanel, isPanelVisible else { return }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0.0
            if let contentView = panel.contentView {
                contentView.wantsLayer = true
                contentView.layer?.setAffineTransform(CGAffineTransform(scaleX: 0.95, y: 0.95))
            }
        } completionHandler: { [weak self] in
            panel.orderOut(nil)
            panel.alphaValue = 1.0
            panel.contentView?.layer?.setAffineTransform(.identity)
            self?.isPanelVisible = false
        }
    }

    /// Toggles the panel visibility.
    func togglePanel() {
        if isPanelVisible {
            hidePanel()
        } else {
            showPanel()
        }
    }

    // MARK: - Multi-monitor Support

    /// Returns the NSScreen that currently contains the mouse cursor.
    static func screenWithMouse() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first { screen in
            NSMouseInRect(mouseLocation, screen.frame, false)
        }
    }
}
