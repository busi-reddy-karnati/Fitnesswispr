import SwiftUI
import PhotosUI

struct SettingsView: View {
    @StateObject private var prefs = UserPreferences()
    @ObservedObject private var health = HealthKitManager.shared
    @ObservedObject private var profile = ProfileStore.shared
    @State private var syncing = false
    @State private var photoItem: PhotosPickerItem?

    var body: some View {
        Form {
            profileSection
            spottersSection

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
        .onChange(of: photoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                    profile.setAvatar(data)
                }
            }
        }
    }

    private var profileSection: some View {
        Section("Profile") {
            HStack(spacing: 16) {
                PhotosPicker(selection: $photoItem, matching: .images) {
                    ZStack(alignment: .bottomTrailing) {
                        AvatarView(imageData: profile.avatarData, initials: profile.me.initials, size: 64)
                        Image(systemName: "pencil.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.white, Color.appAccent)
                    }
                }
                TextField("Your name", text: $profile.myName)
                    .textInputAutocapitalization(.words)
            }
            .padding(.vertical, 4)

            HStack {
                Text("Age")
                Spacer()
                TextField("—", value: $profile.age, format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
            }
            HStack {
                Text("Height")
                Spacer()
                TextField("—", value: $profile.heightCm, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                Text("cm").foregroundColor(.secondary)
            }
            HStack {
                Text("Body weight")
                Spacer()
                TextField("—", value: $profile.weightLbs, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                Text("lbs").foregroundColor(.secondary)
            }
        }
    }

    private var spottersSection: some View {
        Section {
            NavigationLink {
                SpottersView()
            } label: {
                HStack {
                    Label("Spotters", systemImage: "person.2.fill")
                    Spacer()
                    if !profile.linked.isEmpty {
                        Text("\(profile.linked.count)")
                            .foregroundColor(.secondary)
                    }
                }
            }
        } header: {
            Text("Sharing")
        } footer: {
            Text("Share your training with a spotter, or follow someone who shared theirs with you.")
        }
    }
}
