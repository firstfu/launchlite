//
//  AppFolder.swift
//  launchlite
//
//  Created by firstfu on 2026/3/2.
//
//  資料夾模型，使用 SwiftData 持久化儲存應用程式分組資訊。

import Foundation
import SwiftData

/// 資料夾模型，使用 SwiftData 儲存應用程式分組，包含名稱、位置和排序資訊。
@Model
final class AppFolder {
    @Attribute(.unique) var id: UUID
    var name: String
    var pageIndex: Int
    var gridRow: Int
    var gridColumn: Int
    var sortOrder: Int

    @Relationship(deleteRule: .nullify, inverse: \AppItem.folder)
    var items: [AppItem]

    /// 初始化資料夾，設定名稱、位置和排序順序等屬性。
    init(
        id: UUID = UUID(),
        name: String,
        pageIndex: Int = 0,
        gridRow: Int = 0,
        gridColumn: Int = 0,
        sortOrder: Int = 0,
        items: [AppItem] = []
    ) {
        self.id = id
        self.name = name
        self.pageIndex = pageIndex
        self.gridRow = gridRow
        self.gridColumn = gridColumn
        self.sortOrder = sortOrder
        self.items = items
    }
}
