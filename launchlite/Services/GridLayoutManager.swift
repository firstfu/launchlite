//
//  GridLayoutManager.swift
//  launchlite
//
//  Created on 2026/3/2.
//
//  網格佈局管理器，負責合併掃描的應用程式與 SwiftData 持久化的排序和資料夾資訊。

import AppKit
import Combine
import Foundation
import SwiftData

/// Manages the grid layout by merging ScannedApp data with SwiftData persisted
/// sort order and folder membership. Provides a unified `[GridSlotItem]` for rendering.
@MainActor
final class GridLayoutManager: ObservableObject {

    @Published private(set) var allItems: [GridSlotItem] = []

    /// The ID of the item currently being dragged, or nil if no drag is active.
    @Published var draggedItemID: String?

    /// The folder currently expanded as an overlay. Setting this replaces the old popover approach
    /// so that drag-and-drop stays within the same window (popover creates a separate NSWindow).
    @Published var expandedFolder: AppFolder?

    private let modelContext: ModelContext
    private var lastScannedApps: [ScannedApp] = []
    private var dragCheckTimer: Timer?

    /// 初始化網格佈局管理器，注入 SwiftData ModelContext。
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Drag State

    /// Called when a drag begins. Installs a timer to detect when the mouse
    /// button is released (covering the case where the system drag is cancelled
    /// without calling `performDrop`).
    func startDrag(itemID: String) {
        draggedItemID = itemID
        startDragCheckTimer()
    }

    /// Called when a drag ends (either via `performDrop` or timer-based detection).
    func endDrag() {
        draggedItemID = nil
        stopDragCheckTimer()
    }

