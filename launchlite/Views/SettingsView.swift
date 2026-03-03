//
//  SettingsView.swift
//  launchlite
//
//  Created on 2026/3/2.
//
//  設定視圖，提供外觀、快捷鍵和一般設定的分頁介面。

import ServiceManagement
import SwiftData
import SwiftUI

/// The app settings view, displayed in a native macOS Settings window.
/// Provides controls for appearance, shortcuts, and general preferences.
struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allPreferences: [UserPreferences]

    /// 取得目前的使用者偏好設定，若不存在則建立新的預設設定。
    private var prefs: UserPreferences {
        if let existing = allPreferences.first {
            return existing
        }
        let newPrefs = UserPreferences()
        modelContext.insert(newPrefs)
        return newPrefs
    }

    /// 建立設定視窗，包含外觀、快捷鍵和一般三個分頁。
    var body: some View {
        TabView {
            AppearanceTab(prefs: prefs)
                .tabItem {
                    Label("外觀", systemImage: "paintbrush")
                }

            ShortcutsTab(prefs: prefs)
                .tabItem {
                    Label("快捷鍵", systemImage: "keyboard")
                }

            GeneralTab(prefs: prefs, modelContext: modelContext)
                .tabItem {
                    Label("一般", systemImage: "gear")
                }
        }
        .frame(width: 480, height: 340)
        .onAppear {
            NSApp.activate(ignoringOtherApps: true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NSApp.keyWindow?.level = .floating
                NSApp.keyWindow?.orderFrontRegardless()
            }
        }
    }
}

// MARK: - Appearance Tab

/// 外觀設定分頁，提供網格列數、欄數和圖示大小的調整控制。
private struct AppearanceTab: View {
    @Bindable var prefs: UserPreferences

