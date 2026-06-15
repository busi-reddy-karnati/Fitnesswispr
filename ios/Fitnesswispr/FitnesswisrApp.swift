import SwiftUI

@main
struct FitnesswisrApp: App {
    @StateObject private var prefs = UserPreferences()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(prefs)
        }
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Home", systemImage: "house.fill") }

            RecordView()
                .tabItem { Label("Record", systemImage: "mic.fill") }

            CalendarView()
                .tabItem { Label("Calendar", systemImage: "calendar") }

            HistoryView()
                .tabItem { Label("History", systemImage: "clock.fill") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
    }
}
