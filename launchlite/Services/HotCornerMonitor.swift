//
//  HotCornerMonitor.swift
//  launchlite
//
//  Created by firstfu on 2026/3/2.
//
//  螢幕角落觸發器，偵測滑鼠在螢幕角落停留以觸發 Launchpad 顯示。

import Cocoa

/// 螢幕角落觸發器，監聽滑鼠移動事件，當滑鼠在指定角落停留超過設定時間時觸發回呼。
@MainActor
final class HotCornerMonitor {
    /// 螢幕四個角落的列舉定義。
    enum Corner: Int, CaseIterable, Sendable {
        case topLeft = 0
        case topRight = 1
        case bottomLeft = 2
        case bottomRight = 3
    }

    private var monitor: Any?
    private let onTrigger: () -> Void

    /// Which corner is active.
    var activeCorner: Corner = .topLeft

    /// Size of the corner detection zone in points.
    private let cornerSize: CGFloat = 5

    /// How long the mouse must stay in the corner before triggering (seconds).
    private let dwellTime: TimeInterval = 0.5

    /// Minimum interval between triggers to prevent rapid re-firing.
    private let cooldownInterval: TimeInterval = 2.0

    private var cornerEntryTime: Date?
    private var dwellTimer: Timer?
    private var lastTriggerTime: Date = .distantPast

    /// 初始化螢幕角落監聽器，設定觸發時的回呼函數。
    init(onTrigger: @escaping () -> Void) {
        self.onTrigger = onTrigger
    }

    deinit {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
        }
        dwellTimer?.invalidate()
    }

    // MARK: - Configuration

    /// 設定要監聽的螢幕角落。
    func configure(corner: Corner) {
        self.activeCorner = corner
    }

    /// 透過角落位置整數值設定要監聽的螢幕角落。
    func configure(cornerPosition: Int) {
        if let corner = Corner(rawValue: cornerPosition) {
            self.activeCorner = corner
        }
    }

    // MARK: - Start / Stop

    /// 開始監聽全域滑鼠移動事件。
    func start() {
        guard monitor == nil else { return }

        monitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            Task { @MainActor in
                self?.handleMouseMoved(event)
            }
        }
    }

    /// 停止監聽滑鼠移動事件並清除相關計時器。
    func stop() {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
        cancelDwellTimer()
        cornerEntryTime = nil
    }

    // MARK: - Event Handling

    /// 處理滑鼠移動事件，判斷滑鼠是否進入或離開指定角落。
    private func handleMouseMoved(_ event: NSEvent) {
        let mouseLocation = NSEvent.mouseLocation

        if isInActiveCorner(mouseLocation) {
            if cornerEntryTime == nil {
                cornerEntryTime = Date()
                startDwellTimer()
            }
        } else {
            cancelDwellTimer()
            cornerEntryTime = nil
        }
    }

    /// 判斷指定座標是否位於目前啟用的螢幕角落偵測區域內。
    private func isInActiveCorner(_ point: NSPoint) -> Bool {
        guard let screen = NSScreen.main else { return false }
        let frame = screen.frame

        switch activeCorner {
        case .topLeft:
            return point.x <= frame.minX + cornerSize
                && point.y >= frame.maxY - cornerSize
        case .topRight:
            return point.x >= frame.maxX - cornerSize
                && point.y >= frame.maxY - cornerSize
        case .bottomLeft:
            return point.x <= frame.minX + cornerSize
                && point.y <= frame.minY + cornerSize
        case .bottomRight:
            return point.x >= frame.maxX - cornerSize
                && point.y <= frame.minY + cornerSize
        }
    }

    // MARK: - Dwell Timer

    /// 啟動停留計時器，在滑鼠進入角落時開始計時。
    private func startDwellTimer() {
        cancelDwellTimer()
        dwellTimer = Timer.scheduledTimer(withTimeInterval: dwellTime, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.dwellTimerFired()
            }
        }
    }

    /// 取消停留計時器。
    private func cancelDwellTimer() {
        dwellTimer?.invalidate()
        dwellTimer = nil
    }

    /// 停留計時器觸發時呼叫，驗證滑鼠仍在角落並檢查冷卻時間後執行觸發。
    private func dwellTimerFired() {
        // Verify mouse is still in the corner
        let mouseLocation = NSEvent.mouseLocation
        guard isInActiveCorner(mouseLocation) else {
            cornerEntryTime = nil
            return
        }

        // Check cooldown
        let now = Date()
        guard now.timeIntervalSince(lastTriggerTime) >= cooldownInterval else {
            cornerEntryTime = nil
            return
        }

        lastTriggerTime = now
        cornerEntryTime = nil
        onTrigger()
    }
}