    /// 建立外觀設定表單，包含格狀排列和圖示大小的滑桿控制。
    var body: some View {
        Form {
            Section("格狀排列") {
                HStack {
                    Text("列數")
                    Slider(
                        value: Binding(
                            get: { Double(prefs.gridRows) },
                            set: { prefs.gridRows = Int($0) }
                        ),
                        in: 3...8,
                        step: 1
                    )
                    Text("\(prefs.gridRows)")
                        .monospacedDigit()
                        .frame(width: 24, alignment: .trailing)
                }

                HStack {
                    Text("欄數")
                    Slider(
                        value: Binding(
                            get: { Double(prefs.gridColumns) },
                            set: { prefs.gridColumns = Int($0) }
                        ),
                        in: 5...10,
                        step: 1
                    )
                    Text("\(prefs.gridColumns)")
                        .monospacedDigit()
                        .frame(width: 24, alignment: .trailing)
                }
            }

            Section("圖示大小") {
                HStack {
                    Text("大小")
                    Slider(value: $prefs.iconSize, in: 48...160, step: 4)
                    Text("\(Int(prefs.iconSize)) pt")
                        .monospacedDigit()
                        .frame(width: 44, alignment: .trailing)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Shortcuts Tab

/// 快捷鍵設定分頁，提供鍵盤快捷鍵、觸控板手勢和螢幕角落觸發的設定。
private struct ShortcutsTab: View {
    @Bindable var prefs: UserPreferences
    @State private var isRecordingHotkey = false
    @AppStorage("gestureEnabled") private var gestureEnabled = true

    /// 建立快捷鍵設定表單，包含快捷鍵錄製、手勢開關和熱角設定。
    var body: some View {
        Form {
            Section("鍵盤快捷鍵") {
                HStack {
                    Text("啟動快捷鍵")
                    Spacer()
                    HotKeyRecorderButton(
                        hotkey: $prefs.hotkey,
                        isRecording: $isRecordingHotkey
                    )
                }
            }

            Section("觸控板手勢") {
                Toggle("啟用捏合手勢觸發", isOn: $gestureEnabled)
            }

            Section("螢幕角落觸發") {
                Toggle("啟用熱角", isOn: $prefs.hotCornerEnabled)

                if prefs.hotCornerEnabled {
                    Picker("位置", selection: $prefs.hotCornerPosition) {
                        Text("左上角").tag(0)
                        Text("右上角").tag(1)
                        Text("左下角").tag(2)
                        Text("右下角").tag(3)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onChange(of: prefs.hotkey) { _, _ in
            NotificationCenter.default.post(name: .preferencesDidChange, object: nil)
        }
        .onChange(of: prefs.hotCornerEnabled) { _, _ in
            NotificationCenter.default.post(name: .preferencesDidChange, object: nil)
        }
        .onChange(of: prefs.hotCornerPosition) { _, _ in
            NotificationCenter.default.post(name: .preferencesDidChange, object: nil)
        }
    }
}

// MARK: - General Tab

/// 一般設定分頁，提供選單列顯示、開機啟動和佈局重設等功能。
private struct GeneralTab: View {
    @Bindable var prefs: UserPreferences
    let modelContext: ModelContext
    @State private var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled
    @State private var showResetConfirmation = false
    @State private var showLoginError = false
    @State private var loginErrorMessage = ""

    /// 建立一般設定表單，包含選單列、啟動和重設區塊。
    var body: some View {
        Form {
            Section("選單列") {
                Toggle("在選單列中顯示", isOn: $prefs.showInMenuBar)
            }

            Section("啟動") {
                Toggle("登入時自動啟動", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        setLaunchAtLogin(newValue)
                    }
            }

            Section("重設") {
                Button("重設佈局", role: .destructive) {
                    showResetConfirmation = true
                }
                .confirmationDialog(
                    "確定要重設所有配置嗎？此操作無法復原。",
                    isPresented: $showResetConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("重設", role: .destructive) {
                        resetLayout()
                    }
                    Button("取消", role: .cancel) {}
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
        .alert("開機啟動設定失敗", isPresented: $showLoginError) {
            Button("確定") {}
        } message: {
            Text(loginErrorMessage)
        }
    }

    /// 設定或取消應用程式的登入時自動啟動，透過 SMAppService 註冊或註銷。
    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("[LaunchLite] SMAppService error: \(error)")
            launchAtLogin = SMAppService.mainApp.status == .enabled
            loginErrorMessage = "無法設定開機啟動：\(error.localizedDescription)"
            showLoginError = true
        }
    }

    /// 重設所有佈局配置至預設值，清除所有資料夾和自訂排序。
    private func resetLayout() {
        let descriptor = FetchDescriptor<AppItem>()
        guard let items = try? modelContext.fetch(descriptor) else { return }
        for item in items {
            item.pageIndex = 0
            item.gridRow = 0
            item.gridColumn = 0
            item.folderID = nil
            item.folder = nil
        }

        let folderDescriptor = FetchDescriptor<AppFolder>()
        if let folders = try? modelContext.fetch(folderDescriptor) {
            for folder in folders {
                modelContext.delete(folder)
            }
        }

        prefs.gridRows = 5
        prefs.gridColumns = 7
        prefs.iconSize = 120
        prefs.hotkey = "⌥⌘L"
        prefs.hotCornerEnabled = false
        prefs.hotCornerPosition = 0
        prefs.showInMenuBar = true

        try? modelContext.save()
    }
}

// MARK: - Hotkey Recorder

/// 快捷鍵錄製按鈕，點擊後進入錄製模式等待使用者按下新的快捷鍵組合。
private struct HotKeyRecorderButton: View {
    @Binding var hotkey: String
    @Binding var isRecording: Bool

    /// 建立快捷鍵錄製按鈕，錄製中顯示提示文字和強調邊框。
    var body: some View {
        Button {
            isRecording.toggle()
        } label: {
            Text(isRecording ? "請按下快捷鍵..." : hotkey)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .frame(minWidth: 110)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
        }
        .buttonStyle(.bordered)
        .overlay(
            Group {
                if isRecording {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.accentColor, lineWidth: 2)
                        .shadow(color: Color.accentColor.opacity(0.3), radius: 4)
                }
            }
        )
        .animation(.easeOut(duration: 0.2), value: isRecording)
        .background {
            if isRecording {
                HotKeyRecorderRepresentable(hotkey: $hotkey, isRecording: $isRecording)
            }
        }
    }
}

/// NSViewRepresentable that captures keyboard events for hotkey recording.
private struct HotKeyRecorderRepresentable: NSViewRepresentable {
    @Binding var hotkey: String
    @Binding var isRecording: Bool

    /// 建立鍵盤事件捕捉視圖並設定錄製和取消的回呼。
    func makeNSView(context: Context) -> HotKeyCapturingView {
        let view = HotKeyCapturingView()
        view.onKeyRecorded = { recorded in
            hotkey = recorded
            isRecording = false
        }
        view.onCancel = {
            isRecording = false
        }
        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }
        return view
    }

    /// 更新視圖（目前無需更新操作）。
    func updateNSView(_ nsView: HotKeyCapturingView, context: Context) {}
}

/// NSView subclass that intercepts key events to record a hotkey combination.
final class HotKeyCapturingView: NSView {
    var onKeyRecorded: ((String) -> Void)?
    var onCancel: (() -> Void)?

    /// 宣告此視圖可接收鍵盤焦點。
    override var acceptsFirstResponder: Bool { true }

    /// 處理鍵盤事件，解析修飾鍵和按鍵組合後回傳快捷鍵字串。
    override func keyDown(with event: NSEvent) {
        // Escape cancels recording
        if event.keyCode == 53 {
            onCancel?()
            return
        }

        var parts: [String] = []
        let flags = event.modifierFlags

        if flags.contains(.control) { parts.append("⌃") }
        if flags.contains(.option) { parts.append("⌥") }
        if flags.contains(.shift) { parts.append("⇧") }
        if flags.contains(.command) { parts.append("⌘") }

        // At least one modifier is required
        guard !parts.isEmpty else { return }

        if let chars = event.charactersIgnoringModifiers?.uppercased(), !chars.isEmpty {
            let char = chars.first!
            if char.isLetter || char.isNumber {
                parts.append(String(char))
                onKeyRecorded?(parts.joined())
            }
        }
    }
}
