// SpatialMapView.swift
// Interactive 3D map that visualizes the scanned environment mesh and tracked item locations

import SwiftUI
import SceneKit
import ARKit

struct SpatialMapView: UIViewRepresentable {
    @ObservedObject var sessionManager: ARSessionManager

    func makeUIView(context: Context) -> SCNView {
        let sceneView = SCNView()
        sceneView.scene = SCNScene()
        sceneView.backgroundColor = UIColor(white: 0.08, alpha: 1.0)
        sceneView.allowsCameraControl = true   // Orbit, pan, zoom
        sceneView.autoenablesDefaultLighting = true
        sceneView.antialiasingMode = .multisampling4X

        // Setup initial camera
        let cameraNode = SCNNode()
        cameraNode.name = "mapCamera"
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.zNear = 0.01
        cameraNode.camera?.zFar = 100
        cameraNode.camera?.fieldOfView = 60
        cameraNode.position = SCNVector3(0, 2, 3)
        cameraNode.look(at: SCNVector3(0, 0, 0))
        sceneView.scene?.rootNode.addChildNode(cameraNode)
        sceneView.pointOfView = cameraNode

        // Add ambient light
        let ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light?.type = .ambient
        ambientLight.light?.intensity = 500
        ambientLight.light?.color = UIColor(white: 0.6, alpha: 1.0)
        sceneView.scene?.rootNode.addChildNode(ambientLight)

        // Add directional light
        let directionalLight = SCNNode()
        directionalLight.light = SCNLight()
        directionalLight.light?.type = .directional
        directionalLight.light?.intensity = 800
        directionalLight.light?.color = UIColor.white
        directionalLight.position = SCNVector3(5, 10, 5)
        directionalLight.look(at: SCNVector3(0, 0, 0))
        sceneView.scene?.rootNode.addChildNode(directionalLight)

        // Add world origin indicator (small axes)
        let originNode = createOriginAxes()
        originNode.name = "worldOrigin"
        sceneView.scene?.rootNode.addChildNode(originNode)

        // Add device position indicator
        let deviceNode = createDeviceIndicator()
        deviceNode.name = "deviceIndicator"
        sceneView.scene?.rootNode.addChildNode(deviceNode)

        // Grid floor for reference
        let gridNode = createGridFloor()
        gridNode.name = "gridFloor"
        sceneView.scene?.rootNode.addChildNode(gridNode)

        // Start update timer
        context.coordinator.startUpdateTimer(sceneView: sceneView)

        return sceneView
    }

    func updateUIView(_ sceneView: SCNView, context: Context) {
        context.coordinator.sessionManager = sessionManager
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(sessionManager: sessionManager)
    }

    // MARK: - Scene Object Factories

    private func createOriginAxes() -> SCNNode {
        let container = SCNNode()
        let length: CGFloat = 0.15
        let radius: CGFloat = 0.003

        // X axis (red)
        let xAxis = SCNCylinder(radius: radius, height: length)
        xAxis.firstMaterial?.diffuse.contents = UIColor.systemRed
        xAxis.firstMaterial?.lightingModel = .constant
        let xNode = SCNNode(geometry: xAxis)
        xNode.position = SCNVector3(Float(length / 2), 0, 0)
        xNode.eulerAngles = SCNVector3(0, 0, -Float.pi / 2)
        container.addChildNode(xNode)

        // Y axis (green)
        let yAxis = SCNCylinder(radius: radius, height: length)
        yAxis.firstMaterial?.diffuse.contents = UIColor.systemGreen
        yAxis.firstMaterial?.lightingModel = .constant
        let yNode = SCNNode(geometry: yAxis)
        yNode.position = SCNVector3(0, Float(length / 2), 0)
        container.addChildNode(yNode)

        // Z axis (blue)
        let zAxis = SCNCylinder(radius: radius, height: length)
        zAxis.firstMaterial?.diffuse.contents = UIColor.systemBlue
        zAxis.firstMaterial?.lightingModel = .constant
        let zNode = SCNNode(geometry: zAxis)
        zNode.position = SCNVector3(0, 0, Float(length / 2))
        zNode.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)
        container.addChildNode(zNode)

