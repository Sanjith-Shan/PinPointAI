// ARSessionManager.swift

import ARKit
import SceneKit
import UIKit
import Combine

class ARSessionManager: NSObject, ObservableObject {

    @Published var trackedItems: [TrackedItem] = []
    @Published var meshAnchors: [ARMeshAnchor] = []
    @Published var planeAnchors: [ARPlaneAnchor] = []
    @Published var cameraTransform: simd_float4x4 = matrix_identity_float4x4
    @Published var trackingStatus: String = "Initializing..."
    @Published var isLiDARAvailable: Bool = false
    @Published var planeCount: Int = 0

    let session = ARSession()
    weak var arSCNView: ARSCNView?

    override init() {
        super.init()
        session.delegate = self
        isLiDARAvailable = ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)
    }

    func startSession() {
        guard ARWorldTrackingConfiguration.isSupported else {
            DispatchQueue.main.async { self.trackingStatus = "AR not supported" }
            return
        }

        let config = ARWorldTrackingConfiguration()

        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification) {
            config.sceneReconstruction = .meshWithClassification
        } else if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            config.sceneReconstruction = .mesh
        }

        config.planeDetection = [.horizontal, .vertical]
        config.environmentTexturing = .automatic

        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            config.frameSemantics.insert(.sceneDepth)
        }

        session.run(config, options: [.resetTracking, .removeExistingAnchors])

        DispatchQueue.main.async {
            self.trackingStatus = self.isLiDARAvailable
                ? "LiDAR active — move slowly to scan"
                : "Move slowly to scan surfaces"
        }
    }

    // MARK: - Place Item (one raycast, fixed forever)

    func placeItem(at screenPoint: CGPoint) {
        guard let arView = arSCNView else { return }

        var hitPosition: SIMD3<Float>?

        // Try all raycast strategies
        let strategies: [ARRaycastQuery.Target] = [.estimatedPlane, .existingPlaneGeometry, .existingPlaneInfinite]
        for strategy in strategies {
            if hitPosition != nil { break }
            if let query = arView.raycastQuery(from: screenPoint, allowing: strategy, alignment: .any),
               let hit = session.raycast(query).first {
                hitPosition = SIMD3<Float>(
                    hit.worldTransform.columns.3.x,
                    hit.worldTransform.columns.3.y,
                    hit.worldTransform.columns.3.z
                )
            }
        }

        // Fallback: 1m in front of camera
        if hitPosition == nil {
            let cam = session.currentFrame?.camera.transform ?? cameraTransform
            let forward = SIMD3<Float>(-cam.columns.2.x, -cam.columns.2.y, -cam.columns.2.z)
            let camPos = SIMD3<Float>(cam.columns.3.x, cam.columns.3.y, cam.columns.3.z)
            hitPosition = camPos + forward * 1.0
        }

        guard let position = hitPosition else { return }

        let name = "Item \(trackedItems.count + 1)"
        var item = TrackedItem(name: name, position: position, colorIndex: trackedItems.count)
        item.isActivelyTracked = true

        // Add an ARAnchor so ARKit world-locks this point
        let transform = simd_float4x4(
            SIMD4<Float>(1, 0, 0, 0),
            SIMD4<Float>(0, 1, 0, 0),
            SIMD4<Float>(0, 0, 1, 0),
            SIMD4<Float>(position.x, position.y, position.z, 1)
        )
        let anchor = ARAnchor(name: "tracked_\(item.id.uuidString)", transform: transform)
        session.add(anchor: anchor)

        DispatchQueue.main.async {
            self.trackedItems.append(item)
        }

        print("[ST] Placed '\(name)' at world position \(position) — FIXED, will never move")
    }

    func removeItem(_ id: UUID) {
        DispatchQueue.main.async {
            self.trackedItems.removeAll { $0.id == id }
        }
    }

    func removeLastItem() {
        guard let last = trackedItems.last else { return }
        removeItem(last.id)
    }

    // MARK: - Geometry Helpers

    static func planeGeometry(for planeAnchor: ARPlaneAnchor) -> SCNGeometry {
        let extent = planeAnchor.planeExtent
        let plane = SCNPlane(width: CGFloat(extent.width), height: CGFloat(extent.height))
        let material = SCNMaterial()
        material.diffuse.contents = planeAnchor.alignment == .horizontal
            ? UIColor.green.withAlphaComponent(0.25)
            : UIColor.blue.withAlphaComponent(0.25)
        material.isDoubleSided = true
        material.lightingModel = .constant
        plane.materials = [material]
        return plane
    }

    static func convertMeshToSCNGeometry(_ meshAnchor: ARMeshAnchor) -> SCNGeometry? {
        let geo = meshAnchor.geometry
        let vBuf = geo.vertices
        guard vBuf.count > 0 else { return nil }

        let vData = Data(bytes: vBuf.buffer.contents().advanced(by: vBuf.offset), count: vBuf.stride * vBuf.count)
        let vSrc = SCNGeometrySource(data: vData, semantic: .vertex, vectorCount: vBuf.count, usesFloatComponents: true, componentsPerVector: 3, bytesPerComponent: MemoryLayout<Float>.size, dataOffset: 0, dataStride: vBuf.stride)

        let nBuf = geo.normals
        let nData = Data(bytes: nBuf.buffer.contents().advanced(by: nBuf.offset), count: nBuf.stride * nBuf.count)
        let nSrc = SCNGeometrySource(data: nData, semantic: .normal, vectorCount: nBuf.count, usesFloatComponents: true, componentsPerVector: 3, bytesPerComponent: MemoryLayout<Float>.size, dataOffset: 0, dataStride: nBuf.stride)

        let fBuf = geo.faces
        let iCount = fBuf.count * fBuf.indexCountPerPrimitive
        let iData = Data(bytes: fBuf.buffer.contents(), count: iCount * fBuf.bytesPerIndex)
        let elem = SCNGeometryElement(data: iData, primitiveType: .triangles, primitiveCount: fBuf.count, bytesPerIndex: fBuf.bytesPerIndex)

        let scnGeo = SCNGeometry(sources: [vSrc, nSrc], elements: [elem])
        let mat = SCNMaterial()
        mat.diffuse.contents = UIColor.cyan.withAlphaComponent(0.3)
        mat.isDoubleSided = true
        mat.fillMode = .lines
        mat.lightingModel = .constant
        scnGeo.materials = [mat]
        return scnGeo
    }
}

