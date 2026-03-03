//
//  GestureMonitor.swift
//  launchlite
//
//  Created by firstfu on 2026/3/2.
//
//  觸控板手勢監聽器，偵測捏合縮小手勢以觸發 Launchpad 顯示。
//

import Cocoa

/// 觸控板手勢監聽器，監聽全域捏合縮小（magnify）手勢來觸發 Launchpad。
@MainActor
final class GestureMonitor {
    private var monitor: Any?
    private let onTrigger: () -> Void

    /// Magnification threshold: a pinch-in that exceeds this negative value triggers the action.
    private let magnificationThreshold: CGFloat = -0.3

    /// Minimum interval between triggers to prevent rapid re-firing.
    private let debounceInterval: TimeInterval = 1.0
    private var lastTriggerTime: Date = .distantPast

    /// Tracks cumulative magnification during a single gesture sequence.
    private var cumulativeMagnification: CGFloat = 0
    private var gestureInProgress: Bool = false

    /// 初始化手勢監聽器，設定觸發時的回呼函數。
    init(onTrigger: @escaping () -> Void) {
        self.onTrigger = onTrigger
    }

    deinit {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    // MARK: - Start / Stop

    /// 開始監聽全域觸控板捏合手勢事件。
    func start() {
        guard monitor == nil else { return }

        monitor = NSEvent.addGlobalMonitorForEvents(matching: .magnify) { [weak self] event in
            Task { @MainActor in
                self?.handleMagnifyEvent(event)
            }
        }
    }

    /// 停止監聽觸控板手勢事件並重設手勢狀態。
    func stop() {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
        resetGestureState()
    }

    // MARK: - Event Handling

    /// 處理觸控板放大/縮小事件，追蹤手勢的開始、變化及結束階段。
    private func handleMagnifyEvent(_ event: NSEvent) {
        switch event.phase {
        case .began:
            gestureInProgress = true
            cumulativeMagnification = 0

        case .changed:
            guard gestureInProgress else { return }
            cumulativeMagnification += event.magnification

        case .ended, .cancelled:
            guard gestureInProgress else { return }
            cumulativeMagnification += event.magnification
            evaluateGesture()
            resetGestureState()

        default:
            // For trackpads that don't report phase, use single-event detection
            if !gestureInProgress {
                cumulativeMagnification = event.magnification
                evaluateGesture()
                cumulativeMagnification = 0
            }
        }
    }

    /// 評估累積的捏合量是否超過閾值，並在滿足防抖條件時觸發回呼。
    private func evaluateGesture() {
        guard cumulativeMagnification < magnificationThreshold else { return }

        let now = Date()
        guard now.timeIntervalSince(lastTriggerTime) >= debounceInterval else { return }

        lastTriggerTime = now
        onTrigger()
    }

    /// 重設手勢追蹤狀態（進行中標記和累積量）。
    private func resetGestureState() {
        gestureInProgress = false
        cumulativeMagnification = 0
    }
}
