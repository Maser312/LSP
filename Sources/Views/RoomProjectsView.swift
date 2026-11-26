import QuickLook
import SwiftUI

struct RoomProjectsView: View {
    @State private var projects: [RoomProject] = []
    @State private var previewURL: URL?
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if projects.isEmpty {
                ContentUnavailableView("Нет помещений", systemImage: "house", description: Text("Сохраняй результаты RoomPlan, и они появятся здесь."))
            } else {
                List {
                    ForEach(projects) { project in
                        HStack {
                            Image(systemName: "house.lodge.fill").font(.title2).foregroundStyle(.cyan)
                            VStack(alignment: .leading) {
                                Text(project.name).font(.headline)
                                Text(project.createdAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("3D") { previewURL = RoomArchiveStore.usdzURL(for: project) }
                                .buttonStyle(.bordered)
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                try? RoomArchiveStore.delete(project)
                                reload()
                            } label: { Label("Удалить", systemImage: "trash") }
                        }
                    }
                }
            }
        }
        .navigationTitle("Помещения")
        .onAppear(perform: reload)
        .sheet(item: Binding(
            get: { previewURL.map(PreviewItem.init) },
            set: { previewURL = $0?.url }
        )) { item in
            QuickLookPreview(item.url)
        }
        .alert("Ошибка", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("ОК", role: .cancel) { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    private func reload() {
        do { projects = try RoomArchiveStore.all() }
        catch { errorMessage = error.localizedDescription }
    }
}

private struct PreviewItem: Identifiable {
    let id = UUID()
    let url: URL
}
