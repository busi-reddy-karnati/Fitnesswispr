import SwiftUI

@main
struct FitnesswisrApp: App {
    @StateObject private var prefs = UserPreferences()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(prefs)
        }
    }
}

struct RootView: View {
    @ObservedObject private var coordinator = QuickActionCoordinator.shared

    var body: some View {
        HomeView()
            .fullScreenCover(isPresented: $coordinator.showRecorder) {
                RecordView()
            }
    }
}
