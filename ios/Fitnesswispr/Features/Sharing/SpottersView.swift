import SwiftUI
import UIKit

struct SpottersView: View {
    @ObservedObject private var profile = ProfileStore.shared

    @State private var shareAccess: ProfileAccess = .write
    @State private var joinCode = ""
    @State private var joinError: String?
    @State private var joinedName: String?
    @State private var copiedCode = false

    @State private var pendingRevoke: Grantee?

    var body: some View {
        Form {
            shareSection
            if !profile.grantees.isEmpty {
                accessSection
            }
            joinSection
            if !profile.linked.isEmpty {
                followingSection
            }
        }
        .navigationTitle("Spotters")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { profile.loadGrantees() }
        .confirmationDialog(
            "Revoke access?",
            isPresented: Binding(get: { pendingRevoke != nil }, set: { if !$0 { pendingRevoke = nil } }),
            presenting: pendingRevoke
        ) { g in
            Button("Revoke \(g.displayName)'s access", role: .destructive) {
                profile.revokeGrant(g)
            }
            Button("Cancel", role: .cancel) {}
        } message: { g in
            Text("\(g.displayName) will no longer be able to see\(g.access == "write" ? " or log" : "") your training.")
        }
    }

    // MARK: - People with access to me

    private var accessSection: some View {
        Section {
            ForEach(profile.grantees) { g in
                HStack(spacing: 12) {
                    RemoteAvatarView(uuid: g.granteeUuid, initials: initials(g.displayName), size: 36)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(g.displayName)
                        Text(g.access == "write" ? "Can view & log" : "View only")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button("Revoke", role: .destructive) { pendingRevoke = g }
                        .buttonStyle(.borderless)
                        .font(.caption)
                }
                .swipeActions {
                    Button("Revoke", role: .destructive) { pendingRevoke = g }
                }
            }
        } header: {
            Text("People with access to you")
        } footer: {
            Text("These spotters can see your training. Revoke any time.")
        }
    }

    private func initials(_ name: String) -> String {
        let parts = name.split(separator: " ").prefix(2)
        let s = parts.compactMap { $0.first }.map(String.init).joined().uppercased()
        return s.isEmpty ? "?" : s
    }

    // MARK: - Share my profile

    private var shareSection: some View {
        Section {
            Picker("They can", selection: $shareAccess) {
                Text("Log on my behalf").tag(ProfileAccess.write)
                Text("View only").tag(ProfileAccess.read)
            }
            .pickerStyle(.segmented)
            .onChange(of: shareAccess) { _, _ in copiedCode = false }

            ShareLink(
                item: profile.inviteURL(grant: shareAccess),
                subject: Text("Be my spotter on SpotRep"),
                message: Text(inviteMessage)
            ) {
                Label("Share invite link", systemImage: "square.and.arrow.up")
            }

            Button {
                UIPasteboard.general.string = profile.inviteToken(grant: shareAccess)
                copiedCode = true
            } label: {
                Label(copiedCode ? "Code copied" : "Copy invite code", systemImage: copiedCode ? "checkmark" : "doc.on.doc")
            }
        } header: {
            Text("Add a spotter")
        } footer: {
            Text("Tapping the link opens SpotRep and adds you automatically (if they have the app). If the link isn't tappable in their messenger, send the code instead — they paste it under “Follow someone” below.")
        }
    }

    private var inviteMessage: String {
        "Be my spotter on SpotRep — tap to open the app and start \(shareAccess == .write ? "viewing & logging" : "viewing") my training. If the link won't open, paste this code in SpotRep ▸ Spotters ▸ Follow someone:\n\(profile.inviteToken(grant: shareAccess))"
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
        Section {
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
                .swipeActions {
                    Button("Stop spotting", role: .destructive) {
                        profile.stopSpotting(p.id)
                    }
                }
            }
            .onDelete { offsets in
                let ids = offsets.map { profile.linked[$0].id }
                ids.forEach { profile.stopSpotting($0) }
            }
        } header: {
            Text("People you're spotting")
        } footer: {
            Text("Swipe to stop spotting someone.")
        }
    }
}
