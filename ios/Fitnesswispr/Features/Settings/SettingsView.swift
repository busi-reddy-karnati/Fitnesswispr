import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var prefs: UserPreferences

    var body: some View {
        NavigationStack {
            Form {
                Section("Units") {
                    Picker("Weight Unit", selection: $prefs.unitPreference) {
                        Text("lbs").tag("lbs")
                        Text("kg").tag("kg")
                    }
                    .pickerStyle(.segmented)
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
        }
    }
}
