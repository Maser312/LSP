import RoomPlan
import SwiftUI
import UIKit

struct RoomScannerView: View {
    @State private var isScanning = true
    @State private var capturedRoom: CapturedRoom?
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var showShare = false
    @State private var shareURL: URL?
    @State private var roomName = "Новое помещение"

    var body: some View {
        ZStack(alignment: .bottom) {
            RoomCaptureContainer(isScanning: $isScanning) { room in
                capturedRoom = room
                isScanning = false
                isProcessing = false
            }
            .ignoresSafeArea()

            VStack(spacing: 12) {
                HStack {
                    Label("RoomPlan", systemImage: "view.3d")
                        .font(.headline)
                    Spacer()
                    Text(isScanning ? "Сканирование" : "Остановлено")
                        .font(.caption.bold())
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(.ultraThinMaterial, in: Capsule())
                }
                .padding()
                .background(.ultraThinMaterial)

                Spacer()

                if let capturedRoom {
                    VStack(spacing: 10) {
                        Text("Помещение распознано").font(.headline)
                        Text("\(capturedRoom.walls.count) стен · \(capturedRoom.doors.count) дверей · \(capturedRoom.windows.count) окон · \(capturedRoom.objects.count) объектов")
                            .font(.caption).foregroundStyle(.secondary)
                        Button("Сохранить помещение и USDZ") { save(capturedRoom) }
                            .buttonStyle(.borderedProminent)
                        Button("Новое сканирование") {
                            self.capturedRoom = nil
                            isScanning = true
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))
                } else {
                    Text(isScanning ? "Медленно обойди комнату, направляя камеру на стены и углы." : "Подготовка результата…")
                        .font(.subheadline)
                        .padding(16)
                        .frame(maxWidth: .infinity)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
                    Button {
                        isProcessing = true
                        isScanning = false
                    } label: {
                        Label("Завершить сканирование", systemImage: "stop.fill")
                            .frame(maxWidth: .infinity).padding()
                            .background(Color.cyan, in: RoundedRectangle(cornerRadius: 16))
                            .foregroundStyle(.black)
                    }
                    .disabled(!isScanning)
                }
            }
            .padding()
        }
        .navigationTitle("Сканирование помещения")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showShare) {
            if let shareURL { RoomShareSheet(items: [shareURL]) }
        }
        .alert("Ошибка", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("ОК", role: .cancel) { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    private func save(_ room: CapturedRoom) {
        do {
            let project = try RoomArchiveStore.save(room, name: roomName)
            shareURL = RoomArchiveStore.usdzURL(for: project)
            showShare = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct RoomCaptureContainer: UIViewRepresentable {
    @Binding var isScanning: Bool
    let onCaptured: (CapturedRoom) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onCaptured: onCaptured) }

    func makeUIView(context: Context) -> RoomCaptureView {
        let view = RoomCaptureView(frame: .zero)
        view.delegate = context.coordinator
        view.captureSession.run(configuration: RoomCaptureSession.Configuration())
        return view
    }

    func updateUIView(_ uiView: RoomCaptureView, context: Context) {
        if !isScanning && !context.coordinator.didStop {
            context.coordinator.didStop = true
            uiView.captureSession.stop(pauseARSession: false)
        }
    }

    static func dismantleUIView(_ uiView: RoomCaptureView, coordinator: Coordinator) {
        uiView.captureSession.stop(pauseARSession: true)
    }

    final class Coordinator: NSObject, RoomCaptureViewDelegate {
        let onCaptured: (CapturedRoom) -> Void
        var didStop = false
        init(onCaptured: @escaping (CapturedRoom) -> Void) { self.onCaptured = onCaptured }

        func captureView(shouldPresent roomDataForProcessing: CapturedRoomData, error: Error?) -> Bool {
            true
        }

        func captureView(didPresent room: CapturedRoom, error: Error?) {
            if let error { print("RoomPlan capture error: \(error.localizedDescription)") }
            DispatchQueue.main.async { self.onCaptured(room) }
        }
    }
}

private struct RoomShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
