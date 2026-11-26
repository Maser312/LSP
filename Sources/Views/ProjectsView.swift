import SceneKit
import SwiftUI
import simd
import UIKit

struct ProjectsView: View {
    @State private var projects: [ScanProject] = []
    @State private var errorMessage: String?
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Загрузка проектов…")
            } else if let errorMessage {
                ContentUnavailableView("Не удалось открыть библиотеку", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
            } else if projects.isEmpty {
                ContentUnavailableView("Пока нет сканов", systemImage: "cube.transparent", description: Text("Создай сканирование, сохрани модель, и она появится здесь."))
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                        ForEach(projects) { project in
                            NavigationLink {
                                ProjectDetailView(project: project)
                            } label: {
                                ProjectCard(project: project)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) { delete(project) } label: {
                                    Label("Удалить", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Мои сканы")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: reload) { Image(systemName: "arrow.clockwise") }
            }
        }
        .task { reload() }
    }

    private func reload() {
        isLoading = true
        do { projects = try ScanProjectStore.allProjects(); errorMessage = nil }
        catch { errorMessage = error.localizedDescription }
        isLoading = false
    }

    private func delete(_ project: ScanProject) {
        do { try ScanProjectStore.delete(project); projects.removeAll { $0.id == project.id } }
        catch { errorMessage = error.localizedDescription }
    }
}

private struct ProjectCard: View {
    let project: ScanProject
    @State private var thumbnail: UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Group {
                if let thumbnail {
                    Image(uiImage: thumbnail).resizable().scaledToFill()
                } else {
                    ZStack {
                        LinearGradient(colors: [.cyan.opacity(0.28), .blue.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        Image(systemName: "cube.transparent").font(.system(size: 42)).foregroundStyle(.cyan)
                    }
                }
            }
            .frame(height: 130).frame(maxWidth: .infinity).clipped().clipShape(RoundedRectangle(cornerRadius: 14))
            Text(project.name).font(.headline).lineLimit(1)
            Text(project.createdAt.formatted(date: .abbreviated, time: .shortened)).font(.caption2).foregroundStyle(.secondary)
            Text("\(project.vertexCount.formatted()) вершин · \(project.triangleCount.formatted()) треугольников")
                .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
        }
        .padding(10)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 18))
        .task {
            guard let mesh = try? ScanProjectStore.load(project) else { return }
            thumbnail = MeshThumbnailRenderer.render(mesh)
        }
    }
}

private struct ProjectDetailView: View {
    let project: ScanProject
    @State private var mesh: ScanMesh?
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let mesh {
                ModelViewerView(mesh: mesh, title: project.name)
            } else if let errorMessage {
                ContentUnavailableView("Не удалось загрузить модель", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
            } else {
                ProgressView("Загрузка 3D-модели…")
            }
        }
        .task {
            do { mesh = try ScanProjectStore.load(project) }
            catch { errorMessage = error.localizedDescription }
        }
    }
}

private enum MeshThumbnailRenderer {
    static func render(_ mesh: ScanMesh) -> UIImage? {
        guard !mesh.vertices.isEmpty, mesh.faces.count >= 3 else { return nil }
        let scene = SCNScene()
        let points = mesh.vertices
        let center = points.reduce(SIMD3<Float>.zero, +) / Float(points.count)
        let centered = points.map { $0 - center }
        var floats: [Float] = []
        for p in centered { floats.append(contentsOf: [p.x, p.y, p.z]) }
        let source = SCNGeometrySource(data: floats.withUnsafeBufferPointer { Data(buffer: $0) },
            semantic: .vertex, vectorCount: points.count, usesFloatComponents: true,
            componentsPerVector: 3, bytesPerComponent: 4, dataOffset: 0, dataStride: 12)
        var indices = Data()
        for index in mesh.faces { var v = index.littleEndian; withUnsafeBytes(of: &v) { indices.append(contentsOf: $0) } }
        let element = SCNGeometryElement(data: indices, primitiveType: .triangles, primitiveCount: mesh.triangleCount, bytesPerIndex: 4)
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
        material.diffuse.contents = UIColor.systemTeal
        material.isDoubleSided = true
        geometry.firstMaterial = material
        scene.rootNode.addChildNode(SCNNode(geometry: geometry))
        let radius = max(points.map { simd_length($0 - center) }.max() ?? 0.5, 0.2)
        let camera = SCNNode()
        camera.camera = SCNCamera()
        camera.position = SCNVector3(radius * 2, radius * 1.4, radius * 2)
        camera.look(at: SCNVector3Zero)
        scene.rootNode.addChildNode(camera)
        let renderer = SCNRenderer(device: nil, options: nil)
        renderer.scene = scene
        renderer.pointOfView = camera
        return renderer.snapshot(atTime: 0, with: CGSize(width: 420, height: 320), antialiasingMode: .multisampling4X)
    }
}
