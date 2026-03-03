# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 專案概述

LaunchLite 是一個 macOS 原生 Launchpad 替代應用程式，提供全螢幕 iOS 風格的應用程式啟動器。使用 NSPanel + SwiftUI 混合架構，SwiftData 持久化，Combine 響應式資料流。

- **語言**: Swift 6.0（Strict Concurrency）
- **平台**: macOS 26.2+
- **Bundle ID**: `com.firstfu.tw.launchlite`
- **執行時需要**: 輔助使用（Accessibility）權限（CGEvent tap 全域快捷鍵）

## 建置與測試指令

```bash
# 建置（Debug）
xcodebuild -scheme launchlite -configuration Debug build

# 建置（Release）
xcodebuild -scheme launchlite -configuration Release build

# 執行所有測試
xcodebuild test -scheme launchlite -destination 'platform=macOS'

# 僅執行單元測試
xcodebuild test -scheme launchlite -destination 'platform=macOS' -only-testing:launchliteTests

# 僅執行 UI 測試
xcodebuild test -scheme launchlite -destination 'platform=macOS' -only-testing:launchliteUITests
```

或在 Xcode 中開啟 `launchlite.xcodeproj`，按 `⌘R` 執行。

## 架構

### 啟動與視窗層級

```
LaunchLiteApp (@main, MenuBarExtra)
  └── AppDelegate (NSApplicationDelegateAdaptor)
        ├── ModelContainer (SwiftData: AppItem, AppFolder, UserPreferences)
        ├── AppState (ObservableObject — 全域狀態中樞)
        ├── LaunchpadWindowController → LaunchpadPanel (NSPanel, 全螢幕模糊背景)
        │     └── NSHostingView → LaunchpadView (SwiftUI)
        │           ├── SearchBarView
        │           ├── AppGridView (格狀 + 拖放)
        │           │   ├── AppIconView
        │           │   └── FolderView
        │           └── PageIndicatorView
        └── 輸入服務
              ├── HotKeyManager (CGEvent tap, 預設 ⌥⌘L)
              ├── GestureMonitor (觸控板捏合)
              └── HotCornerMonitor (螢幕角落)
```

### 核心資料流

1. **AppScanner** 掃描 `/Applications`、`/System/Applications`、`~/Applications`，透過 `DispatchSource` 監聽檔案系統變更自動更新
2. **AppState** 訂閱 `AppScanner.$apps`，驅動搜尋過濾（`$searchText.combineLatest($installedApps)`）並同步至 GridLayoutManager
3. **GridLayoutManager** 合併 `ScannedApp`（掃描結果）與 SwiftData 持久化的排序/資料夾資訊，輸出統一的 `[GridSlotItem]`（`.app` / `.folder`）
4. **AppState.$isVisible** → AppDelegate 控制 `LaunchpadWindowController.showPanel()/hidePanel()`

### 關鍵設計決策

- **NSPanel 而非 SwiftUI Window**: 需要 `borderless + nonactivatingPanel` 全螢幕覆蓋，`NSVisualEffectView` 模糊背景，自訂 `level` 確保浮在最上層但低於拖曳視窗層級
- **GridSlotItem enum**: 統一 `ScannedApp` 和 `AppFolder` 為單一格狀項目類型，簡化渲染與拖放邏輯
- **拖放使用自訂 UTType**: `com.firstfu.tw.launchlite.griditem`（定義於 Info.plist）
- **偏好設定變更通知**: `Notification.Name.preferencesDidChange` 通知 AppDelegate 重新載入 HotKey/HotCorner 設定
- **所有核心類別使用 `@MainActor`**: AppState、GridLayoutManager、AppScanner、HotKeyManager 等

### SwiftData 模型

| 模型 | 用途 |
|------|------|
| `AppItem` | 應用程式持久化排序（bundleID 唯一約束）、資料夾關聯 |
| `AppFolder` | 資料夾分組，`@Relationship` 反向連結 AppItem |
| `UserPreferences` | 網格行列數、圖示大小、快捷鍵、熱角設定（單例模式使用） |

## 專案設定

- App Sandbox 與 Hardened Runtime 已啟用
- 自動程式碼簽署（Team: WY468E45SJ）
- 無外部第三方相依套件，僅使用 Apple 原生框架（SwiftUI、SwiftData、AppKit、Combine、CoreGraphics）