// MARK: - ARSessionDelegate

extension ARSessionManager: ARSessionDelegate {

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        DispatchQueue.main.async { self.cameraTransform = frame.camera.transform }
    }

    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) { processAnchors(anchors) }
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) { processAnchors(anchors) }

    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        let ids = Set(anchors.map { $0.identifier })
        DispatchQueue.main.async {
            self.meshAnchors.removeAll { ids.contains($0.identifier) }
            self.planeAnchors.removeAll { ids.contains($0.identifier) }
            self.planeCount = self.planeAnchors.count
        }
    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        DispatchQueue.main.async { self.trackingStatus = "Error: \(error.localizedDescription)" }
    }

    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        DispatchQueue.main.async {
            switch camera.trackingState {
            case .notAvailable: self.trackingStatus = "Tracking unavailable"
            case .limited(let r):
                switch r {
                case .initializing: self.trackingStatus = "Initializing..."
                case .excessiveMotion: self.trackingStatus = "Move slower"
                case .insufficientFeatures: self.trackingStatus = "Point at textured surfaces"
                case .relocalizing: self.trackingStatus = "Relocalizing..."
                @unknown default: self.trackingStatus = "Limited"
                }
            case .normal:
                let s = self.planeAnchors.count
                self.trackingStatus = self.isLiDARAvailable ? "LiDAR — \(s) surfaces" : "Tracking — \(s) surfaces"
            }
        }
    }

    private func processAnchors(_ anchors: [ARAnchor]) {
        DispatchQueue.main.async {
            for anchor in anchors {
                if let mesh = anchor as? ARMeshAnchor {
                    if let i = self.meshAnchors.firstIndex(where: { $0.identifier == mesh.identifier }) {
                        self.meshAnchors[i] = mesh
                    } else { self.meshAnchors.append(mesh) }
                }
                if let plane = anchor as? ARPlaneAnchor {
                    if let i = self.planeAnchors.firstIndex(where: { $0.identifier == plane.identifier }) {
                        self.planeAnchors[i] = plane
                    } else { self.planeAnchors.append(plane) }
                    self.planeCount = self.planeAnchors.count
                }
            }
        }
    }
}
