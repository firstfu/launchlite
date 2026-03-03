//
//  FolderView.swift
//  launchlite
//
//  Created on 2026/3/2.
//
//  資料夾視圖，顯示 3x3 迷你預覽網格，支援點擊展開、重新命名和刪除。

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Displays a folder with a 3x3 mini grid preview of contained apps.
/// Tapping opens the folder content overlay (managed by LaunchpadView).
/// Supports renaming, deleting, and dragging apps in/out.
struct FolderView: View {
    let folder: AppFolder
    let iconSize: CGFloat

    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var gridLayoutManager: GridLayoutManager
    @State private var isHovering = false
    @State private var isRenaming = false
    @State private var editedName: String = ""

    /// 建立資料夾視圖，包含迷你預覽、懸停效果、編輯模式刪除按鈕及重新命名功能。
    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .topLeading) {
                folderPreview
                    .scaleEffect(isHovering ? 1.06 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHovering)

                if appState.isEditMode {
                    Button {
                        gridLayoutManager.deleteFolder(folder)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.white, .gray)
                    }
                    .buttonStyle(.plain)
                    .offset(x: -4, y: -4)
                }
            }

            if isRenaming {
                TextField("資料夾名稱", text: $editedName, onCommit: {
                    gridLayoutManager.renameFolder(folder, to: editedName)
                    isRenaming = false
                })
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .frame(width: iconSize + 16)
                .onAppear { editedName = folder.name }
            } else {
                Text(folder.name)
                    .font(.system(size: 11))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(width: iconSize + 16)
                    .onTapGesture(count: 2) {
                        editedName = folder.name
                        isRenaming = true
                    }
            }
        }
        .onHover { hovering in
            isHovering = hovering
        }
        .onTapGesture {
            if appState.isEditMode {
                editedName = folder.name
                isRenaming = true
            } else {
                // Open folder content as overlay (same window, not popover)
                gridLayoutManager.expandedFolder = folder
            }
        }
    }

    // MARK: - 3x3 Mini Grid Preview

    /// 資料夾 3x3 迷你圖示預覽，顯示前 9 個應用程式的縮圖。
    private var folderPreview: some View {
        let previewItems = Array(folder.items.prefix(9))
        let miniSize = iconSize / 4

        return ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .opacity(0.7)
            RoundedRectangle(cornerRadius: 16)
                .fill(.white.opacity(0.12))
            RoundedRectangle(cornerRadius: 16)
                .stroke(.white.opacity(0.15), lineWidth: 0.5)
        }
        .frame(width: iconSize, height: iconSize)
        .shadow(color: .black.opacity(isHovering ? 0.45 : 0.3), radius: isHovering ? 10 : 6, x: 0, y: isHovering ? 5 : 3)
        .overlay {
            LazyVGrid(
                columns: Array(repeating: GridItem(.fixed(miniSize), spacing: 3), count: 3),
                spacing: 3
            ) {
                ForEach(previewItems, id: \.bundleID) { item in
                    if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: item.bundleID) {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                            .resizable()
                            .frame(width: miniSize, height: miniSize)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                }
            }
            .padding(8)
        }
    }
}

// MARK: - Folder Content Overlay

/// Full-screen overlay showing expanded folder content.
/// Placed in the same window as the grid (via LaunchpadView ZStack)
/// so drag-and-drop works correctly — unlike .popover which creates a separate NSWindow.
struct FolderContentOverlayView: View {
    let folder: AppFolder

    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var gridLayoutManager: GridLayoutManager
    @State private var isRenaming = false
    @State private var editedName: String = ""

    /// 建立資料夾展開覆蓋層，顯示可編輯的資料夾名稱和 4 欄應用程式網格。
    var body: some View {
        ZStack {
            // Dimmed background — tap to close
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    gridLayoutManager.expandedFolder = nil
                }

            // Folder content card
            VStack(spacing: 14) {
                // Editable folder name
                if isRenaming {
                    TextField("資料夾名稱", text: $editedName, onCommit: {
                        gridLayoutManager.renameFolder(folder, to: editedName)
                        isRenaming = false
                    })
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 16, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .frame(width: 200)
                } else {
                    Text(folder.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .onTapGesture(count: 2) {
                            editedName = folder.name
                            isRenaming = true
                        }
                }

                let columns = Array(repeating: GridItem(.fixed(64), spacing: 18), count: 4)
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(folder.items, id: \.bundleID) { item in
                        VStack(spacing: 5) {
                            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: item.bundleID) {
                                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                                    .resizable()
                                    .frame(width: 48, height: 48)
                                    .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
                            }
                            Text(item.name)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.white.opacity(0.9))
                                .lineLimit(1)
                        }
                        .onTapGesture {
                            appState.launchApp(bundleID: item.bundleID)
                        }
                        .onDrag {
                            let dragID = "app-\(item.bundleID)"
                            gridLayoutManager.startDrag(itemID: dragID)
                            // Close the overlay so the grid cells underneath can receive the drop.
                            // The NSItemProvider is returned before SwiftUI processes the view update,
                            // so the drag session survives the overlay removal.
                            gridLayoutManager.expandedFolder = nil
                            let provider = NSItemProvider()
                            provider.registerDataRepresentation(
                                forTypeIdentifier: UTType.launchLiteGridItem.identifier,
                                visibility: .ownProcess
                            ) { completion in
                                completion(dragID.data(using: .utf8), nil)
                                return nil
                            }
                            return provider
                        }
                        .contextMenu {
                            Button("從資料夾移出") {
                                gridLayoutManager.removeFromFolder(item)
                                if folder.items.isEmpty {
                                    gridLayoutManager.expandedFolder = nil
                                }
                            }
                        }
                    }
                }

                if folder.items.isEmpty {
                    Text("拖曳 app 到此處")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.4))
                        .frame(width: 200, height: 60)
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
            )
            .onDrop(of: [.launchLiteGridItem], isTargeted: nil) { providers in
                handleFolderDrop(providers: providers)
            }
        }
        .transition(.opacity)
        .onAppear {
            editedName = folder.name
        }
    }

    /// 處理拖放到資料夾覆蓋層的操作，將拖曳的應用程式加入資料夾。
    private func handleFolderDrop(providers: [NSItemProvider]) -> Bool {
        guard let dragID = gridLayoutManager.draggedItemID else { return false }
        gridLayoutManager.addToFolder(itemID: dragID, folder: folder)
        gridLayoutManager.endDrag()
        return true
    }
}
