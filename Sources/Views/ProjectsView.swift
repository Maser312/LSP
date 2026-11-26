import SwiftUI

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
                ContentUnavailableView(
                    "Пока нет сканов",
                    systemImage: "cube.transparent",
                    description: Text("Создай сканирование, сохрани модель, и она появится здесь.")
                )
            } else {
                List {
                    ForEach(projects) { project in
                        NavigationLink {
                            ProjectDetailView(project: project)
                        } label: {
                            ProjectRow(project: project)
                        }
                        .listRowBackground(Color(uiColor: .secondarySystemBackground))
                        .swipeActions {
                            Button(role: .destructive) {
                                delete(project)
                            } label: {
                                Label("Удалить", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Мои сканы")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    reload()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .accessibilityLabel("Обновить библиотеку")
            }
        }
        .task { reload() }
    }

    private func reload() {
        isLoading = true
        do {
            projects = try ScanProjectStore.allProjects()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func delete(_ project: ScanProject) {
        do {
            try ScanProjectStore.delete(project)
            projects.removeAll { $0.id == project.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct ProjectRow: View {
    let project: ScanProject

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(LinearGradient(colors: [.cyan.opacity(0.3), .blue.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing))
                Image(systemName: "cube.transparent")
                    .font(.title2)
                    .foregroundStyle(.cyan)
            }
            .frame(width: 58, height: 58)

            VStack(alignment: .leading, spacing: 5) {
                Text(project.name).font(.headline).lineLimit(1)
                Text(project.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption).foregroundStyle(.secondary)
                Text("\(project.vertexCount.formatted()) вершин · \(project.triangleCount.formatted()) треугольников")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
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
            do {
                mesh = try ScanProjectStore.load(project)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
