//
//  AppState.swift
//  launchlite
//
//  Created on 2026/3/2.
//
//  應用程式全域狀態管理器，負責管理 Launchpad 的可見性、搜尋、分頁及應用程式啟動等核心狀態。

import AppKit
import Combine
import SwiftData
import SwiftUI

/// 應用程式全域狀態管理器，管理 Launchpad 的可見性、搜尋過濾、分頁及應用程式啟動。
@MainActor
final class AppState: ObservableObject {

    // MARK: - Published State

    @Published var isVisible = false
    @Published var searchText = ""
    @Published var isEditMode = false
    @Published var currentPage = 0
    /// 翻頁手勢期間的即時水平偏移量（像素），正值向右、負值向左。
    @Published var pageDragOffset: CGFloat = 0
    /// 當前視口寬度，由 AppGridView 的 GeometryReader 設定。
    var viewportWidth: CGFloat = 0
    @Published private(set) var installedApps: [ScannedApp] = []
    @Published private(set) var filteredApps: [ScannedApp] = []

    // MARK: - Dependencies

    let appScanner: AppScanner
    let modelContext: ModelContext
    let gridLayoutManager: GridLayoutManager

    // MARK: - Private

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    /// 初始化 AppState，注入 AppScanner 和 ModelContext 依賴並設定響應式綁定。
    init(appScanner: AppScanner, modelContext: ModelContext) {
        self.appScanner = appScanner
        self.modelContext = modelContext
        self.gridLayoutManager = GridLayoutManager(modelContext: modelContext)

        setupBindings()
    }

    // MARK: - Reactive Bindings

    /// 設定 Combine 響應式綁定，包含掃描結果同步、搜尋過濾、網格佈局同步及頁碼重設。
    private func setupBindings() {
        // Sync scanner results into installedApps
        appScanner.$apps
            .receive(on: RunLoop.main)
            .assign(to: &$installedApps)

        // Filter apps whenever searchText or installedApps changes
        $searchText
            .combineLatest($installedApps)
            .map { query, apps in
                guard !query.isEmpty else { return apps }
                let lowered = query.lowercased()
                return apps.filter {
                    $0.name.lowercased().contains(lowered)
                        || $0.bundleID.lowercased().contains(lowered)
                }
            }
            .assign(to: &$filteredApps)

        // Sync grid layout whenever installed apps change
        $installedApps
            .sink { [weak self] apps in
                self?.gridLayoutManager.syncWithScannedApps(apps)
            }
            .store(in: &cancellables)

        // Reset page to 0 when search text changes
        $searchText
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.currentPage = 0
                self?.pageDragOffset = 0
            }
            .store(in: &cancellables)
    }

    // MARK: - Pagination

    /// Whether we are currently in search mode (non-empty search text).
    var isSearching: Bool { !searchText.isEmpty }

    /// Number of items that fit on a single page, based on UserPreferences grid size.
    var appsPerPage: Int {
        let prefs = fetchPreferences()
        return prefs.gridRows * prefs.gridColumns
    }

    /// Total number of pages needed.
    var totalPages: Int {
        let perPage = appsPerPage
        guard perPage > 0 else { return 1 }
        let totalCount = isSearching ? filteredApps.count : gridLayoutManager.totalItems
        return max(1, Int(ceil(Double(totalCount) / Double(perPage))))
    }

    /// Returns the flat list of filtered apps for a search page (no folders, alphabetical).
    func apps(forPage page: Int) -> [ScannedApp] {
        let perPage = appsPerPage
        guard perPage > 0 else { return [] }
        let start = page * perPage
        guard start < filteredApps.count else { return [] }
        let end = min(start + perPage, filteredApps.count)
        return Array(filteredApps[start..<end])
    }

    /// Returns the unified grid slot items for a page (custom order with folders).
    func gridItems(forPage page: Int) -> [GridSlotItem] {
        gridLayoutManager.items(forPage: page, perPage: appsPerPage)
    }

    // MARK: - Page Snap

    /// 根據當前拖動偏移量吸附到最近的頁面，支援預測偏移以考慮手勢速度。
    func snapToNearestPage(predictedOffset: CGFloat? = nil) {
        guard viewportWidth > 0 else {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                pageDragOffset = 0
            }
            return
        }

        let snapOffset = predictedOffset ?? pageDragOffset
        let effectivePosition = CGFloat(currentPage) - snapOffset / viewportWidth
        let targetPage = max(0, min(totalPages - 1, Int(round(effectivePosition))))

        // 調整偏移量以補償頁碼變化（瞬間完成，視覺位置不變）
        let pageDelta = targetPage - currentPage
        pageDragOffset += CGFloat(pageDelta) * viewportWidth
        currentPage = targetPage

        // 動畫將偏移量歸零（視覺上平滑吸附到目標頁面）
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            pageDragOffset = 0
        }
    }

    // MARK: - Visibility

    /// 顯示 Launchpad，重設搜尋文字、編輯模式及頁碼至初始狀態。
    func show() {
        searchText = ""
        isEditMode = false
        currentPage = 0
        pageDragOffset = 0
        isVisible = true
    }

    /// 隱藏 Launchpad，清除搜尋文字及編輯模式。
    func hide() {
        isVisible = false
        searchText = ""
        isEditMode = false
    }

    /// 切換 Launchpad 的顯示與隱藏狀態。
    func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }

    // MARK: - App Launching

    /// 透過 Bundle ID 啟動指定應用程式，更新 SwiftData 中的最後使用時間，並隱藏 Launchpad。
    func launchApp(bundleID: String) {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.openApplication(at: url, configuration: configuration)

        // Update lastUsed timestamp in SwiftData
        let descriptor = FetchDescriptor<AppItem>(
            predicate: #Predicate { $0.bundleID == bundleID }
        )
        if let item = try? modelContext.fetch(descriptor).first {
            item.lastUsed = Date()
            try? modelContext.save()
        }

        hide()
    }

    // MARK: - Refresh

    /// 非同步重新掃描系統中已安裝的應用程式。
    func refreshApps() async {
        _ = await appScanner.scan()
    }

    // MARK: - Preferences Helper

    /// 從 SwiftData 取得使用者偏好設定，若無則回傳預設值。
    private func fetchPreferences() -> UserPreferences {
        let descriptor = FetchDescriptor<UserPreferences>()
        if let prefs = try? modelContext.fetch(descriptor).first {
            return prefs
        }
        return UserPreferences()
    }
}
