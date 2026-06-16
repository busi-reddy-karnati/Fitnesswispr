import SwiftUI

struct SpottersView: View {
    @ObservedObject private var profile = ProfileStore.shared

    @State private var shareAccess: ProfileAccess = .write
    @State private var joinCode = ""
    @State private var joinError: String?
    @State private var joinedName: String?

    var body: some View {
        Form {
            shareSection
            joinSection
            if !profile.linked.isEmpty {
                followingSection
            }
        }
        .navigationTitle("Spotters")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Share my profile

    private var shareSection: some View {
        Section {
            Picker("They can", selection: $shareAccess) {
                Text("Log on my behalf").tag(ProfileAccess.write)
                Text("View only").tag(ProfileAccess.read)
            }
            .pickerStyle(.segmented)

            ShareLink(
                item: profile.inviteURL(grant: shareAccess),
                subject: Text("Be my spotter on SpotRep"),
                message: Text("Follow my training on SpotRep — open this link in the app.")
            ) {
                Label("Share invite", systemImage: "square.and.arrow.up")
            }
        } header: {
            Text("Add a spotter")
        } footer: {
            Text("Send the invite to a spotter. When they open it in SpotRep they'll be able to \(shareAccess == .write ? "view and log" : "view") your training.")
        }
    }

    // MARK: - Join someone

    private var joinSection: some View {
        Section {
            TextField("Paste invite code", text: $joinCode, axis: .vertical)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .lineLimit(1...3)

            Button("Add profile") {
                join()
            }
            .disabled(joinCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            if let joinError {
                Text(joinError).font(.caption).foregroundColor(.red)
            }
            if let joinedName {
                Label("Added \(joinedName)", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.green)
            }
        } header: {
            Text("Follow someone")
        } footer: {
            Text("Paste a code someone shared with you to see their training on your Home screen.")
        }
    }

    private func join() {
        joinError = nil
        joinedName = nil
        do {
            let p = try profile.redeem(joinCode)
            joinedName = p.name
            joinCode = ""
        } catch {
            joinError = error.localizedDescription
        }
    }

    // MARK: - Profiles I follow

    private var followingSection: some View {
        Section("Following") {
            ForEach(profile.linked) { p in
                HStack(spacing: 12) {
                    RemoteAvatarView(uuid: p.id, initials: p.initials, size: 36)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(p.name)
                        Text(p.access.label)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
            }
            .onDelete { offsets in
                let ids = offsets.map { profile.linked[$0].id }
                ids.forEach { profile.remove($0) }
            }
        }
    }
}
