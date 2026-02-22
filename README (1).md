# SpatialTracker — iOS 3D Item Tracking with LiDAR

A real-time spatial mapping and item tracking app that uses the iPhone's LiDAR sensor and ARKit to create a 3D model of your environment, then lets you tag and track physical items within that 3D space.

---

## Features

- **Real-time LiDAR mesh scanning** — Continuously reconstructs your environment as a 3D wireframe mesh
- **Split-screen interface** — Live AR camera on top, interactive 3D map on the bottom
- **Item tracking** — Tap on any object to place a persistent 3D marker at its location
- **Vision-based movement tracking** — Uses Apple's Vision framework to follow items as they move and update their 3D position
- **Interactive 3D map** — Orbit, pan, and zoom the spatial map; see all tracked items with labels and color coding
- **Device position indicator** — See where your phone is in the 3D map in real time

---

## Requirements

| Requirement | Details |
|---|---|
| **iOS** | 16.0+ |
| **Xcode** | 15.0+ |
| **Device** | iPhone 12 Pro, 13 Pro, 14 Pro, 15 Pro, 16 Pro (or any iPad Pro with LiDAR) |
| **Frameworks** | ARKit, SceneKit, Vision, SwiftUI |

> **Note:** LiDAR is required for full mesh scanning. On devices without LiDAR, the app falls back to plane detection only (horizontal/vertical surfaces).

---

## Project Setup

### 1. Create a new Xcode project

1. Open Xcode → **File → New → Project**
2. Select **iOS → App**
3. Configure:
   - **Product Name:** `SpatialTracker`
   - **Interface:** SwiftUI
   - **Language:** Swift
   - **Bundle Identifier:** `com.yourname.SpatialTracker`
4. Click **Create**

### 2. Copy source files

Delete the auto-generated `ContentView.swift` from Xcode, then drag all `.swift` files from this folder into your Xcode project navigator:

```
SpatialTrackerApp.swift    — App entry point
ContentView.swift          — Main split-screen UI layout
ARCameraView.swift         — AR camera feed with mesh overlay
SpatialMapView.swift       — 3D map visualization
ARSessionManager.swift     — Core AR session + Vision tracking
TrackedItem.swift          — Data model for tracked items
```

### 3. Configure Info.plist

Either replace the auto-generated Info.plist with the provided one, or add these keys manually:

- **Privacy — Camera Usage Description**: `SpatialTracker needs camera access to scan your environment and track items in 3D space using ARKit and LiDAR.`
- **Required device capabilities**: `arkit`
- **Supported interface orientations**: Portrait only

### 4. Build & Run

1. Connect your LiDAR-equipped iPhone
2. Select your device as the build target (this won't work in the simulator)
3. **Product → Run** (⌘R)
4. Grant camera permission when prompted

---

## How to Use

### Scanning Your Space
As soon as the app launches, it begins scanning. Move your phone slowly around the room — you'll see the cyan wireframe mesh building in both the camera view and the 3D map below.

### Tracking an Item
1. Tap **"Track Item"** to enter tracking mode
2. Point your camera at the object you want to track
3. Tap on the object — a colored marker appears at its 3D position
4. The item now shows up on the 3D spatial map

### Viewing the 3D Map
- **Drag** to orbit the map
- **Pinch** to zoom in/out
- **Two-finger drag** to pan
- The white cone shows your device's current position and direction
- Colored spheres represent tracked items with vertical pillars showing height

### Managing Items
- Tap the item counter badge (top-right) to see the full item list
- Swipe to delete items from the list
- Tap the undo arrow to remove the last placed item

---

## Architecture

```
┌─────────────────────────────────────────────┐
│                ContentView                   │
│  ┌───────────────────────────────────────┐  │
│  │           ARCameraView                │  │
│  │  (ARSCNView + mesh overlay + markers) │  │
│  └───────────────────────────────────────┘  │
│  ┌───────────────────────────────────────┐  │
│  │          SpatialMapView               │  │
│  │  (SCNView + mesh + items + device)    │  │
│  └───────────────────────────────────────┘  │
└──────────────────┬──────────────────────────┘
                   │ @ObservedObject
         ┌─────────▼──────────┐
         │  ARSessionManager  │
         │                    │
         │  • ARSession       │
         │  • Mesh anchors    │
         │  • Tracked items   │
         │  • Vision tracking │
         │  • Camera pose     │
         └────────────────────┘
```

### Key Components

| File | Role |
|---|---|
| `ARSessionManager` | Central brain — manages the ARKit session, processes LiDAR mesh anchors, handles item placement via raycasting, and runs Vision-based object tracking on each frame |
| `ARCameraView` | `UIViewRepresentable` wrapping `ARSCNView` — renders the live camera feed with mesh overlay and animated item markers |
| `SpatialMapView` | `UIViewRepresentable` wrapping `SCNView` — renders the 3D map with converted mesh geometry, item spheres, device indicator, and grid floor. Updates on a 0.3s timer |
| `TrackedItem` | Simple model holding name, 3D position, color, last-seen timestamp, and active tracking state |

### Data Flow

1. **ARKit** captures frames with LiDAR depth → `ARSessionDelegate` receives mesh anchors
2. **Mesh anchors** are stored in `ARSessionManager.meshAnchors` (published)
3. **Camera view** renders mesh via `ARSCNViewDelegate.renderer(_:nodeFor:)` 
4. **3D map** converts `ARMeshAnchor` geometry to `SCNGeometry` and renders in a separate `SCNView`
5. **Item placement**: screen tap → `raycastQuery` → 3D world position → `TrackedItem` created
6. **Vision tracking**: each frame's `CVPixelBuffer` → `VNTrackObjectRequest` → updated bounding box → raycast → position update

---

## Next Steps / Enhancements

- [ ] **Persistent storage** — Save the 3D map and item positions to disk so they survive app restarts (use ARKit's `ARWorldMap`)
- [ ] **Object recognition** — Use Core ML + Vision to automatically identify common objects (keys, wallet, remote, etc.)
- [ ] **Search & navigate** — Search for a lost item and display an AR arrow pointing to its last known location
- [ ] **Multi-room support** — Stitch together maps from different rooms into one unified space
- [ ] **Notifications** — Alert when a tracked item hasn't been seen in its expected location for too long
- [ ] **Collaborative tracking** — Share spatial maps between devices using MultipeerConnectivity
- [ ] **Item thumbnails** — Capture a snapshot of each item when first tracked for visual reference

---

## Troubleshooting

| Issue | Solution |
|---|---|
| Black camera screen | Ensure camera permissions are granted in Settings → SpatialTracker |
| No mesh appearing | Confirm you're using a LiDAR device. Move slowly and ensure adequate lighting |
| Items not placing | Make sure you can see surfaces in the camera. ARKit needs detected planes/geometry to raycast against |
| Map not updating | The map refreshes every 0.3s. Give it a moment after scanning new areas |
| Tracking "lost" on items | Vision tracking can lose objects if they move too fast or change appearance significantly. The last known position is preserved |

---

## License

MIT — use freely for personal and commercial projects.