    /// 啟動拖曳檢查計時器，偵測滑鼠釋放以結束拖曳狀態。
    private func startDragCheckTimer() {
        stopDragCheckTimer()
        // Use .common run loop mode so the timer fires during event-tracking
        // (the run loop mode active during system drag sessions).
        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            if NSEvent.pressedMouseButtons == 0 {
                self?.endDrag()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        dragCheckTimer = timer
    }

    /// 停止並清除拖曳檢查計時器。
    private func stopDragCheckTimer() {
        dragCheckTimer?.invalidate()
        dragCheckTimer = nil
    }

    // MARK: - Sync

    /// Merges scanned apps with persisted SwiftData state.
    /// - First launch: creates AppItem for each scanned app with alphabetical sortOrder.
    /// - Subsequent launches: preserves user-customized order; new apps go to the end.
    func syncWithScannedApps(_ scannedApps: [ScannedApp]) {
        lastScannedApps = scannedApps
        let existingItems = fetchAllAppItems()
        let existingByBundleID = Dictionary(uniqueKeysWithValues: existingItems.map { ($0.bundleID, $0) })

        var maxSortOrder = existingItems.map(\.sortOrder).max() ?? -1

        // Also account for folder sortOrders
        let folders = fetchAllFolders()
        let maxFolderSort = folders.map(\.sortOrder).max() ?? -1
        maxSortOrder = max(maxSortOrder, maxFolderSort)

        var hasChanges = false

        for scannedApp in scannedApps {
            if existingByBundleID[scannedApp.bundleID] == nil {
                // New app — assign next sortOrder
                maxSortOrder += 1
                let appItem = AppItem(
                    bundleID: scannedApp.bundleID,
                    name: scannedApp.name,
                    sortOrder: maxSortOrder
                )
                modelContext.insert(appItem)
                hasChanges = true
            } else {
                // Update name if changed
                let item = existingByBundleID[scannedApp.bundleID]!
                if item.name != scannedApp.name {
                    item.name = scannedApp.name
                    hasChanges = true
                }
            }
        }

        // Remove AppItems for uninstalled apps (not in scannedApps)
        let scannedBundleIDs = Set(scannedApps.map(\.bundleID))
        for item in existingItems where !scannedBundleIDs.contains(item.bundleID) {
            modelContext.delete(item)
            hasChanges = true
        }

        if hasChanges {
            try? modelContext.save()
        }

        rebuildSlotItems(scannedApps: scannedApps)
    }

    // MARK: - Rebuild Slot Items

    /// Rebuilds the unified `[GridSlotItem]` array from current SwiftData state.
    private func rebuildSlotItems(scannedApps: [ScannedApp]) {
        let scannedByBundleID = Dictionary(uniqueKeysWithValues: scannedApps.map { ($0.bundleID, $0) })
        let appItems = fetchAllAppItems()
        let folders = fetchAllFolders()

        // Collect bundleIDs that are inside folders
        let folderAppBundleIDs = Set(folders.flatMap { $0.items.map(\.bundleID) })

        // Build slot items: folders + top-level apps (not in any folder)
        var slots: [(sortOrder: Int, item: GridSlotItem)] = []

        for folder in folders {
            slots.append((folder.sortOrder, .folder(folder)))
        }

        for appItem in appItems where !folderAppBundleIDs.contains(appItem.bundleID) {
            if let scanned = scannedByBundleID[appItem.bundleID] {
                slots.append((appItem.sortOrder, .app(scanned)))
            }
        }

        slots.sort { $0.sortOrder < $1.sortOrder }
        allItems = slots.map(\.item)
    }

    // MARK: - Pagination

    /// 取得指定頁面的網格項目列表。
    func items(forPage page: Int, perPage: Int) -> [GridSlotItem] {
        guard perPage > 0 else { return [] }
        let start = page * perPage
        guard start < allItems.count else { return [] }
        let end = min(start + perPage, allItems.count)
        return Array(allItems[start..<end])
    }

    /// 所有網格項目的總數。
    var totalItems: Int { allItems.count }

    // MARK: - Move / Reorder

    /// 將項目從指定索引移動到目標索引，並重新分配所有項目的排序順序。
    func moveItem(fromIndex: Int, toIndex: Int) {
        guard fromIndex != toIndex,
              fromIndex >= 0, fromIndex < allItems.count,
              toIndex >= 0, toIndex < allItems.count else { return }

        var items = allItems
        let moved = items.remove(at: fromIndex)
        items.insert(moved, at: toIndex)

        // Reassign sortOrder for all items
        for (index, slot) in items.enumerated() {
            switch slot {
            case .app(let scannedApp):
                if let appItem = fetchAppItem(bundleID: scannedApp.bundleID) {
                    appItem.sortOrder = index
                }
            case .folder(let folder):
                folder.sortOrder = index
            }
        }

        try? modelContext.save()
        allItems = items
    }

    /// Moves an item identified by its GridSlotItem.id to a target index.
    /// If the item is inside a folder, it is removed from the folder first.
    func moveItem(id: String, toIndex: Int) {
        // Item is in the top-level grid → simple reorder
        if let fromIndex = allItems.firstIndex(where: { $0.id == id }) {
            moveItem(fromIndex: fromIndex, toIndex: toIndex)
            return
        }

        // Item might be inside a folder — extract bundleID from "app-{bundleID}" format
        guard id.hasPrefix("app-") else { return }
        let bundleID = String(id.dropFirst(4))
        guard let appItem = fetchAppItem(bundleID: bundleID),
              appItem.folder != nil else { return }

        // Shift existing items first (while appItem is still in folder, unaffected by shift)
        shiftSortOrdersFrom(toIndex)
        // Then remove from folder and place at target position
        appItem.folder = nil
        appItem.sortOrder = toIndex

        try? modelContext.save()
        normalizeSortOrders()
        rebuildSlotItems(scannedApps: currentScannedApps())
    }

    // MARK: - Folder Operations

    /// Creates a new folder from two apps being dragged together.
    /// Returns the created folder, or nil if either app is not found.
    @discardableResult
    func createFolder(from appA: ScannedApp, and appB: ScannedApp, name: String = "新增資料夾") -> AppFolder? {
        guard let itemA = fetchAppItem(bundleID: appA.bundleID),
              let itemB = fetchAppItem(bundleID: appB.bundleID) else { return nil }

        // Use the lower sortOrder for the folder's position
        let folderSort = min(itemA.sortOrder, itemB.sortOrder)

        let folder = AppFolder(name: name, sortOrder: folderSort)
        modelContext.insert(folder)

        itemA.folder = folder
        itemB.folder = folder

        try? modelContext.save()
        rebuildSlotItems(scannedApps: currentScannedApps())
        return folder
    }

    /// Creates a folder from two slot item IDs.
    @discardableResult
    func createFolder(fromItemID idA: String, andItemID idB: String) -> AppFolder? {
        print("[FOLDER] createFolder called: idA=\(idA), idB=\(idB)")
        print("[FOLDER] allItems count: \(allItems.count)")
        guard let slotA = allItems.first(where: { $0.id == idA }),
              let slotB = allItems.first(where: { $0.id == idB }),
              case .app(let appA) = slotA,
              case .app(let appB) = slotB else {
            print("[FOLDER] ❌ Guard failed — slotA: \(allItems.first(where: { $0.id == idA }) != nil), slotB: \(allItems.first(where: { $0.id == idB }) != nil)")
            return nil
        }
        print("[FOLDER] ✅ Creating folder with: \(appA.name) + \(appB.name)")
        return createFolder(from: appA, and: appB)
    }

    /// Adds an app to an existing folder.
    func addToFolder(_ scannedApp: ScannedApp, folder: AppFolder) {
        guard let appItem = fetchAppItem(bundleID: scannedApp.bundleID) else { return }
        appItem.folder = folder
        try? modelContext.save()
        rebuildSlotItems(scannedApps: currentScannedApps())
    }

    /// Adds an app identified by slot ID to a folder.
    func addToFolder(itemID: String, folder: AppFolder) {
        // Try top-level items first
        if let slot = allItems.first(where: { $0.id == itemID }),
           case .app(let scannedApp) = slot {
            addToFolder(scannedApp, folder: folder)
            return
        }

        // Handle items from inside other folders (e.g., dragging between folders)
        guard itemID.hasPrefix("app-") else { return }
        let bundleID = String(itemID.dropFirst(4))
        guard let appItem = fetchAppItem(bundleID: bundleID) else { return }
        appItem.folder = folder
        try? modelContext.save()
        rebuildSlotItems(scannedApps: currentScannedApps())
    }

    /// Removes an app from its folder back to the main grid.
    func removeFromFolder(_ appItem: AppItem) {
        guard let folder = appItem.folder else { return }
        // Place after the folder in sort order
        appItem.sortOrder = folder.sortOrder + 1
        appItem.folder = nil

        // Shift subsequent items
        shiftSortOrdersFrom(appItem.sortOrder + 1)

        try? modelContext.save()
        rebuildSlotItems(scannedApps: currentScannedApps())
    }

    /// Deletes a folder, returning all contained apps to the main grid.
    func deleteFolder(_ folder: AppFolder) {
        let folderSort = folder.sortOrder
        let containedItems = folder.items

        // Return contained apps to main grid at folder's position
        for (offset, item) in containedItems.enumerated() {
            item.folder = nil
            item.sortOrder = folderSort + offset
        }

        modelContext.delete(folder)

        // Normalize all sortOrders
        try? modelContext.save()
        normalizeSortOrders()
        rebuildSlotItems(scannedApps: currentScannedApps())
    }

    /// Renames a folder.
    func renameFolder(_ folder: AppFolder, to newName: String) {
        folder.name = newName
        try? modelContext.save()
    }

    // MARK: - Reset

    /// Resets all custom ordering and folders, returning to alphabetical sort.
    func resetLayout() {
        // Delete all folders
        let folders = fetchAllFolders()
        for folder in folders {
            for item in folder.items {
                item.folder = nil
            }
            modelContext.delete(folder)
        }

        // Reset all AppItems to alphabetical order
        let items = fetchAllAppItems().sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        for (index, item) in items.enumerated() {
            item.sortOrder = index
        }

        try? modelContext.save()
        rebuildSlotItems(scannedApps: currentScannedApps())
    }

    // MARK: - Private Helpers

    /// 從 SwiftData 取得所有 AppItem，按排序順序排列。
    private func fetchAllAppItems() -> [AppItem] {
        let descriptor = FetchDescriptor<AppItem>(sortBy: [SortDescriptor(\.sortOrder)])
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    /// 從 SwiftData 取得所有 AppFolder，按排序順序排列。
    private func fetchAllFolders() -> [AppFolder] {
        let descriptor = FetchDescriptor<AppFolder>(sortBy: [SortDescriptor(\.sortOrder)])
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    /// 根據 Bundle ID 從 SwiftData 查詢對應的 AppItem。
    private func fetchAppItem(bundleID: String) -> AppItem? {
        let descriptor = FetchDescriptor<AppItem>(
            predicate: #Predicate { $0.bundleID == bundleID }
        )
        return try? modelContext.fetch(descriptor).first
    }

    /// Shifts sortOrder of items at or after the given position by +1.
    private func shiftSortOrdersFrom(_ position: Int) {
        let allAppItems = fetchAllAppItems()
        let folders = fetchAllFolders()

        for item in allAppItems where item.folder == nil && item.sortOrder >= position {
            item.sortOrder += 1
        }
        for folder in folders where folder.sortOrder >= position {
            folder.sortOrder += 1
        }
    }

    /// Renumbers all top-level items sequentially starting from 0.
    private func normalizeSortOrders() {
        let appItems = fetchAllAppItems().filter { $0.folder == nil }
        let folders = fetchAllFolders()

        var combined: [(sortOrder: Int, setOrder: (Int) -> Void)] = []

        for item in appItems {
            combined.append((item.sortOrder, { item.sortOrder = $0 }))
        }
        for folder in folders {
            combined.append((folder.sortOrder, { folder.sortOrder = $0 }))
        }

        combined.sort { $0.sortOrder < $1.sortOrder }
        for (index, entry) in combined.enumerated() {
            entry.setOrder(index)
        }

        try? modelContext.save()
    }

    /// Returns the last-known full ScannedApp list.
    private func currentScannedApps() -> [ScannedApp] {
        lastScannedApps
    }
}
