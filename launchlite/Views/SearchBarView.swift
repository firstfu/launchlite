//
//  SearchBarView.swift
//  launchlite
//
//  Created on 2026/3/2.
//
//  搜尋列視圖，提供半透明圓角搜尋欄位，附帶聚焦動畫效果。

import SwiftUI

/// A rounded, semi-transparent search bar styled like the classic Launchpad search field.
struct SearchBarView: View {
    @EnvironmentObject private var appState: AppState
    @FocusState private var isFocused: Bool
    @State private var animateFocus = false

    /// 建立搜尋列視圖，包含放大鏡圖示、文字輸入欄位和清除按鈕，附帶聚焦時的邊框和陰影動畫。
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.white.opacity(animateFocus ? 0.9 : 0.5))
                .font(.system(size: 14, weight: .medium))
                .animation(.easeOut(duration: 0.25), value: animateFocus)

            TextField("Search", text: $appState.searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .foregroundStyle(.white)
                .focused($isFocused)

            if !appState.searchText.isEmpty {
                Button {
                    appState.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.white.opacity(0.5))
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .transition(.opacity.combined(with: .scale))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .frame(width: 260)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.white.opacity(0.08))
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.ultraThinMaterial)
                        .opacity(0.5)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(
                    animateFocus ? .white.opacity(0.25) : .white.opacity(0.12),
                    lineWidth: animateFocus ? 1.0 : 0.5
                )
                .animation(.easeOut(duration: 0.25), value: animateFocus)
        )
        .shadow(color: .black.opacity(0.2), radius: animateFocus ? 12 : 6, y: 2)
        .animation(.easeOut(duration: 0.25), value: animateFocus)
        .onChange(of: isFocused) { _, focused in
            animateFocus = focused
        }
        .onAppear {
            isFocused = true
        }
    }
}
