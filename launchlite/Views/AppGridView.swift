//
//  AppGridView.swift
//  launchlite
//
//  Created on 2026/3/2.
//
//  應用程式網格視圖，顯示當前頁面的應用圖示，支援分頁動畫、拖放重排和資料夾建立。

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// 擴展 UTType，定義 LaunchLite 內部拖放使用的自訂類型。
extension UTType {
    /// LaunchLite 網格項目的自訂 UTType，用於內部拖放識別。
    static let launchLiteGridItem = UTType(exportedAs: "com.firstfu.tw.launchlite.griditem")
}

/// Displays the grid of app icons for the current page, with support for
/// page transitions, drag-and-drop rearranging, and folder creation.
struct AppGridView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var gridLayoutManager: GridLayoutManager
    @Query private var preferences: [UserPreferences]

    @State private var hoveredItemID: String?
    @State private var folderCreationTimer: Timer?

    /// 取得目前的使用者偏好設定，若無則回傳預設值。
    private var prefs: UserPreferences {
        preferences.first ?? UserPreferences()
    }

    /// 從偏好設定取得圖示大小。
    private var iconSize: CGFloat {
        prefs.iconSize
    }

    /// 根據偏好設定的欄數產生 LazyVGrid 所需的欄位配置。
    private var columns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: 28),
            count: prefs.gridColumns
        )
    }

    /// 計算滿頁 grid 的預期高度，確保每頁 grid 區域大小一致。
    private var expectedGridHeight: CGFloat {
        let cellHeight = iconSize + 58 // icon area (iconSize+20) + spacing (8) + text (~30)
        let rows = CGFloat(prefs.gridRows)
        return rows * cellHeight + (rows - 1) * 32
    }

    /// 根據搜尋狀態顯示搜尋模式網格或自訂排序網格。
    var body: some View {
        Group {
            if appState.isSearching {
                searchGrid
            } else {
                customOrderGrid
            }
        }
        .frame(height: expectedGridHeight, alignment: .top)
    }

    // MARK: - Search Mode Grid (flat, alphabetical, no folders)

    /// 搜尋模式的扁平網格視圖，按字母順序顯示過濾後的應用程式（無資料夾）。
    private var searchGrid: some View {
        let currentApps = appState.apps(forPage: appState.currentPage)

        return LazyVGrid(columns: columns, spacing: 32) {
            ForEach(currentApps) { app in
                AppIconView(app: app, iconSize: iconSize)
            }
        }
        .padding(.horizontal, 64)
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
        .id("search-\(appState.currentPage)")
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: appState.currentPage)
    }

    // MARK: - Custom Order Grid (with folders and drag-and-drop)

    /// 自訂排序的網格視圖，支援資料夾顯示和拖放重排。
    private var customOrderGrid: some View {
        let items = appState.gridItems(forPage: appState.currentPage)

        return LazyVGrid(columns: columns, spacing: 32) {
            ForEach(items) { item in
                gridCell(for: item)
                    .opacity(gridLayoutManager.draggedItemID == item.id ? 0.3 : 1.0)
                    .scaleEffect(hoveredItemID == item.id && gridLayoutManager.draggedItemID != item.id ? 1.12 : 1.0)
                    .animation(.spring(response: 0.25, dampingFraction: 0.6), value: hoveredItemID)
                    .onDrag {
                        print("[DRAG] onDrag started for item: \(item.id)")
                        gridLayoutManager.startDrag(itemID: item.id)
                        let provider = NSItemProvider()
                        provider.registerDataRepresentation(
                            forTypeIdentifier: UTType.launchLiteGridItem.identifier,
                            visibility: .ownProcess
                        ) { completion in
                            completion(Data(), nil)
                            return nil
                        }
                        return provider
                    }
                    .onDrop(
                        of: [.launchLiteGridItem],
                        delegate: GridCellDropDelegate(
                            targetItem: item,
                            gridLayoutManager: gridLayoutManager,
                            hoveredItemID: $hoveredItemID,
                            folderCreationTimer: $folderCreationTimer
                        )
                    )
            }
        }
        .padding(.horizontal, 64)
        .onChange(of: gridLayoutManager.draggedItemID) { _, newValue in
            if newValue == nil {
                hoveredItemID = nil
                folderCreationTimer?.invalidate()
                folderCreationTimer = nil
            }
        }
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
        .id("grid-\(appState.currentPage)")
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: appState.currentPage)
    }

    // MARK: - Grid Cell

    /// 根據 GridSlotItem 類型建立對應的網格儲存格視圖（應用程式或資料夾）。
    @ViewBuilder
    private func gridCell(for item: GridSlotItem) -> some View {
        switch item {
        case .app(let scannedApp):
            AppIconView(app: scannedApp, iconSize: iconSize)
        case .folder(let folder):
            FolderView(folder: folder, iconSize: iconSize)
        }
    }
}

