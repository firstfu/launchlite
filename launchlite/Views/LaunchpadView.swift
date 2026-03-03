//
//  LaunchpadView.swift
//  launchlite
//
//  Created on 2026/3/2.
//
//  Launchpad 主容器視圖，包含搜尋列、應用網格和頁面指示器，並支援手勢翻頁及拖動關閉。

import SwiftUI

/// The main Launchpad container view. Hosts the search bar, app grid, and page indicator.
/// Designed to be embedded in the LaunchpadPanel via NSHostingView.
struct LaunchpadView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var gridLayoutManager: GridLayoutManager

    @State private var hasAppeared = false

    /// 垂直拖動關閉的偏移量
    @State private var dismissOffset: CGFloat = 0
    /// 拖動方向判定：undetermined → 首次顯著移動後鎖定為 horizontal 或 vertical
    @State private var dragDirection: DragDirection = .undetermined

    private enum DragDirection {
        case undetermined, horizontal, vertical
    }

    /// 建立 Launchpad 主視圖，包含搜尋列、應用網格、頁面指示器及資料夾覆蓋層，支援點擊關閉、滑動翻頁及拖動關閉。
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
        // 拖動關閉：內容隨手勢移動並縮放
        .offset(y: dismissOffset)
        .scaleEffect(dismissScaleEffect)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .opacity(dismissOpacity)
        .onTapGesture {
            // Tap on empty area to close — child views' gestures take priority
            if gridLayoutManager.expandedFolder != nil {
                gridLayoutManager.expandedFolder = nil
            } else {
                appState.hide()
            }
        }
        .gesture(dragGesture)
        .task {
            await appState.refreshApps()
        }
        .onAppear {
            dismissOffset = 0
            dragDirection = .undetermined
            appState.pageDragOffset = 0
            hasAppeared = false
            withAnimation(.easeOut(duration: 0.35).delay(0.05)) {
                hasAppeared = true
            }
        }
    }

    // MARK: - Dismiss Gesture Effects

    /// 拖動時的縮放效果，隨距離增加輕微縮小
    private var dismissScaleEffect: CGFloat {
        let progress = min(abs(dismissOffset) / 600, 1.0)
        return 1.0 - progress * 0.1
    }

    /// 拖動時的透明度變化，隨距離增加逐漸淡出
    private var dismissOpacity: Double {
        let progress = min(abs(dismissOffset) / 500, 1.0)
        return 1.0 - progress * 0.5
    }

    // MARK: - Combined Drag Gesture

    /// 統一的拖動手勢：根據初始方向判定為水平翻頁（即時跟隨）或垂直關閉
    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 20)
            .onChanged { value in
                // 在首次顯著移動時判定方向並鎖定
                if dragDirection == .undetermined {
                    let absX = abs(value.translation.width)
                    let absY = abs(value.translation.height)
                    if absY > absX * 1.2 {
                        dragDirection = .vertical
                    } else if absX > absY {
                        dragDirection = .horizontal
                    }
                }

                switch dragDirection {
                case .vertical:
                    dismissOffset = value.translation.height
                case .horizontal:
                    appState.pageDragOffset = value.translation.width
                case .undetermined:
                    break
                }
            }
            .onEnded { value in
                switch dragDirection {
                case .vertical:
                    handleDismissDragEnd()
                case .horizontal:
                    appState.snapToNearestPage(predictedOffset: value.predictedEndTranslation.width)
                case .undetermined:
                    break
                }
                dragDirection = .undetermined
            }
    }

    /// 處理垂直拖動結束：超過閾值則滑出關閉，否則彈回原位
    private func handleDismissDragEnd() {
        let threshold: CGFloat = 120

        if abs(dismissOffset) > threshold {
            // 超過閾值：內容朝拖動方向飛出畫面
            let direction: CGFloat = dismissOffset > 0 ? 1 : -1
            withAnimation(.easeIn(duration: 0.2)) {
                dismissOffset = direction * 800
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                appState.hide()
                dismissOffset = 0
            }
        } else {
            // 未超過閾值：彈簧動畫回到原位
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                dismissOffset = 0
            }
        }
    }
}
