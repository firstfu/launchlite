# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 專案概述

LaunchLite 是一個 macOS 原生桌面應用程式，使用 SwiftUI + SwiftData 建構。目前為基礎樣板，提供項目（Item）的新增、瀏覽與刪除功能，採用雙欄式 NavigationSplitView 介面。

- **語言**: Swift 5.0
- **平台**: macOS 26.2+
- **Bundle ID**: `com.firstfu.tw.launchlite`

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

## 架構

```
launchliteApp (@main)
  └── ModelContainer (SwiftData 持久化)
        └── ContentView
              ├── @Query items: [Item]  ← 自動響應式資料查詢
              └── NavigationSplitView
                    ├── Sidebar: 項目列表（支援刪除）
                    └── Detail: 項目詳情
```

**資料流**: `launchliteApp` 建立 `ModelContainer` 並注入至 SwiftUI 環境 → `ContentView` 透過 `@Query` 取得資料、透過 `@Environment(\.modelContext)` 執行 CRUD。

**關鍵模式**:
- `@Model` 定義 SwiftData 模型（`Item.swift`）
- `ModelContainer` 設定為磁碟持久化（非記憶體模式）
- SwiftUI Preview 使用 `inMemory: true` 的獨立容器
- 預設啟用 `MainActor` 隔離與 Approachable Concurrency

## 專案設定

- App Sandbox 與 Hardened Runtime 皆已啟用
- 自動程式碼簽署（Team: WY468E45SJ）
- 無外部第三方相依套件，僅使用 Apple 原生框架