        return container
    }

    private func createDeviceIndicator() -> SCNNode {
        // Cone pointing in camera direction
        let cone = SCNCone(topRadius: 0, bottomRadius: 0.03, height: 0.06)
        let material = SCNMaterial()
        material.diffuse.contents = UIColor.white
        material.emission.contents = UIColor.white.withAlphaComponent(0.5)
        material.lightingModel = .constant
        cone.materials = [material]

        let node = SCNNode(geometry: cone)
        // Rotate so the cone points forward (-Z)
        node.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)

        let container = SCNNode()
        container.addChildNode(node)

        // Field of view indicator lines
        let fovLength: Float = 0.12
        let fovSpread: Float = 0.06
        let linePositions: [(Float, Float)] = [
            (-fovSpread, -fovSpread), (fovSpread, -fovSpread),
            (-fovSpread, fovSpread), (fovSpread, fovSpread)
        ]
        for (x, y) in linePositions {
            let lineGeo = SCNCylinder(radius: 0.001, height: CGFloat(fovLength))
            lineGeo.firstMaterial?.diffuse.contents = UIColor.white.withAlphaComponent(0.4)
            lineGeo.firstMaterial?.lightingModel = .constant
            let lineNode = SCNNode(geometry: lineGeo)
            lineNode.position = SCNVector3(x / 2, y / 2, -fovLength / 2)
            lineNode.look(at: SCNVector3(x, y, -fovLength))
            container.addChildNode(lineNode)
        }

        return container
    }

    private func createGridFloor() -> SCNNode {
        let container = SCNNode()
        let gridSize: Int = 10
        let spacing: Float = 0.5

        for i in -gridSize...gridSize {
            // Lines along X
            let xLine = SCNCylinder(radius: 0.001, height: CGFloat(Float(gridSize * 2) * spacing))
            xLine.firstMaterial?.diffuse.contents = UIColor.gray.withAlphaComponent(0.15)
            xLine.firstMaterial?.lightingModel = .constant
            let xNode = SCNNode(geometry: xLine)
            xNode.position = SCNVector3(0, 0, Float(i) * spacing)
            xNode.eulerAngles = SCNVector3(0, 0, Float.pi / 2)
            container.addChildNode(xNode)

            // Lines along Z
            let zLine = SCNCylinder(radius: 0.001, height: CGFloat(Float(gridSize * 2) * spacing))
            zLine.firstMaterial?.diffuse.contents = UIColor.gray.withAlphaComponent(0.15)
            zLine.firstMaterial?.lightingModel = .constant
            let zNode = SCNNode(geometry: zLine)
            zNode.position = SCNVector3(Float(i) * spacing, 0, 0)
            zNode.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)
            container.addChildNode(zNode)
        }

        return container
    }

    // MARK: - Coordinator

    class Coordinator {
        var sessionManager: ARSessionManager
        private var meshNodes: [UUID: SCNNode] = [:]
        private var itemNodes: [UUID: SCNNode] = [:]
        private var updateTimer: Timer?
        private weak var sceneView: SCNView?

        init(sessionManager: ARSessionManager) {
            self.sessionManager = sessionManager
        }

        deinit {
            updateTimer?.invalidate()
        }

        func startUpdateTimer(sceneView: SCNView) {
            self.sceneView = sceneView

            // Update the 3D map every 0.3 seconds
            updateTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
                self?.updateScene()
            }
        }

        private func updateScene() {
            guard let scene = sceneView?.scene else { return }

            updateMeshNodes(in: scene)
            updateItemNodes(in: scene)
            updateDevicePosition(in: scene)
        }

        // MARK: - Mesh Update

        private func updateMeshNodes(in scene: SCNScene) {
            let currentAnchors = sessionManager.meshAnchors
            let currentIds = Set(currentAnchors.map { $0.identifier })

            // Remove stale mesh nodes
            for (id, node) in meshNodes where !currentIds.contains(id) {
                node.removeFromParentNode()
                meshNodes.removeValue(forKey: id)
            }

            // Add/update mesh nodes
            for anchor in currentAnchors {
                if let existingNode = meshNodes[anchor.identifier] {
                    // Update geometry
                    if let geometry = ARSessionManager.convertMeshToSCNGeometry(anchor) {
                        existingNode.geometry = geometry
                    }
                    existingNode.simdTransform = anchor.transform
                } else {
                    // Create new mesh node
                    if let geometry = ARSessionManager.convertMeshToSCNGeometry(anchor) {
                        let node = SCNNode(geometry: geometry)
                        node.simdTransform = anchor.transform
                        scene.rootNode.addChildNode(node)
                        meshNodes[anchor.identifier] = node
                    }
                }
            }
        }

        // MARK: - Item Markers Update

        private func updateItemNodes(in scene: SCNScene) {
            let currentItems = sessionManager.trackedItems
            let currentIds = Set(currentItems.map { $0.id })

            // Remove deleted item nodes
            for (id, node) in itemNodes where !currentIds.contains(id) {
                node.removeFromParentNode()
                itemNodes.removeValue(forKey: id)
            }

            // Add/update item markers
            for item in currentItems {
                if let existingNode = itemNodes[item.id] {
                    // Smooth position update
                    SCNTransaction.begin()
                    SCNTransaction.animationDuration = 0.3
                    existingNode.simdPosition = item.position
                    existingNode.opacity = item.isActivelyTracked ? 1.0 : 0.5
                    SCNTransaction.commit()
                } else {
                    let node = createMapItemNode(for: item)
                    scene.rootNode.addChildNode(node)
                    itemNodes[item.id] = node
                }
            }
        }

        private func createMapItemNode(for item: TrackedItem) -> SCNNode {
            let container = SCNNode()
            container.simdPosition = item.position

            // Sphere marker
            let sphere = SCNSphere(radius: 0.04)
            let material = SCNMaterial()
            material.diffuse.contents = item.uiColor
            material.emission.contents = item.uiColor.withAlphaComponent(0.6)
            material.lightingModel = .physicallyBased
            sphere.materials = [material]
            let sphereNode = SCNNode(geometry: sphere)
            container.addChildNode(sphereNode)

            // Vertical pillar from floor to item (helps visualize height)
            let pillarHeight = max(0.01, item.position.y)
            let pillar = SCNCylinder(radius: 0.003, height: CGFloat(pillarHeight))
            let pillarMaterial = SCNMaterial()
            pillarMaterial.diffuse.contents = item.uiColor.withAlphaComponent(0.3)
            pillarMaterial.lightingModel = .constant
            pillar.materials = [pillarMaterial]
            let pillarNode = SCNNode(geometry: pillar)
            pillarNode.position = SCNVector3(0, -pillarHeight / 2, 0)
            container.addChildNode(pillarNode)

            // Floor dot
            let dot = SCNCylinder(radius: 0.02, height: 0.002)
            dot.firstMaterial?.diffuse.contents = item.uiColor.withAlphaComponent(0.4)
            dot.firstMaterial?.lightingModel = .constant
            let dotNode = SCNNode(geometry: dot)
            dotNode.position = SCNVector3(0, -pillarHeight, 0)
            container.addChildNode(dotNode)

            // Label
            let text = SCNText(string: item.name, extrusionDepth: 0.3)
            text.font = UIFont.systemFont(ofSize: 3, weight: .bold)
            text.flatness = 0.1
            let textMat = SCNMaterial()
            textMat.diffuse.contents = UIColor.white
            textMat.lightingModel = .constant
            text.materials = [textMat]

            let textNode = SCNNode(geometry: text)
            textNode.scale = SCNVector3(0.008, 0.008, 0.008)
            let (tMin, tMax) = textNode.boundingBox
            let textWidth = Float(tMax.x - tMin.x) * 0.008
            textNode.position = SCNVector3(-textWidth / 2, 0.06, 0)

            let billboard = SCNBillboardConstraint()
            billboard.freeAxes = [.Y]
            textNode.constraints = [billboard]
            container.addChildNode(textNode)

            // Entry animation
            container.scale = SCNVector3(0.01, 0.01, 0.01)
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.5
            SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeOut)
            container.scale = SCNVector3(1, 1, 1)
            SCNTransaction.commit()

            return container
        }

        // MARK: - Device Position Update

        private func updateDevicePosition(in scene: SCNScene) {
            guard let deviceNode = scene.rootNode.childNode(
                withName: "deviceIndicator", recursively: false
            ) else { return }

            let transform = sessionManager.cameraTransform

            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.15
            deviceNode.simdTransform = transform
            SCNTransaction.commit()
        }
    }
}