// MARK: - Drop Delegate

/// 網格儲存格的拖放委託，處理拖放進入、離開、更新和執行等事件。
struct GridCellDropDelegate: DropDelegate {
    let targetItem: GridSlotItem
    let gridLayoutManager: GridLayoutManager
    @Binding var hoveredItemID: String?
    @Binding var folderCreationTimer: Timer?

    /// 拖放項目進入目標儲存格時呼叫，啟動資料夾建立計時器。
    func dropEntered(info: DropInfo) {
        print("[DROP] dropEntered for target: \(targetItem.id), draggedItemID: \(gridLayoutManager.draggedItemID ?? "nil")")
        hoveredItemID = targetItem.id

        // Start folder creation timer when app is dragged onto another app
        if case .app = targetItem,
           let dragID = gridLayoutManager.draggedItemID,
           dragID != targetItem.id {
            folderCreationTimer?.invalidate()
            print("[DROP] Starting 0.5s folder creation timer (drag: \(dragID) → target: \(targetItem.id))")
            // Use .common run loop mode so the timer fires during drag sessions
            // (which run in .eventTracking mode, not .default).
            // Call createFolder directly — do NOT use Task { @MainActor in }
            // because async Tasks may not execute during event-tracking RunLoop mode.
            let timer = Timer(timeInterval: 0.5, repeats: false) { _ in
                print("[DROP] Timer fired! Calling createFolder...")
                gridLayoutManager.createFolder(fromItemID: dragID, andItemID: targetItem.id)
                hoveredItemID = nil
            }
            RunLoop.main.add(timer, forMode: .common)
            folderCreationTimer = timer
        } else {
            print("[DROP] Skipped timer — targetItem is folder or dragID mismatch")
        }
    }

    /// 拖放項目離開目標儲存格時呼叫，取消資料夾建立計時器。
    func dropExited(info: DropInfo) {
        folderCreationTimer?.invalidate()
        folderCreationTimer = nil
        if hoveredItemID == targetItem.id {
            hoveredItemID = nil
        }
    }

    /// 拖放更新時回傳移動操作提案。
    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    /// 執行拖放操作，將項目加入資料夾或重新排序。
    func performDrop(info: DropInfo) -> Bool {
        print("[DROP] performDrop called for target: \(targetItem.id)")
        folderCreationTimer?.invalidate()
        folderCreationTimer = nil

        // Always clean up drag state and return true to prevent macOS drop artifacts
        defer {
            gridLayoutManager.endDrag()
            hoveredItemID = nil
        }

        guard let dragID = gridLayoutManager.draggedItemID, dragID != targetItem.id else {
            print("[DROP] performDrop — no dragID or same item, returning early")
            return true
        }

        // If target is a folder → add dragged app to folder
        if case .folder(let folder) = targetItem {
            gridLayoutManager.addToFolder(itemID: dragID, folder: folder)
            return true
        }

        // Otherwise → reorder (item may already have been foldered by timer)
        guard let targetIndex = gridLayoutManager.allItems.firstIndex(where: { $0.id == targetItem.id }) else {
            return true
        }
        gridLayoutManager.moveItem(id: dragID, toIndex: targetIndex)
        return true
    }
}
