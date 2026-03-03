//
//  GridSlotItem.swift
//  launchlite
//
//  Created on 2026/3/2.
//
//  網格插槽項目列舉，作為應用程式網格中單一格位的統一視圖模型。

import Foundation

/// A unified view-model representing a single cell in the app grid.
/// Can be either a standalone app or a folder containing multiple apps.
enum GridSlotItem: Identifiable {
    case app(ScannedApp)
    case folder(AppFolder)

    /// 根據項目類型產生唯一識別碼，格式為 "app-{bundleID}" 或 "folder-{uuid}"。
    var id: String {
        switch self {
        case .app(let scannedApp):
            return "app-\(scannedApp.bundleID)"
        case .folder(let folder):
            return "folder-\(folder.id.uuidString)"
        }
    }

    /// 取得項目的顯示名稱，應用程式回傳 app 名稱，資料夾回傳資料夾名稱。
    var name: String {
        switch self {
        case .app(let scannedApp):
            return scannedApp.name
        case .folder(let folder):
            return folder.name
        }
    }

    /// 取得項目的排序順序，資料夾回傳自身排序值，應用程式由 GridLayoutManager 解析。
    var sortOrder: Int {
        switch self {
        case .app:
            // Resolved via GridLayoutManager lookup
            return 0
        case .folder(let folder):
            return folder.sortOrder
        }
    }

    /// The drag identifier string used for NSItemProvider.
    var dragID: String { id }
}
