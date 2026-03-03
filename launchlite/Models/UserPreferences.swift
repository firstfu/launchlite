//
//  UserPreferences.swift
//  launchlite
//
//  Created by firstfu on 2026/3/2.
//
//  使用者偏好設定模型，儲存網格佈局、圖示大小、快捷鍵等設定。

import Foundation
import SwiftData

/// 擴展 Notification.Name，定義偏好設定變更通知名稱。
extension Notification.Name {
    /// 偏好設定已變更的通知名稱，用於通知各服務重新載入設定。
    static let preferencesDidChange = Notification.Name("LaunchLitePreferencesDidChange")
}

/// 使用者偏好設定模型，使用 SwiftData 持久化儲存網格佈局、圖示大小、快捷鍵等設定。
@Model
final class UserPreferences {
    var gridRows: Int
    var gridColumns: Int
    var iconSize: Double
    var hotkey: String
    var hotCornerEnabled: Bool
    var hotCornerPosition: Int
    var showInMenuBar: Bool

    /// 初始化使用者偏好設定，提供預設的網格大小、圖示大小及快捷鍵等值。
    init(
        gridRows: Int = 5,
        gridColumns: Int = 7,
        iconSize: Double = 120,
        hotkey: String = "⌥⌘L",
        hotCornerEnabled: Bool = false,
        hotCornerPosition: Int = 0,
        showInMenuBar: Bool = true
    ) {
        self.gridRows = gridRows
        self.gridColumns = gridColumns
        self.iconSize = iconSize
        self.hotkey = hotkey
        self.hotCornerEnabled = hotCornerEnabled
        self.hotCornerPosition = hotCornerPosition
        self.showInMenuBar = showInMenuBar
    }
}
