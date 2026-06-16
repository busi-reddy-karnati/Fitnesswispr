import SwiftUI

struct SettingsView: View {
    @StateObject private var prefs = UserPreferences()
    @ObservedObject private var health = HealthKitManager.shared
    @State private var syncing = false

    var body: some View {
        Form {
            Section("Units") {
                Picker("Weight Unit", selection: $prefs.unitPreference) {
                    Text("lbs").tag("lbs")
                    Text("kg").tag("kg")
                }
                .pickerStyle(.segmented)
            }

            Section {
                if health.isAvailable {
                    Button {
                        syncing = true
                        Task {
                            await health.sync()
                            syncing = false
                        }
                    } label: {
                        HStack {
                            Label("Sync Apple Fitness", systemImage: "heart.fill")
                            Spacer()
                            if syncing { ProgressView() }
                            else if health.didSync {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }
                    }
                    .disabled(syncing)
                } else {
                    Text("Apple Health is not available on this device.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("Apple Fitness")
            } footer: {
                Text("Imports the days you worked out (and the category) from Apple Health into your consistency view.")
            }

            Section("Data") {
                ExportView()
            }

            Section("Device") {
                HStack {
                    Text("Device ID")
                    Spacer()
                    Text(String(DeviceUUID.shared.id.prefix(8)) + "...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}
