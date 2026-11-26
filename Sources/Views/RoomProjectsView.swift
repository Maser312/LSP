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
        .sheet(isPresented: Binding(get: { previewURL != nil }, set: { if !$0 { previewURL = nil } })) {
            if let previewURL { RoomUSDZPreview(url: previewURL) }
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

private struct RoomUSDZPreview: UIViewControllerRepresentable {
    let url: URL
    func makeCoordinator() -> Coordinator { Coordinator(url: url) }
    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }
    func updateUIViewController(_ controller: QLPreviewController, context: Context) {}
    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        let url: URL
        init(url: URL) { self.url = url }
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            url as NSURL
        }
    }
}
