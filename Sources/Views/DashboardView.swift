import SwiftUI

struct DashboardView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("LiDAR Scanner").font(.largeTitle.bold())
                        Text("Пространство вокруг тебя. В трёх измерениях.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    .padding(.top, 12)

                    NavigationLink {
                        ScannerView()
                    } label: {
                        ZStack(alignment: .bottomLeading) {
                            RoundedRectangle(cornerRadius: 28)
                                .fill(LinearGradient(
                                    colors: [Color.cyan.opacity(0.35), Color.blue.opacity(0.12), Color.black],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                ))
                            VStack(alignment: .leading, spacing: 12) {
                                Image(systemName: "view.3d").font(.system(size: 42, weight: .light))
                                Text("Новое сканирование").font(.title2.bold())
                                Text("Захват геометрии через LiDAR и ARKit")
                                    .font(.subheadline).foregroundStyle(.secondary)
                                Label("Начать", systemImage: "arrow.up.right")
                                    .font(.headline).padding(.top, 4)
                            }
                            .padding(24)
                        }
                        .frame(height: 230)
                        .overlay(RoundedRectangle(cornerRadius: 28).stroke(.white.opacity(0.12)))
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        ProjectsView()
                    } label: {
                        HStack(spacing: 16) {
                            Image(systemName: "square.stack.3d.up")
                                .font(.system(size: 30))
                                .foregroundStyle(.cyan)
                                .frame(width: 58, height: 58)
                                .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Мои сканы").font(.headline)
                                Text("Библиотека сохранённых 3D-моделей")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                        }
                        .padding(16)
                        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 20))
                    }
                    .buttonStyle(.plain)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Возможности").font(.title3.bold())
                        featureRow("3D-реконструкция", detail: "Сетка поверхностей в реальном времени", icon: "cube.transparent")
                        featureRow("3D-просмотр", detail: "Вращение, масштабирование, сдвиг и каркас", icon: "rotate.3d")
                        featureRow("Экспорт моделей", detail: "Сейчас PLY, следующие форматы в разработке", icon: "square.and.arrow.up")
                    }
                }
                .padding(20)
            }
            .background(Color.black)
            .toolbar(.hidden, for: .navigationBar)
        }
        .tint(.cyan)
    }

    private func featureRow(_ title: String, detail: String, icon: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon).font(.title2).foregroundStyle(.cyan)
                .frame(width: 42, height: 42)
                .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 16))
    }
}
