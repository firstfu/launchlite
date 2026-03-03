//
//  LaunchpadView.swift
//  launchlite
//
//  Created on 2026/3/2.
//
//  Launchpad 主容器視圖，包含搜尋列、應用網格和頁面指示器，並支援手勢翻頁。

import SwiftUI

/// The main Launchpad container view. Hosts the search bar, app grid, and page indicator.
/// Designed to be embedded in the LaunchpadPanel via NSHostingView.
struct LaunchpadView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var gridLayoutManager: GridLayoutManager

    @State private var hasAppeared = false

    /// 建立 Launchpad 主視圖，包含搜尋列、應用網格、頁面指示器及資料夾覆蓋層，支援點擊關閉和滑動翻頁。
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Search bar at top
                SearchBarView()
                    .padding(.top, 40)
                    .opacity(hasAppeared ? 1.0 : 0.0)
                    .offset(y: hasAppeared ? 0 : -10)

                Spacer()

                // App grid — vertically centered, but content top-left aligned
                AppGridView()
                    .opacity(hasAppeared ? 1.0 : 0.0)
                    .scaleEffect(hasAppeared ? 1.0 : 0.96)

                Spacer()

                // Page indicator at bottom
                PageIndicatorView()
                    .padding(.bottom, 36)
                    .opacity(hasAppeared ? 1.0 : 0.0)
                    .offset(y: hasAppeared ? 0 : 10)
            }

            // Folder content overlay — in the same window so drag-and-drop works
            if let folder = gridLayoutManager.expandedFolder {
                FolderContentOverlayView(folder: folder)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            // Tap on empty area to close — child views' gestures take priority
            if gridLayoutManager.expandedFolder != nil {
                gridLayoutManager.expandedFolder = nil
            } else {
                appState.hide()
            }
        }
        .gesture(
            DragGesture(minimumDistance: 50)
                .onEnded { value in
                    let horizontal = value.translation.width
                    if horizontal < -50, appState.currentPage < appState.totalPages - 1 {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            appState.currentPage += 1
                        }
                    } else if horizontal > 50, appState.currentPage > 0 {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            appState.currentPage -= 1
                        }
                    }
                }
        )
        .task {
            await appState.refreshApps()
        }
        .onAppear {
            hasAppeared = false
            withAnimation(.easeOut(duration: 0.35).delay(0.05)) {
                hasAppeared = true
            }
        }
    }
}
