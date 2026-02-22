// ARCameraView.swift
// Displays the live AR camera feed with LiDAR mesh overlay and tracked item markers

import SwiftUI
import ARKit
import SceneKit

struct ARCameraView: UIViewRepresentable {
    @ObservedObject var sessionManager: ARSessionManager
    var onTap: ((CGPoint) -> Void)?

    func makeUIView(context: Context) -> ARSCNView {
        let arView = ARSCNView()
        arView.session = sessionManager.session
        arView.delegate = context.coordinator
        arView.automaticallyUpdatesLighting = true
        arView.rendersCameraGrain = false

        // Debug options
        if sessionManager.isLiDARAvailable {
            arView.debugOptions = [.showWorldOrigin]
        }

        // Tap gesture for placing items
        let tapGesture = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        arView.addGestureRecognizer(tapGesture)
        arView.isUserInteractionEnabled = true

        // Store reference
        sessionManager.arSCNView = arView

        // Start session
        sessionManager.startSession()

        print("[SpatialTracker] ARSCNView created and session started")

        return arView
    }

    func updateUIView(_ arView: ARSCNView, context: Context) {
        // CRITICAL: Update the tap handler on every SwiftUI re-render
        // This is what makes tracking mode work — without this, onTap stays nil forever
        context.coordinator.onTap = onTap
        context.coordinator.updateTrackedItemNodes(in: arView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(sessionManager: sessionManager, onTap: onTap)
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, ARSCNViewDelegate {
        let sessionManager: ARSessionManager

        // MUTABLE — gets updated by updateUIView every time isTrackingMode changes
        var onTap: ((CGPoint) -> Void)?

        private var itemNodes: [UUID: SCNNode] = [:]
        private var meshNodes: [UUID: SCNNode] = [:]

        init(sessionManager: ARSessionManager, onTap: ((CGPoint) -> Void)?) {
            self.sessionManager = sessionManager
            self.onTap = onTap
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            let location = gesture.location(in: gesture.view)
            print("[SpatialTracker] TAP at \(location), handler exists: \(onTap != nil)")
            onTap?(location)
        }

        func updateTrackedItemNodes(in arView: ARSCNView) {
            let currentIds = Set(sessionManager.trackedItems.map { $0.id })

            // Remove nodes for deleted items
            for (id, node) in itemNodes where !currentIds.contains(id) {
                node.removeFromParentNode()
                itemNodes.removeValue(forKey: id)
            }

            // Add/update nodes
            for item in sessionManager.trackedItems {
                if let existingNode = itemNodes[item.id] {
                    SCNTransaction.begin()
                    SCNTransaction.animationDuration = 0.15
                    existingNode.simdPosition = item.position
                    SCNTransaction.commit()
                    existingNode.opacity = item.isActivelyTracked ? 1.0 : 0.5
                } else {
                    let node = createItemMarkerNode(for: item)
                    arView.scene.rootNode.addChildNode(node)
                    itemNodes[item.id] = node
                    print("[SpatialTracker] Added marker node for \(item.name)")
                }
            }
        }

        private func createItemMarkerNode(for item: TrackedItem) -> SCNNode {
            let containerNode = SCNNode()
            containerNode.simdPosition = item.position

            // Main sphere
            let sphere = SCNSphere(radius: 0.025)
            let material = SCNMaterial()
            material.diffuse.contents = item.uiColor
            material.emission.contents = item.uiColor.withAlphaComponent(0.4)
            material.lightingModel = .physicallyBased
            sphere.materials = [material]
            let sphereNode = SCNNode(geometry: sphere)
            containerNode.addChildNode(sphereNode)

            // Pulsing ring
            let ring = SCNTorus(ringRadius: 0.035, pipeRadius: 0.003)
            let ringMaterial = SCNMaterial()
            ringMaterial.diffuse.contents = item.uiColor.withAlphaComponent(0.6)
            ringMaterial.lightingModel = .constant
            ring.materials = [ringMaterial]
            let ringNode = SCNNode(geometry: ring)
            containerNode.addChildNode(ringNode)

            let pulse = CABasicAnimation(keyPath: "scale")
            pulse.fromValue = SCNVector3(1, 1, 1)
            pulse.toValue = SCNVector3(1.3, 1.3, 1.3)
            pulse.duration = 1.0
            pulse.autoreverses = true
            pulse.repeatCount = .infinity
            ringNode.addAnimation(pulse, forKey: "pulse")

            // Label
            let text = SCNText(string: item.name, extrusionDepth: 0.5)
            text.font = UIFont.systemFont(ofSize: 4, weight: .bold)
            text.flatness = 0.2
            let textMaterial = SCNMaterial()
            textMaterial.diffuse.contents = UIColor.white
            textMaterial.lightingModel = .constant
            text.materials = [textMaterial]

            let textNode = SCNNode(geometry: text)
            textNode.scale = SCNVector3(0.005, 0.005, 0.005)
            let (min, max) = textNode.boundingBox
            let textWidth = Float(max.x - min.x) * 0.005
            textNode.position = SCNVector3(-textWidth / 2, 0.04, 0)

            let billboard = SCNBillboardConstraint()
            billboard.freeAxes = [.Y]
            textNode.constraints = [billboard]
            containerNode.addChildNode(textNode)

            return containerNode
        }

        // MARK: - ARSCNViewDelegate

        func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
            guard let meshAnchor = anchor as? ARMeshAnchor else { return nil }

            let node = SCNNode()
            if let geometry = ARSessionManager.convertMeshToSCNGeometry(meshAnchor) {
                let material = SCNMaterial()
                material.diffuse.contents = UIColor.cyan.withAlphaComponent(0.1)
                material.isDoubleSided = true
                material.fillMode = .lines
                material.lightingModel = .constant
                geometry.materials = [material]
                node.geometry = geometry
            }
            meshNodes[meshAnchor.identifier] = node
            return node
        }

        func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
            guard let meshAnchor = anchor as? ARMeshAnchor else { return }
            if let geometry = ARSessionManager.convertMeshToSCNGeometry(meshAnchor) {
                let material = SCNMaterial()
                material.diffuse.contents = UIColor.cyan.withAlphaComponent(0.1)
                material.isDoubleSided = true
                material.fillMode = .lines
                material.lightingModel = .constant
                geometry.materials = [material]
                node.geometry = geometry
            }
        }
    }
}
