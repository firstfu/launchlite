//
//  BlurEffect.swift
//  launchlite
//
//  Created on 2026/3/2.
//
//  模糊效果工具，提供 NSVisualEffectView 的 SwiftUI 封裝。

import SwiftUI
import AppKit

/// A SwiftUI wrapper for NSVisualEffectView, providing a native macOS blur effect.
struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    var state: NSVisualEffectView.State

    /// 初始化模糊效果視圖，可自訂材質、混合模式和狀態。
    init(
        material: NSVisualEffectView.Material = .fullScreenUI,
        blendingMode: NSVisualEffectView.BlendingMode = .behindWindow,
        state: NSVisualEffectView.State = .active
    ) {
        self.material = material
        self.blendingMode = blendingMode
        self.state = state
    }

    /// 建立並回傳 NSVisualEffectView 實例。
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = state
        return view
    }

    /// 更新現有的 NSVisualEffectView 屬性以反映 SwiftUI 狀態變化。
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = state
    }
}
