// ContentView.swift
// Main UI layout: split-screen with AR camera (top) and 3D spatial map (bottom)

import SwiftUI

struct ContentView: View {
    @StateObject private var sessionManager = ARSessionManager()
    @State private var isTrackingMode = false
    @State private var showItemList = false

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // ── Top Half: AR Camera View ──
                ZStack {
                    ARCameraView(
                        sessionManager: sessionManager,
                        onTap: isTrackingMode ? { point in
                            sessionManager.placeItem(at: point)
                            withAnimation { isTrackingMode = false }
                        } : nil
                    )

                    // Tracking mode crosshair overlay — does NOT block taps
                    if isTrackingMode {
                        trackingOverlay
                            .allowsHitTesting(false) // taps pass through to ARSCNView
                    }

                    // Status bar and controls overlay
                    VStack {
                        statusBar
                        Spacer()
                        cameraControls
                    }
                    .padding(.vertical, 8)
                }
                .frame(height: geometry.size.height * 0.55)
                .clipped()

                // ── Divider ──
                Rectangle()
                    .fill(Color.white.opacity(0.2))
                    .frame(height: 2)

                // ── Bottom Half: 3D Spatial Map ──
                ZStack(alignment: .topLeading) {
                    SpatialMapView(sessionManager: sessionManager)
                    mapOverlay
                }
                .frame(height: geometry.size.height * 0.45)
                .clipped()
            }
        }
        .ignoresSafeArea()
        .sheet(isPresented: $showItemList) {
            ItemListView(sessionManager: sessionManager)
        }
    }

    // MARK: - Subviews

    private var statusBar: some View {
        HStack {
            HStack(spacing: 6) {
                Circle()
                    .fill(sessionManager.isLiDARAvailable ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                Text(sessionManager.trackingStatus)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial)
            .cornerRadius(20)

            Spacer()

            if !sessionManager.trackedItems.isEmpty {
                Button(action: { showItemList = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "cube.fill")
                        Text("\(sessionManager.trackedItems.count)")
                            .fontWeight(.bold)
                    }
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
                }
            }
        }
        .padding(.horizontal)
        .padding(.top, 50)
    }

    private var cameraControls: some View {
        HStack(spacing: 16) {
            Button(action: {
                withAnimation(.spring(response: 0.3)) {
                    isTrackingMode.toggle()
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: isTrackingMode ? "xmark" : "viewfinder")
                        .font(.system(size: 16, weight: .semibold))
                    Text(isTrackingMode ? "Cancel" : "Track Item")
                        .fontWeight(.semibold)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(isTrackingMode ? Color.red : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(25)
                .shadow(radius: 4)
            }

            if !sessionManager.trackedItems.isEmpty {
                Button(action: {
                    withAnimation { sessionManager.removeLastItem() }
                }) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 16, weight: .semibold))
                        .padding(12)
                        .background(.ultraThinMaterial)
                        .foregroundColor(.white)
                        .clipShape(Circle())
                        .shadow(radius: 4)
                }
            }
        }
        .padding(.bottom, 12)
    }

    private var trackingOverlay: some View {
        ZStack {
            Color.black.opacity(0.15)

            VStack(spacing: 16) {
                // Crosshair
                ZStack {
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: 40, height: 1.5)
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: 1.5, height: 40)
                    ForEach(0..<4, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 1)
                            .stroke(Color.white, lineWidth: 2)
                            .frame(width: 20, height: 20)
                            .offset(
                                x: CGFloat(i % 2 == 0 ? -15 : 15),
                                y: CGFloat(i < 2 ? -15 : 15)
                            )
                    }
                }
                .shadow(radius: 2)

                Text("Tap on an item to track it")
                    .font(.callout)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(20)
            }
        }
    }

    private var mapOverlay: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "cube.transparent")
                Text("3D Spatial Map")
                    .fontWeight(.semibold)
            }
            .font(.caption)
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial)
            .cornerRadius(8)

            if !sessionManager.trackedItems.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(sessionManager.trackedItems) { item in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(item.color)
                                .frame(width: 8, height: 8)
                                .opacity(item.isActivelyTracked ? 1.0 : 0.4)
                            Text(item.name)
                                .font(.caption2)
                                .foregroundColor(.white)
                            Spacer()
                            Text(item.lastSeenDescription)
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial)
                .cornerRadius(8)
            }

            Text("Pinch to zoom · Drag to orbit")
                .font(.system(size: 9))
                .foregroundColor(.gray)
                .padding(.horizontal, 10)
        }
        .padding(10)
    }
}

// MARK: - Item List Sheet

struct ItemListView: View {
    @ObservedObject var sessionManager: ARSessionManager
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            List {
                if sessionManager.trackedItems.isEmpty {
                    Text("No items tracked yet.")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(sessionManager.trackedItems) { item in
                        HStack {
                            Circle()
                                .fill(item.color)
                                .frame(width: 14, height: 14)

                            VStack(alignment: .leading) {
                                Text(item.name)
                                    .font(.body)
                                    .fontWeight(.medium)
                                Text(String(format: "x:%.2f y:%.2f z:%.2f",
                                            item.position.x, item.position.y, item.position.z))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .monospacedDigit()
                            }

                            Spacer()

                            VStack(alignment: .trailing) {
                                Image(systemName: item.isActivelyTracked ? "eye.fill" : "eye.slash")
                                    .foregroundColor(item.isActivelyTracked ? .green : .orange)
                                Text(item.lastSeenDescription)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            let item = sessionManager.trackedItems[index]
                            sessionManager.removeItem(item.id)
                        }
                    }
                }
            }
            .navigationTitle("Tracked Items")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
