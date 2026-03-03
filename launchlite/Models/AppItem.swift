//
//  AppItem.swift
//  launchlite
//
//  Created by firstfu on 2026/3/2.
//
//  應用程式項目模型，使用 SwiftData 持久化儲存應用程式的排序和分組資訊。

import Foundation
import SwiftData

/// 應用程式項目模型，儲存 Bundle ID、名稱、圖示資料、網格位置及所屬資料夾等資訊。
@Model
final class AppItem {
    #Unique<AppItem>([\.bundleID])

    var bundleID: String
    var name: String
    var iconData: Data?
    var pageIndex: Int
    var gridRow: Int
    var gridColumn: Int
    var sortOrder: Int
    var folderID: String?
    var lastUsed: Date?

    var folder: AppFolder?

    /// 初始化應用程式項目，設定 Bundle ID、名稱及各項網格佈局屬性。
    init(
        bundleID: String,
        name: String,
        iconData: Data? = nil,
        pageIndex: Int = 0,
        gridRow: Int = 0,
        gridColumn: Int = 0,
        sortOrder: Int = 0,
        folderID: String? = nil,
        lastUsed: Date? = nil
    ) {
        self.bundleID = bundleID
        self.name = name
        self.iconData = iconData
        self.pageIndex = pageIndex
        self.gridRow = gridRow
        self.gridColumn = gridColumn
        self.sortOrder = sortOrder
        self.folderID = folderID
        self.lastUsed = lastUsed
    }
}
