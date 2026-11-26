import SwiftUI

struct DashboardView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("LiDAR Scanner").font(.largeTitle.bold())
                        Text("Сканирование, измерение и экспорт 3D-моделей.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    .padding(.top, 12)

                    NavigationLink { ScannerView() } label: {
                        featureCard("Новое 3D-сканирование", detail: "Объекты и произвольные поверхности", icon: "view.3d", tint: .cyan)
                    }
                    .buttonStyle(.plain)

                    NavigationLink { RoomScannerView() } label: {
                        featureCard("Сканирование помещения", detail: "Стены, двери, окна и распознанные объекты через RoomPlan", icon: "house", tint: .orange)
                    }
                    .buttonStyle(.plain)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        NavigationLink { ProjectsView() } label: {
                            smallCard("3D-модели", detail: "Галерея сканов", icon: "cube.transparent")
                        }.buttonStyle(.plain)
                        NavigationLink { RoomProjectsView() } label: {
                            smallCard("Помещения", detail: "Проекты RoomPlan", icon: "house.lodge")
                        }.buttonStyle(.plain)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Инструменты модели").font(.title3.bold())
                        featureLine("Измерение расстояния", "Выбери две точки прямо на модели", "ruler")
                        featureLine("Площадь и объём", "Автоматический расчёт по треугольной сетке", "square.3.layers.3d")
                        featureLine("Упрощение сетки", "Уменьшение числа полигонов с сохранением формы", "arrow.down.right.and.arrow.up.left")
                        featureLine("Экспорт", "PLY · OBJ · STL · USDZ · GLB", "square.and.arrow.up")
                    }
                    .padding(16)
                    .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 20))
                }
                .padding(20)
            }
            .background(Color.black)
            .toolbar(.hidden, for: .navigationBar)
        }
        .tint(.cyan)
    }

    private func featureCard(_ title: String, detail: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon).font(.system(size: 34)).foregroundStyle(tint)
                .frame(width: 64, height: 64).background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 18))
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.headline)
                Text(detail).font(.caption).foregroundStyle(.secondary)
                Label("Открыть", systemImage: "arrow.up.right").font(.caption.bold()).padding(.top, 3)
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LinearGradient(colors: [tint.opacity(0.18), .white.opacity(0.035)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(.white.opacity(0.08)))
    }

    private func smallCard(_ title: String, detail: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon).font(.title2).foregroundStyle(.cyan)
            Text(title).font(.headline)
            Text(detail).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
        .padding(14)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 18))
    }

    private func featureLine(_ title: String, _ detail: String, _ icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(.cyan).frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.bold())
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
