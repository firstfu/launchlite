//
//  AppIconView.swift
//  launchlite
//
//  Created on 2026/3/2.
//

import SwiftUI

/// Displays a single app icon with name label. Supports hover, click-to-launch,
/// and edit mode (jiggle animation with delete button).
struct AppIconView: View {
    let app: ScannedApp
    let iconSize: CGFloat

    @EnvironmentObject private var appState: AppState
    @State private var isHovering = false
    @State private var isPressed = false

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // Soft ambient glow behind icon on hover
                Circle()
                    .fill(.white.opacity(isHovering ? 0.08 : 0.0))
                    .frame(width: iconSize + 20, height: iconSize + 20)
                    .blur(radius: 14)
                    .animation(.easeOut(duration: 0.25), value: isHovering)

                Image(nsImage: app.icon)
                    .interpolation(.high)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: iconSize, height: iconSize)
                    // Layered shadows for depth: soft ambient + sharper contact shadow
                    .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 2)
                    .shadow(color: .black.opacity(isHovering ? 0.4 : 0.25), radius: isHovering ? 14 : 8, x: 0, y: isHovering ? 8 : 4)
                    .scaleEffect(isPressed ? 0.92 : (isHovering ? 1.06 : 1.0))
                    .animation(.spring(response: 0.3, dampingFraction: 0.65), value: isHovering)
                    .animation(.spring(response: 0.15, dampingFraction: 0.5), value: isPressed)
                    .overlay(alignment: .topLeading) {
                        if appState.isEditMode {
                            Button {
                                // Delete action placeholder - remove from grid
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(.white, .gray.opacity(0.8))
                                    .shadow(color: .black.opacity(0.4), radius: 3)
                            }
                            .buttonStyle(.plain)
                            .offset(x: -4, y: -4)
                            .transition(.scale.combined(with: .opacity))
                        }
                    }
            }
            .rotationEffect(
                appState.isEditMode
                    ? .degrees(Double.random(in: -2...2))
                    : .zero
            )
            .animation(
                appState.isEditMode
                    ? .easeInOut(duration: 0.12).repeatForever(autoreverses: true)
                    : .default,
                value: appState.isEditMode
            )

            Text(app.name)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(isHovering ? 1.0 : 0.88))
                .shadow(color: .black.opacity(0.7), radius: 3, x: 0, y: 1)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: iconSize + 24)
                .animation(.easeOut(duration: 0.2), value: isHovering)
        }
        .onHover { hovering in
            isHovering = hovering
        }
        .onTapGesture {
            if !appState.isEditMode {
                // Brief press feedback
                isPressed = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isPressed = false
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    appState.launchApp(bundleID: app.bundleID)
                }
            }
        }
        .onLongPressGesture(minimumDuration: 0.8) {
            appState.isEditMode.toggle()
        }
    }
}
