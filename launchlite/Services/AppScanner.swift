//
//  AppScanner.swift
//  launchlite
//
//  Created by firstfu on 2026/3/2.
//
//  應用程式掃描器，負責掃描系統中已安裝的應用程式並監聽檔案系統變更。
//

import AppKit
import Combine
import Foundation

/// 掃描到的應用程式資料結構，包含 Bundle ID、名稱、路徑和圖示。
struct ScannedApp: Sendable, Identifiable, Hashable {
    let bundleID: String
    let name: String
    let url: URL
    let icon: NSImage

    var id: String { bundleID }
}

/// 應用程式掃描器，掃描 /Applications 等目錄中的已安裝應用程式，並監聽檔案系統變更自動更新。
@MainActor
final class AppScanner: ObservableObject {

    @Published private(set) var apps: [ScannedApp] = []

    private let searchPaths: [String] = [
        "/Applications",
        "/System/Applications",
        NSString("~/Applications").expandingTildeInPath,
    ]

    private var fileSources: [DispatchSourceFileSystemObject] = []

    /// 初始化掃描器並開始監聽應用程式目錄的檔案系統變更。
    init() {
        startMonitoring()
    }

    deinit {
        for source in fileSources {
            source.cancel()
        }
        fileSources.removeAll()
    }

    // MARK: - Public

    /// 在背景執行緒掃描所有搜尋路徑，回傳按名稱排序的應用程式列表。
    func scan() async -> [ScannedApp] {
        let paths = searchPaths
        let scanned = await Task.detached {
            AppScanner.performScan(searchPaths: paths)
        }.value

        apps = scanned
        return scanned
    }

    // MARK: - File System Monitoring

    /// 啟動檔案系統監聽，當應用程式目錄發生變更時自動重新掃描。
    private func startMonitoring() {
        for path in searchPaths {
            let fd = open(path, O_EVTONLY)
            guard fd >= 0 else { continue }

            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: fd,
                eventMask: [.write, .rename, .delete],
                queue: .global(qos: .utility)
            )

            source.setEventHandler { [weak self] in
                Task { @MainActor [weak self] in
                    _ = await self?.scan()
                }
            }

            source.setCancelHandler {
                close(fd)
            }

            source.resume()
            fileSources.append(source)
        }
    }

    // MARK: - Scanning (nonisolated)

    /// 執行實際的檔案系統掃描，遍歷所有搜尋路徑並收集應用程式資訊。
    nonisolated private static func performScan(searchPaths: [String]) -> [ScannedApp] {
        var results: [String: ScannedApp] = [:]

        for path in searchPaths {
            let directoryURL = URL(fileURLWithPath: path)
            guard let enumerator = FileManager.default.enumerator(
                at: directoryURL,
                includingPropertiesForKeys: [.isApplicationKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { continue }

            for case let fileURL as URL in enumerator {
                guard fileURL.pathExtension == "app" else { continue }
                guard !isFilteredApp(fileURL) else { continue }

                if let app = scannedApp(from: fileURL) {
                    results[app.bundleID] = app
                }
            }
        }

        return results.values.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    /// 從應用程式 URL 建立 ScannedApp 實例，讀取 Bundle 資訊和圖示。
    nonisolated private static func scannedApp(from url: URL) -> ScannedApp? {
        guard let bundle = Bundle(url: url),
              let bundleID = bundle.bundleIdentifier
        else { return nil }

        let name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? url.deletingPathExtension().lastPathComponent

        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = NSSize(width: 512, height: 512)

        return ScannedApp(bundleID: bundleID, name: name, url: url, icon: icon)
    }

    /// 判斷應用程式是否應被過濾排除（隱藏檔案、系統工具程式等）。
    nonisolated private static func isFilteredApp(_ url: URL) -> Bool {
        let name = url.lastPathComponent
        if name.hasPrefix(".") { return true }

        let filteredPaths = [
            "/System/Applications/Utilities/",
            "/System/Library/",
            "/usr/",
        ]
        let path = url.path
        for filtered in filteredPaths {
            if path.hasPrefix(filtered) { return true }
        }

        let filteredBundleIDs = [
            "com.apple.finder",
        ]
        if let bundle = Bundle(url: url),
           let bundleID = bundle.bundleIdentifier,
           filteredBundleIDs.contains(bundleID)
        {
            return true
        }

        return false
    }
}
