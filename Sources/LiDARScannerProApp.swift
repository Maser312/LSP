import SwiftUI

@main
struct LiDARScannerProApp: App {
    var body: some Scene {
        WindowGroup {
            DashboardView()
                .preferredColorScheme(.dark)
        }
    }
}
