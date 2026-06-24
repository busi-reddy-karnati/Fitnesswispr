import SwiftUI
import PhotosUI
import AuthenticationServices

struct SettingsView: View {
    @StateObject private var prefs = UserPreferences()
    @ObservedObject private var health = HealthKitManager.shared
    @ObservedObject private var profile = ProfileStore.shared
    @ObservedObject private var account = AccountStore.shared
    @State private var syncing = false
    @State private var photoItem: PhotosPickerItem?
    @State private var authError: String?
    @State private var showDeleteConfirm = false
    @State private var isDeleting = false
    @State private var deleteError: String?

    var body: some View {
        Form {
            profileSection
            accountSection
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

    @ViewBuilder
    private var accountSection: some View {
        Section {
            if let acc = account.account {
                HStack {
                    Label("Signed in", systemImage: "checkmark.seal.fill")
                        .foregroundColor(.green)
                    Spacer()
                    if let email = acc.email {
                        Text(email)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Button(role: .destructive) {
                    account.signOut()
                } label: {
                    Text("Sign out")
                }
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    HStack {
                        Text("Delete Account")
                        Spacer()
                        if isDeleting { ProgressView() }
                    }
                }
                .disabled(isDeleting)
            } else {
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    handleAppleSignIn(result)
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 44)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }
        } header: {
            Text("Account")
        } footer: {
            Text(account.isSignedIn
                 ? "Your workouts are backed up to your account and sync across your devices. Deleting your account permanently removes your account and all of its data from our servers."
                 : "Sign in to back up your workouts and access them on any device. Optional, your data stays on this device until you do.")
        }
        .alert("Sign-in failed", isPresented: .constant(authError != nil)) {
            Button("OK") { authError = nil }
        } message: {
            Text(authError ?? "")
        }
        .confirmationDialog(
            "Delete your account?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete Account", role: .destructive) { deleteAccount() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently deletes your account and all of your workout data from our servers. This cannot be undone.")
        }
        .alert("Couldn't delete account", isPresented: .constant(deleteError != nil)) {
            Button("OK") { deleteError = nil }
        } message: {
            Text(deleteError ?? "")
        }
    }

    private func deleteAccount() {
        isDeleting = true
        Task {
            do {
                try await account.deleteAccount()
            } catch {
                deleteError = error.localizedDescription
            }
            isDeleting = false
        }
    }

    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let token = String(data: tokenData, encoding: .utf8) else {
                authError = "Apple didn't return a valid identity token."
                return
            }
            let name = [credential.fullName?.givenName, credential.fullName?.familyName]
                .compactMap { $0 }
                .joined(separator: " ")
            Task {
                do {
                    try await account.signInWithApple(
                        identityToken: token,
                        fullName: name.isEmpty ? nil : name
                    )
                    if profile.myName.isEmpty, !name.isEmpty {
                        profile.myName = name
                    }
                } catch {
                    authError = error.localizedDescription
                }
            }
        case .failure(let error):
            // User cancelling isn't an error worth surfacing.
            if (error as? ASAuthorizationError)?.code != .canceled {
                authError = error.localizedDescription
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
