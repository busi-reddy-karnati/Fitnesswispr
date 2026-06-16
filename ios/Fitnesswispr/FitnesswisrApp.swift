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
                        coordinator.handleInvite(url.absoluteString)
                    }
                }
            }
            .alert(
                coordinator.joinOutcome?.title ?? "",
                isPresented: Binding(
                    get: { coordinator.joinOutcome != nil },
                    set: { if !$0 { coordinator.joinOutcome = nil } }
                ),
                presenting: coordinator.joinOutcome
            ) { _ in
                Button("OK", role: .cancel) {}
            } message: { outcome in
                Text(outcome.message)
            }
    }
}
