//
//  IconStyleManager.swift
//  launchlite
//
//  Created by firstfu on 2026/3/2.
//
//  圖示樣式管理器，負責取得應用程式圖示並處理外觀模式變更。

import Cocoa

/// 圖示樣式管理器，負責取得和處理應用程式圖示，並監聽系統外觀模式變更。
@MainActor
final class IconStyleManager {
    /// 圖示顯示風格列舉，支援自動、淺色、深色和著色模式。
    enum IconStyle: Sendable {
        case automatic
        case light
        case dark
        case tinted
    }

    private(set) var currentStyle: IconStyle = .automatic
    private var appearanceObservation: NSKeyValueObservation?

    /// 初始化圖示樣式管理器並開始監聽系統外觀變更。
    init() {
        observeAppearanceChanges()
    }

    deinit {
        appearanceObservation?.invalidate()
    }

    // MARK: - Appearance Detection

    /// Returns the current effective appearance (dark or light).
    var isDarkMode: Bool {
        let appearance = NSApp.effectiveAppearance
        return appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

    /// 監聽系統外觀模式變更（深色/淺色模式切換）。
    private func observeAppearanceChanges() {
        appearanceObservation = NSApp.observe(\.effectiveAppearance, options: [.new]) { [weak self] _, _ in
            Task { @MainActor in
                self?.handleAppearanceChange()
            }
        }
    }

    /// 處理系統外觀模式變更事件。
    private func handleAppearanceChange() {
        // Notify observers or update cached values if needed
    }

    // MARK: - Icon Retrieval

    /// Returns the icon image for a given app bundle ID, styled appropriately.
    func icon(forBundleID bundleID: String, size: CGFloat = 512) -> NSImage {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return fallbackIcon(size: size)
        }

        let icon = NSWorkspace.shared.icon(forFile: appURL.path)
        icon.size = NSSize(width: size, height: size)
        return icon
    }

    /// Returns the icon image for an app at a given URL.
    func icon(forAppAt url: URL, size: CGFloat = 512) -> NSImage {
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = NSSize(width: size, height: size)
        return icon
    }

    /// Returns icon data (PNG) for the given bundle ID.
    func iconData(forBundleID bundleID: String, size: CGFloat = 512) -> Data? {
        let image = icon(forBundleID: bundleID, size: size)
        return pngData(from: image)
    }

    // MARK: - Fallback

    /// 產生一個通用的應用程式替代圖示，用於找不到應用程式時的備用顯示。
    private func fallbackIcon(size: CGFloat) -> NSImage {
        let image = NSImage(systemSymbolName: "app.fill", accessibilityDescription: "Application") ?? NSImage()
        image.size = NSSize(width: size, height: size)
        return image
    }

    // MARK: - PNG Conversion

    /// 將 NSImage 轉換為 PNG 格式的 Data。
    private func pngData(from image: NSImage) -> Data? {
        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData)
        else {
            return nil
        }
        return bitmapRep.representation(using: .png, properties: [:])
    }
}
