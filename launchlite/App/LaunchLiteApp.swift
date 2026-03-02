//
//  LaunchLiteApp.swift
//  launchlite
//
//  Created by firstfu on 2026/3/2.
//

import Combine
import SwiftData
import SwiftUI

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

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - SwiftData

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

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupWindowController()
        setupInputServices()
        observeVisibility()
        loadPreferences()

        // Initial app scan
        Task {
            await appState.refreshApps()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        cleanup()
    }

    func cleanup() {
        hotKeyManager?.stop()
        gestureMonitor?.stop()
        hotCornerMonitor?.stop()
    }

    // MARK: - Window Controller

    private func setupWindowController() {
        let launchpadView = LaunchpadView()
            .environmentObject(appState)
            .modelContainer(modelContainer)
        let wc = LaunchpadWindowController(rootView: launchpadView)
        wc.onDismiss = { [weak self] in
            self?.appState.hide()
        }
        windowController = wc
    }

    // MARK: - Input Services

    private func setupInputServices() {
        hotKeyManager = HotKeyManager { [weak self] in
            self?.appState.toggle()
        }
        _ = hotKeyManager?.start()

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

    private func loadPreferences() {
        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<UserPreferences>()
        guard let prefs = try? context.fetch(descriptor).first else { return }

        hotKeyManager?.configure(hotkey: prefs.hotkey)

        if prefs.hotCornerEnabled {
            hotCornerMonitor?.configure(cornerPosition: prefs.hotCornerPosition)
            hotCornerMonitor?.start()
        }
    }
}
