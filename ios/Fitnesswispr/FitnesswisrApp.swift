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
                AssistantView()
            }
            .onOpenURL { url in
                guard url.scheme == "spotrep" else { return }
                Task { @MainActor in
                    switch url.host {
                    case "chat":
                        coordinator.openChat()
                    case "record":
                        coordinator.triggerRecordNow()
                    default:
                        if let added = try? ProfileStore.shared.redeem(url.absoluteString) {
                            ProfileStore.shared.setActive(added.id)
                        }
                    }
                }
            }
    }
}
