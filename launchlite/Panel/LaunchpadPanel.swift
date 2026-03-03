//
//  LaunchpadPanel.swift
//  launchlite
//
//  Created on 2026/3/2.
//
//  Launchpad 全螢幕面板，提供模糊背景、鍵盤及滑鼠事件處理。
//

import AppKit

/// A borderless, full-screen NSPanel used as the Launchpad overlay.
/// Floats above all windows with a blurred background effect.
class LaunchpadPanel: NSPanel {

    /// Called when the panel is dismissed (via Esc or clicking empty area).
    var onDismiss: (() -> Void)?

    /// Called when the user swipes horizontally to change pages.
    /// Parameter: +1 for next page (swipe left), -1 for previous page (swipe right).
    var onPageSwipe: ((Int) -> Void)?

    /// Accumulated horizontal scroll delta during a trackpad swipe gesture.
    private var scrollDeltaX: CGFloat = 0
    private var isTrackpadScrolling = false

    /// The visual effect view providing the blur background.
    private let blurView: NSVisualEffectView = {
        let view = NSVisualEffectView()
        view.material = .fullScreenUI
        view.appearance = NSAppearance(named: .darkAqua)
        view.blendingMode = .behindWindow
        view.state = .active
        view.autoresizingMask = [.width, .height]
        return view
    }()

    /// Dark overlay to simulate the native Launchpad dark tone.
    private let darkOverlay: NSView = {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.40).cgColor
        view.autoresizingMask = [.width, .height]
        return view
    }()

    /// 初始化全螢幕面板，設定無邊框樣式、模糊背景和暗色覆蓋層。
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        // Use a level above all standard windows (popUpMenu=101) but below
        // the system drag window level (kCGDraggingWindowLevel=500) so that
        // drag previews render above the panel during drag-and-drop.
        level = .init(rawValue: NSWindow.Level.popUpMenu.rawValue + 1)
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isMovableByWindowBackground = false
        titlebarAppearsTransparent = true
        titleVisibility = .hidden

        // Add blur background and dark overlay
        // Use contentView.bounds (local coordinates, origin 0,0) instead of
        // contentRect (screen absolute coordinates) to avoid offset on external displays.
        let localRect = contentView?.bounds ?? NSRect(origin: .zero, size: contentRect.size)
        blurView.frame = localRect
        contentView?.addSubview(blurView, positioned: .below, relativeTo: nil)
        darkOverlay.frame = localRect
        contentView?.addSubview(darkOverlay, positioned: .above, relativeTo: blurView)
    }

    /// 允許面板成為 Key Window 以接收鍵盤事件。
    override var canBecomeKey: Bool {
        return true
    }

    /// 允許面板成為 Main Window。
    override var canBecomeMain: Bool {
        return true
    }

    /// 處理鍵盤事件，按下 Esc 鍵時關閉面板。
    override func keyDown(with event: NSEvent) {
        // Esc key (keyCode 53) closes the panel
        if event.keyCode == 53 {
            dismiss()
        } else {
            super.keyDown(with: event)
        }
    }

    /// 處理滑鼠點擊事件，點擊空白區域時關閉面板。
    override func mouseDown(with event: NSEvent) {
        // Check if the click is on the background (not on a subview of the hosted content)
        guard let contentView = contentView else { return }

        let location = event.locationInWindow
        let hitView = contentView.hitTest(location)

        // If the hit view is the content view itself or the blur view,
        // the user clicked on empty area - close the panel
        if hitView === contentView || hitView === blurView || hitView === darkOverlay {
            dismiss()
        }
    }

    /// 處理觸控板滑動事件，累積水平滑動量超過閾值時切換頁面。
    override func scrollWheel(with event: NSEvent) {
        // Only handle trackpad scroll gestures (they report phase),
        // ignore discrete mouse scroll wheels.
        guard event.phase != [] || event.momentumPhase != [] else {
            super.scrollWheel(with: event)
            return
        }

        // Ignore momentum phase to prevent multiple page changes from inertia
        guard event.momentumPhase == [] else { return }

        switch event.phase {
        case .began:
            scrollDeltaX = 0
            isTrackpadScrolling = true

        case .changed:
            guard isTrackpadScrolling else { return }
            scrollDeltaX += event.scrollingDeltaX

        case .ended:
            guard isTrackpadScrolling else { return }
            scrollDeltaX += event.scrollingDeltaX

            let threshold: CGFloat = 50
            if scrollDeltaX > threshold {
                onPageSwipe?(-1)  // swipe right → previous page
            } else if scrollDeltaX < -threshold {
                onPageSwipe?(1)   // swipe left → next page
            }

            scrollDeltaX = 0
            isTrackpadScrolling = false

        case .cancelled:
            scrollDeltaX = 0
            isTrackpadScrolling = false

        default:
            break
        }
    }

    /// Dismisses the panel and notifies the delegate via onDismiss callback.
    func dismiss() {
        onDismiss?()
    }
}
