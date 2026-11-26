import ARKit
import SceneKit
import SwiftUI
import UIKit

struct ScannerView: View {
    @StateObject private var viewModel = ScannerViewModel()
    @State private var exportedURL: URL?
    @State private var showingExport = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingViewer = false
    @State private var savedMessage: String?
    @State private var showingSaved = false
    @State private var exportFormat: MeshExportFormat = .ply
    @State private var simplification: Double = 0.015

    var body: some View {
        ZStack {
            LiDARSceneView(viewModel: viewModel).ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.projectName).font(.headline)
                        Text(viewModel.status).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button { viewModel.reset() } label: {
                        Image(systemName: "arrow.counterclockwise").font(.headline).padding(12).background(.ultraThinMaterial, in: Circle())
                    }
                    .accessibilityLabel("Сбросить скан")
                }
                .padding().background(.ultraThinMaterial)

                Spacer()

                HStack(spacing: 12) {
                    metric(title: "Вершины", value: viewModel.vertexCount)
                    metric(title: "Треугольники", value: viewModel.triangleCount)
                    metric(title: "Области", value: viewModel.meshAnchorCount)
                }
                .padding().background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))

                HStack(spacing: 10) {
                    Button { showingViewer = true } label: {
                        Label("3D-просмотр", systemImage: "cube.transparent").frame(maxWidth: .infinity).padding(.vertical, 13).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(!viewModel.hasMesh)
                    Button(action: saveScan) {
                        Label("Сохранить", systemImage: "square.and.arrow.down").frame(maxWidth: .infinity).padding(.vertical, 13).background(Color.cyan, in: RoundedRectangle(cornerRadius: 14)).foregroundStyle(.black)
                    }
                    .disabled(!viewModel.hasMesh)
                }
                .font(.subheadline.bold()).padding(.top, 10)

                HStack(spacing: 8) {
                    Button(action: { viewModel.simplify(voxelSize: Float(simplification)) }) {
                        Label("Упростить", systemImage: "arrow.down.right.and.arrow.up.left").frame(maxWidth: .infinity).padding(.vertical, 12).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(!viewModel.hasMesh)
                    Button(action: exportScan) {
                        Label("Экспорт \(exportFormat.rawValue)", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity).padding(.vertical, 12).background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(!viewModel.hasMesh)
                }
                .font(.subheadline.bold()).padding(.top, 8)

                HStack {
                    Text("Упрощение сетки")
                    Slider(value: $simplification, in: 0.005...0.06, step: 0.005)
                    Text("\(Int(simplification * 1000)) мм").monospacedDigit().font(.caption)
                }
                .padding(.top, 8)

                Picker("Формат", selection: $exportFormat) {
                    ForEach(MeshExportFormat.allCases) { format in Text(format.rawValue).tag(format) }
                }
                .pickerStyle(.segmented).padding(.top, 6)
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingExport) { if let exportedURL { ActivityView(items: [exportedURL]) } }
        .sheet(isPresented: $showingViewer) {
            NavigationStack {
                ModelViewerView(mesh: viewModel.makeMesh(), title: viewModel.projectName)
                    .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Готово") { showingViewer = false } } }
            }
        }
        .alert("Скан сохранён", isPresented: $showingSaved) {
            Button("Просмотреть 3D-модель") { showingViewer = true }
            Button("Продолжить", role: .cancel) {}
        } message: { Text(savedMessage ?? "Модель добавлена в библиотеку.") }
        .alert("Ошибка", isPresented: $showingError) {
            Button("ОК", role: .cancel) {}
        } message: { Text(errorMessage) }
    }

    private func metric(title: String, value: Int) -> some View {
        VStack(spacing: 4) {
            Text(value.formatted()).font(.title3.monospacedDigit().bold())
            Text(title).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func saveScan() {
        do {
            let project = try ScanProjectStore.save(mesh: viewModel.makeMesh(), name: viewModel.projectName)
            savedMessage = "\(project.name) · \(project.vertexCount.formatted()) вершин"
            showingSaved = true
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }

    private func exportScan() {
        do {
            exportedURL = try MeshExportService.export(viewModel.makeMesh(), name: viewModel.projectName, format: exportFormat)
            showingExport = true
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
}

private struct LiDARSceneView: UIViewRepresentable {
    @ObservedObject var viewModel: ScannerViewModel
    func makeCoordinator() -> Coordinator { Coordinator(viewModel: viewModel) }

    func makeUIView(context: Context) -> ARSCNView {
        let view = ARSCNView(frame: .zero)
        view.automaticallyUpdatesLighting = true
        view.delegate = context.coordinator
        view.session.delegate = context.coordinator
        view.scene = SCNScene()
        guard ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) else {
            viewModel.setUnavailable("Это устройство не поддерживает LiDAR Mesh")
            return view
        }
        let configuration = ARWorldTrackingConfiguration()
        configuration.sceneReconstruction = ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification) ? .meshWithClassification : .mesh
        configuration.planeDetection = [.horizontal, .vertical]
        view.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        return view
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {}

    static func dismantleUIView(_ uiView: ARSCNView, coordinator: Coordinator) {
        uiView.session.pause()
        uiView.session.delegate = nil
        uiView.delegate = nil
    }

    final class Coordinator: NSObject, ARSCNViewDelegate, ARSessionDelegate {
        private let viewModel: ScannerViewModel
        init(viewModel: ScannerViewModel) { self.viewModel = viewModel }

        func session(_ session: ARSession, didAdd anchors: [ARAnchor]) { publish(anchors) }
        func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) { publish(anchors) }

        private func publish(_ anchors: [ARAnchor]) {
            let meshAnchors = anchors.filter { $0 is ARMeshAnchor }
            guard !meshAnchors.isEmpty else { return }
            let frame = session.currentFrame
            Task { @MainActor in viewModel.consume(anchors: meshAnchors, frame: frame) }
        }

        func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
            guard let mesh = anchor as? ARMeshAnchor else { return }
            node.geometry = makeGeometry(from: mesh)
        }

        func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
            guard let mesh = anchor as? ARMeshAnchor else { return }
            node.geometry = makeGeometry(from: mesh)
        }

        private func makeGeometry(from anchor: ARMeshAnchor) -> SCNGeometry {
            let mesh = anchor.geometry
            let vertices = mesh.vertices
            let length = max(0, (vertices.count - 1) * vertices.stride + MemoryLayout<SIMD3<Float>>.size)
            let pointer = vertices.buffer.contents().advanced(by: vertices.offset)
            let data = Data(bytes: pointer, count: length)
            let source = SCNGeometrySource(data: data, semantic: .vertex, vectorCount: vertices.count,
                usesFloatComponents: true, componentsPerVector: 3, bytesPerComponent: 4, dataOffset: 0, dataStride: vertices.stride)
            let faces = mesh.faces
            let faceLength = faces.count * faces.indexCountPerPrimitive * faces.bytesPerIndex
            let faceData = Data(bytes: faces.buffer.contents(), count: faceLength)
            let element = SCNGeometryElement(data: faceData, primitiveType: .triangles, primitiveCount: faces.count, bytesPerIndex: faces.bytesPerIndex)
            let geometry = SCNGeometry(sources: [source], elements: [element])
            let material = SCNMaterial()
            material.diffuse.contents = UIColor.systemCyan.withAlphaComponent(0.3)
            material.isDoubleSided = true
            material.fillMode = .lines
            geometry.firstMaterial = material
            return geometry
        }
    }
}

private struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: items, applicationActivities: nil) }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
