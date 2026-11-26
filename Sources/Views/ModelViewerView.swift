import SceneKit
import SwiftUI
import simd
import UIKit

struct ModelViewerView: View {
    let mesh: ScanMesh
    let title: String

    @State private var wireframe = false
    @State private var selectedPoints: [SIMD3<Float>] = []

    private var measurements: MeshMeasurements { MeshMeasurements.calculate(mesh) }
    private var measuredDistance: Double? {
        guard selectedPoints.count >= 2 else { return nil }
        return MeshMeasurements.distance(selectedPoints[0], selectedPoints[1])
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.headline).lineLimit(1)
                    Text("\(mesh.vertices.count.formatted()) вершин · \(mesh.triangleCount.formatted()) треугольников")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button { wireframe.toggle() } label: {
                    Image(systemName: wireframe ? "square.3.layers.3d.down.right" : "square.3.layers.3d")
                        .font(.title3).padding(10).background(.thinMaterial, in: Circle())
                }
                .accessibilityLabel(wireframe ? "Показать поверхность" : "Показать каркас")
            }
            .padding()

            SceneKitModelView(mesh: mesh, wireframe: wireframe, selectedPoints: $selectedPoints)
                .background(Color.black)

            VStack(spacing: 8) {
                HStack {
                    Label("Площадь", systemImage: "square.dashed")
                    Spacer()
                    Text("\(measurements.surfaceAreaSquareMeters, specifier: "%.3f") м²")
                        .monospacedDigit().bold()
                }
                HStack {
                    Label("Объём*", systemImage: "cube")
                    Spacer()
                    Text("\(measurements.volumeCubicMeters, specifier: "%.3f") м³")
                        .monospacedDigit().bold()
                }
                HStack {
                    Label("Расстояние", systemImage: "ruler")
                    Spacer()
                    Text(measuredDistance.map { String(format: "%.3f м", $0) } ?? "Выбери две точки")
                        .monospacedDigit().bold()
                }
                HStack {
                    Text("*Объём корректен для замкнутой сетки")
                        .font(.caption2).foregroundStyle(.secondary)
                    Spacer()
                    Button("Сбросить точки") { selectedPoints.removeAll() }
                        .font(.caption)
                }
            }
            .padding()
            .background(.ultraThinMaterial)
        }
        .background(Color(uiColor: .secondarySystemBackground))
        .navigationTitle("3D-просмотр")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct SceneKitModelView: UIViewRepresentable {
    let mesh: ScanMesh
    let wireframe: Bool
    @Binding var selectedPoints: [SIMD3<Float>]

    func makeCoordinator() -> Coordinator { Coordinator(selectedPoints: $selectedPoints) }

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
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.didTap(_:)))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
        context.coordinator.sceneView = view
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        context.coordinator.selectedPoints = $selectedPoints
        context.coordinator.setWireframe(wireframe)
    }

    final class Coordinator: NSObject {
        var selectedPoints: Binding<[SIMD3<Float>]>
        weak var sceneView: SCNView?
        private weak var modelNode: SCNNode?

        init(selectedPoints: Binding<[SIMD3<Float>]>) { self.selectedPoints = selectedPoints }

        @objc func didTap(_ recognizer: UITapGestureRecognizer) {
            guard let view = sceneView else { return }
            let hits = view.hitTest(recognizer.location(in: view), options: [.searchMode: SCNHitTestSearchMode.closest.rawValue])
            guard let point = hits.first?.worldCoordinates else { return }
            var points = selectedPoints.wrappedValue
            if points.count == 2 { points.removeAll() }
            points.append(SIMD3<Float>(point.x, point.y, point.z))
            selectedPoints.wrappedValue = points
        }

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
            let extent = max(bounds.max.x - bounds.min.x, max(bounds.max.y - bounds.min.y, bounds.max.z - bounds.min.z))
            let distance = max(extent * 2.2, 0.35)
            let cameraNode = SCNNode()
            cameraNode.camera = SCNCamera()
            cameraNode.camera?.zNear = 0.001
            cameraNode.camera?.zFar = CGFloat(max(1000, Double(distance) * 100))
            cameraNode.position = SCNVector3(center.x, center.y, center.z + distance)
            cameraNode.look(at: center)
            view.scene?.rootNode.addChildNode(cameraNode)
            view.pointOfView = cameraNode
            view.defaultCameraController.target = center
        }

        func setWireframe(_ enabled: Bool) {
            modelNode?.geometry?.materials.first?.fillMode = enabled ? .lines : .fill
            modelNode?.geometry?.materials.first?.lightingModel = .constant
        }

        private func meshBounds(_ mesh: ScanMesh) -> (min: SIMD3<Float>, max: SIMD3<Float>) {
            guard let first = mesh.vertices.first else { return (.zero, SIMD3<Float>(repeating: 1)) }
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
            for p in mesh.vertices { floats.append(contentsOf: [p.x, p.y, p.z]) }
            let vertexData = floats.withUnsafeBufferPointer { Data(buffer: $0) }
            let source = SCNGeometrySource(data: vertexData, semantic: .vertex, vectorCount: mesh.vertices.count,
                usesFloatComponents: true, componentsPerVector: 3, bytesPerComponent: 4, dataOffset: 0, dataStride: 12)

            var indexData = Data()
            for index in mesh.faces {
                var value = index.littleEndian
                withUnsafeBytes(of: &value) { indexData.append(contentsOf: $0) }
            }
            let element = SCNGeometryElement(data: indexData, primitiveType: .triangles,
                primitiveCount: mesh.triangleCount, bytesPerIndex: 4)
            var sources = [source]
            if mesh.hasColors {
                var colorFloats: [Float] = []
                for color in mesh.colors { colorFloats.append(contentsOf: [color.x, color.y, color.z, color.w]) }
                let colorData = colorFloats.withUnsafeBufferPointer { Data(buffer: $0) }
                sources.append(SCNGeometrySource(data: colorData, semantic: .color, vectorCount: mesh.colors.count,
                    usesFloatComponents: true, componentsPerVector: 4, bytesPerComponent: 4, dataOffset: 0, dataStride: 16))
            }
            let geometry = SCNGeometry(sources: sources, elements: [element])
            let material = SCNMaterial()
            material.diffuse.contents = UIColor.white
            material.lightingModel = .physicallyBased
            material.isDoubleSided = true
            geometry.materials = [material]
            return geometry
        }
    }
}
