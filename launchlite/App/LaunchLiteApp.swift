//
//  LaunchLiteApp.swift
//  launchlite
//
//  Created by firstfu on 2026/3/2.
//
//  LaunchLite 應用程式入口點，定義選單列圖示、設定視窗及 AppDelegate 生命週期管理。

import Combine
import SwiftData
import SwiftUI

/// LaunchLite 應用程式入口點，提供選單列圖示和設定視窗。
@main
struct LaunchLiteApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // Menu bar icon
        MenuBarExtra("LaunchLite", systemImage: "square.grid.3x3") {
            Button("顯示 Launchpad") {
                appDelegate.appState.toggle()
            }
            .keyboardShortcut("l", modifiers: [.option, .command])

            Divider()

            SettingsLink {
                Text("設定...")
            }
            .keyboardShortcut(",", modifiers: .command)

            Divider()

            Button("結束 LaunchLite") {
                appDelegate.cleanup()
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }

        // Settings window
        Settings {
            SettingsView()
                .modelContainer(appDelegate.modelContainer)
        }
    }
}

// MARK: - AppDelegate

/// 應用程式委託，負責 SwiftData 容器初始化、視窗控制器設定及輸入服務管理。
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - SwiftData

    /// SwiftData 模型容器，註冊 AppItem、AppFolder 和 UserPreferences 模型。
    let modelContainer: ModelContainer = {
        let schema = Schema([
            AppItem.self,
            AppFolder.self,
            UserPreferences.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    // MARK: - State & Services

    /// 應用程式全域狀態實例，延遲初始化以確保依賴準備完成。
    private(set) lazy var appState: AppState = {
        AppState(
            appScanner: appScanner,
            modelContext: ModelContext(modelContainer)
        )
    }()

    private let appScanner = AppScanner()
    private var hotKeyManager: HotKeyManager?
    private var gestureMonitor: GestureMonitor?
    private var hotCornerMonitor: HotCornerMonitor?
    private var windowController: LaunchpadWindowController?
    private var visibilityCancellable: AnyCancellable?
    private var prefsCancellable: AnyCancellable?

    // MARK: - Lifecycle

    /// 應用程式啟動完成時呼叫，初始化視窗控制器、輸入服務並執行首次應用掃描。
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupWindowController()
        setupInputServices()
        observeVisibility()
        loadPreferences()
        observePreferenceChanges()

        // Initial app scan
        Task {
            await appState.refreshApps()
        }
    }

    /// 應用程式即將終止時呼叫，執行清理工作。
    func applicationWillTerminate(_ notification: Notification) {
        cleanup()
    }

    /// 停止所有輸入監聽服務（快捷鍵、手勢、螢幕角落）。
    func cleanup() {
        hotKeyManager?.stop()
        gestureMonitor?.stop()
        hotCornerMonitor?.stop()
    }

    // MARK: - Window Controller

    /// 建立並設定 LaunchpadWindowController，綁定關閉和翻頁回呼。
    private func setupWindowController() {
        let launchpadView = LaunchpadView()
            .environmentObject(appState)
            .environmentObject(appState.gridLayoutManager)
            .modelContainer(modelContainer)
        let wc = LaunchpadWindowController(rootView: launchpadView)
        wc.onDismiss = { [weak self] in
            self?.appState.hide()
        }
        wc.onScrollUpdate = { [weak self] delta in
            self?.appState.pageDragOffset = delta
        }
        wc.onScrollEnd = { [weak self] in
            self?.appState.snapToNearestPage()
        }
        windowController = wc
    }

    // MARK: - Input Services

    /// 初始化快捷鍵管理器、觸控板手勢監聽器及螢幕角落觸發器。
    private func setupInputServices() {
        hotKeyManager = HotKeyManager { [weak self] in
            self?.appState.toggle()
        }
        let started = hotKeyManager?.start() ?? false
        if !started {
            print("[LaunchLite] HotKeyManager failed to start - check accessibility permissions")
        }

        gestureMonitor = GestureMonitor { [weak self] in
            self?.appState.toggle()
        }
        gestureMonitor?.start()

        hotCornerMonitor = HotCornerMonitor { [weak self] in
            self?.appState.toggle()
        }
        // Hot corner starts disabled by default; enabled via preferences
    }

    // MARK: - Visibility

    /// 監聽 appState 的可見性變化，控制面板的顯示與隱藏。
    private func observeVisibility() {
        visibilityCancellable = appState.$isVisible
            .removeDuplicates()
            .sink { [weak self] visible in
                if visible {
                    self?.windowController?.showPanel()
                } else {
                    self?.windowController?.hidePanel()
                }
            }
    }

    // MARK: - Preferences

    /// 監聽偏好設定變更通知，自動重新載入設定。
    private func observePreferenceChanges() {
        prefsCancellable = NotificationCenter.default
            .publisher(for: .preferencesDidChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.loadPreferences()
            }
    }

    /// 從 SwiftData 載入使用者偏好設定，更新快捷鍵和螢幕角落設定。
    private func loadPreferences() {
        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<UserPreferences>()
        guard let prefs = try? context.fetch(descriptor).first else { return }

        hotKeyManager?.configure(hotkey: prefs.hotkey)
        let started = hotKeyManager?.start() ?? false
        if !started {
            print("[LaunchLite] HotKeyManager failed to start - check accessibility permissions")
        }

        if prefs.hotCornerEnabled {
            hotCornerMonitor?.configure(cornerPosition: prefs.hotCornerPosition)
            hotCornerMonitor?.start()
        } else {
            hotCornerMonitor?.stop()
        }
    }
}
