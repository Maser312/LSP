import SceneKit
import SwiftUI
import UIKit

struct ModelViewerView: View {
    let mesh: ScanMesh
    let title: String

    @State private var wireframe = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.headline).lineLimit(1)
                    Text("\(mesh.vertices.count.formatted()) вершин · \(mesh.triangleCount.formatted()) треугольников")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    wireframe.toggle()
                } label: {
                    Image(systemName: wireframe ? "square.3.layers.3d.down.right" : "square.3.layers.3d")
                        .font(.title3)
                        .padding(10)
                        .background(.thinMaterial, in: Circle())
                }
                .accessibilityLabel(wireframe ? "Показать поверхность" : "Показать каркас")
            }
            .padding()

            SceneKitModelView(mesh: mesh, wireframe: wireframe)
                .background(Color.black)

            HStack(spacing: 18) {
                Label("Вращение", systemImage: "rotate.3d")
                Label("Масштаб", systemImage: "plus.magnifyingglass")
                Label("Сдвиг", systemImage: "hand.draw")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.vertical, 14)
        }
        .background(Color(uiColor: .secondarySystemBackground))
        .navigationTitle("3D-просмотр")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct SceneKitModelView: UIViewRepresentable {
    let mesh: ScanMesh
    let wireframe: Bool

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView(frame: .zero)
        view.backgroundColor = .black
        view.scene = SCNScene()
        view.allowsCameraControl = true
        view.autoenablesDefaultLighting = true
        view.antialiasingMode = .multisampling4X
        view.defaultCameraController.interactionMode = .orbitTurntable
        view.defaultCameraController.inertiaEnabled = true
        view.defaultCameraController.maximumVerticalAngle = 88
        context.coordinator.install(mesh: mesh, in: view)
        context.coordinator.setWireframe(wireframe)
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        context.coordinator.setWireframe(wireframe)
    }

    final class Coordinator {
        private weak var modelNode: SCNNode?

        func install(mesh: ScanMesh, in view: SCNView) {
            let geometry = Self.geometry(from: mesh)
            let node = SCNNode(geometry: geometry)
            view.scene?.rootNode.addChildNode(node)
            modelNode = node

            let bounds = meshBounds(mesh)
            let center = SCNVector3(
                (bounds.min.x + bounds.max.x) / 2,
                (bounds.min.y + bounds.max.y) / 2,
                (bounds.min.z + bounds.max.z) / 2
            )
            let extent = max(
                bounds.max.x - bounds.min.x,
                max(bounds.max.y - bounds.min.y, bounds.max.z - bounds.min.z)
            )
            let distance = max(extent * 2.2, 0.35)
            let cameraNode = SCNNode()
            cameraNode.camera = SCNCamera()
            cameraNode.camera?.zNear = 0.001
            cameraNode.camera?.zFar = max(1000, Double(distance) * 100)
            cameraNode.position = SCNVector3(center.x, center.y, center.z + distance)
            cameraNode.look(at: center)
            view.scene?.rootNode.addChildNode(cameraNode)
            view.pointOfView = cameraNode
            view.defaultCameraController.target = center
        }

        func setWireframe(_ enabled: Bool) {
            modelNode?.geometry?.firstMaterial?.fillMode = enabled ? .lines : .fill
            modelNode?.geometry?.firstMaterial?.diffuse.contents = enabled
                ? UIColor.systemTeal.withAlphaComponent(0.9)
                : UIColor.systemTeal.withAlphaComponent(0.82)
        }

        private func meshBounds(_ mesh: ScanMesh) -> (min: SIMD3<Float>, max: SIMD3<Float>) {
            guard let first = mesh.vertices.first else {
                return (.zero, SIMD3<Float>(repeating: 1))
            }
            var minimum = first
            var maximum = first
            for vertex in mesh.vertices.dropFirst() {
                minimum = simd_min(minimum, vertex)
                maximum = simd_max(maximum, vertex)
            }
            return (minimum, maximum)
        }

        private static func geometry(from mesh: ScanMesh) -> SCNGeometry {
            var floats: [Float] = []
            floats.reserveCapacity(mesh.vertices.count * 3)
            for vertex in mesh.vertices {
                floats.append(vertex.x)
                floats.append(vertex.y)
                floats.append(vertex.z)
            }
            let vertexData = floats.withUnsafeBufferPointer { Data(buffer: $0) }
            let source = SCNGeometrySource(
                data: vertexData,
                semantic: .vertex,
                vectorCount: mesh.vertices.count,
                usesFloatComponents: true,
                componentsPerVector: 3,
                bytesPerComponent: MemoryLayout<Float>.size,
                dataOffset: 0,
                dataStride: MemoryLayout<Float>.size * 3
            )

            var indexData = Data()
            for index in mesh.faces {
                let value = index.littleEndian
                withUnsafeBytes(of: value) { indexData.append(contentsOf: $0) }
            }
            let element = SCNGeometryElement(
                data: indexData,
                primitiveType: .triangles,
                primitiveCount: mesh.faces.count / 3,
                bytesPerIndex: MemoryLayout<UInt32>.size
            )
            let geometry = SCNGeometry(sources: [source], elements: [element])
            let material = SCNMaterial()
            material.diffuse.contents = UIColor.systemTeal.withAlphaComponent(0.82)
            material.lightingModel = .physicallyBased
            material.metalness.contents = 0.12
            material.roughness.contents = 0.68
            material.isDoubleSided = true
            geometry.materials = [material]
            return geometry
        }
    }
}
