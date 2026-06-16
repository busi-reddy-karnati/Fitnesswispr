import SwiftUI
import UIKit

/// Central store for the user's own profile (name, body metrics, avatar) and
/// any linked profiles shared with them ("Spotter" sharing). Persisted locally.
///
/// Note: the backend has no authentication, so read/write access here is
/// enforced client-side (trust-based). Real enforcement would require backend
/// auth + per-profile permissions.
final class ProfileStore: ObservableObject {
    static let shared = ProfileStore()

    @Published var myName: String { didSet { persist(); scheduleNamePush() } }
    @Published var age: Int { didSet { persist() } }            // 0 = unset
    @Published var heightCm: Double { didSet { persist() } }    // 0 = unset
    @Published var weightLbs: Double { didSet { persist() } }   // 0 = unset
    @Published var linked: [Profile] { didSet { persist() } }
    @Published var activeID: String { didSet { persist() } }
    @Published var avatarData: Data?

    private let defaultsKey = "profile_store_v1"

    private struct Persisted: Codable {
        var myName = ""
        var age = 0
        var heightCm = 0.0
        var weightLbs = 0.0
        var linked: [Profile] = []
        var activeID = ""
    }

    private init() {
        let loaded: Persisted
        if let data = UserDefaults.standard.data(forKey: "profile_store_v1"),
           let decoded = try? JSONDecoder().decode(Persisted.self, from: data) {
            loaded = decoded
        } else {
            loaded = Persisted()
        }
        myName = loaded.myName
        age = loaded.age
        heightCm = loaded.heightCm
        weightLbs = loaded.weightLbs
        linked = loaded.linked
        activeID = loaded.activeID.isEmpty ? Identity.current : loaded.activeID
        avatarData = ProfileStore.loadAvatar()

        // Ensure the active profile still exists.
        if activeID != Identity.current && !linked.contains(where: { $0.id == activeID }) {
            activeID = Identity.current
        }
    }

    // MARK: - Derived

    var meID: String { Identity.current }

    var me: Profile {
        Profile(id: meID, name: myName.isEmpty ? "Me" : myName, access: .owner)
    }

    var profiles: [Profile] { [me] + linked }

    var active: Profile {
        profiles.first { $0.id == activeID } ?? me
    }

    var isViewingSelf: Bool { activeID == meID }

    // MARK: - Mutations

    func setActive(_ id: String) {
        guard profiles.contains(where: { $0.id == id }) else { return }
        activeID = id
    }

    /// Re-point the active profile at "me". Call after signing in or out so the
    /// app reloads data for the (possibly new) canonical identity.
    func switchToSelf() {
        activeID = meID
        objectWillChange.send()
    }

    func remove(_ id: String) {
        linked.removeAll { $0.id == id }
        if activeID == id { activeID = meID }
    }

    func setAvatar(_ data: Data?) {
        avatarData = data
        ProfileStore.saveAvatar(data)
        if let data { uploadAvatar(data) }
    }

    private var didPushProfile = false
    private var namePushTask: Task<Void, Never>?

    /// Best-effort push of profile info (name + photo) so spotters see it.
    /// Safe to call repeatedly; only does work once per launch.
    func pushProfileIfNeeded() {
        guard !didPushProfile else { return }
        didPushProfile = true
        if let data = avatarData { uploadAvatar(data) }
        pushName()
    }

    /// Debounced name push — `myName` changes on every keystroke while editing.
    private func scheduleNamePush() {
        namePushTask?.cancel()
        namePushTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 600_000_000)
            guard !Task.isCancelled else { return }
            self?.pushName()
        }
    }

    private func pushName() {
        let name = myName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let uuid = meID
        Task {
            let body = ProfileUpdateRequest(name: name)
            let _: ProfileInfo? = try? await APIClient.shared.put(APIEndpoints.profile(uuid), body: body)
        }
    }

    /// Refresh the names of people you're spotting from the backend, so a name
    /// change on their side shows up for you.
    func refreshLinkedProfiles() {
        let targets = linked
        guard !targets.isEmpty else { return }
        Task {
            var updates: [(id: String, name: String)] = []
            for p in targets {
                if let info: ProfileInfo = try? await APIClient.shared.get(APIEndpoints.profile(p.id)),
                   let name = info.name, !name.isEmpty {
                    updates.append((p.id, name))
                }
            }
            let resolved = updates
            await MainActor.run { ProfileStore.shared.applyLinkedNames(resolved) }
        }
    }

    @MainActor
    private func applyLinkedNames(_ updates: [(id: String, name: String)]) {
        for u in updates {
            if let idx = linked.firstIndex(where: { $0.id == u.id }), linked[idx].name != u.name {
                linked[idx].name = u.name
            }
        }
    }

    private func uploadAvatar(_ data: Data) {
        guard let jpeg = ProfileStore.downscaledJPEG(data) else { return }
        let uuid = meID
        Task {
            try? await APIClient.shared.putData(
                APIEndpoints.profileAvatar(uuid), data: jpeg, contentType: "image/jpeg"
            )
            await AvatarCache.shared.invalidate(uuid)
        }
    }

    /// Shrink a photo to a reasonable avatar size to keep uploads small.
    private static func downscaledJPEG(_ data: Data, maxDimension: CGFloat = 512) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let longest = max(image.size.width, image.size.height)
        let scale = longest > maxDimension ? maxDimension / longest : 1
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        let resized = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
        return resized.jpegData(compressionQuality: 0.8)
    }

    // MARK: - Sharing

    /// Generates an invite token (base64url) granting `grant` access to your profile.
    func inviteToken(grant: ProfileAccess) -> String {
        let invite = ProfileInvite(uuid: meID, name: me.name, access: grant.rawValue)
        let data = (try? JSONEncoder().encode(invite)) ?? Data()
        return Self.base64urlEncode(data)
    }

    func inviteURL(grant: ProfileAccess) -> URL {
        URL(string: "spotrep://join/\(inviteToken(grant: grant))")!
    }

    enum RedeemError: LocalizedError {
        case invalid
        case isSelf

        var errorDescription: String? {
            switch self {
            case .invalid: return "That invite code isn't valid."
            case .isSelf: return "That's your own profile."
            }
        }
    }

    /// Adds a linked profile from an invite token or `spotrep://join/<token>` URL.
    @discardableResult
    func redeem(_ raw: String) throws -> Profile {
        var token = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let range = token.range(of: "join/") {
            token = String(token[range.upperBound...])
        }
        guard let data = Self.base64urlDecode(token),
              let invite = try? JSONDecoder().decode(ProfileInvite.self, from: data)
        else { throw RedeemError.invalid }

        guard invite.uuid != meID else { throw RedeemError.isSelf }

        let access = ProfileAccess(rawValue: invite.access) ?? .read
        let profile = Profile(id: invite.uuid, name: invite.name, access: access)

        if let idx = linked.firstIndex(where: { $0.id == profile.id }) {
            linked[idx] = profile   // update name/access
        } else {
            linked.append(profile)
        }
        return profile
    }

    // MARK: - Persistence

    private func persist() {
        let p = Persisted(
            myName: myName, age: age, heightCm: heightCm,
            weightLbs: weightLbs, linked: linked, activeID: activeID
        )
        if let data = try? JSONEncoder().encode(p) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }

    private static func avatarURL() -> URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("profile_avatar.jpg")
    }

    private static func loadAvatar() -> Data? {
        try? Data(contentsOf: avatarURL())
    }

    private static func saveAvatar(_ data: Data?) {
        let url = avatarURL()
        if let data {
            try? data.write(to: url)
        } else {
            try? FileManager.default.removeItem(at: url)
        }
    }

    // MARK: - base64url helpers

    private static func base64urlEncode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func base64urlDecode(_ s: String) -> Data? {
        var str = s.replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while str.count % 4 != 0 { str.append("=") }
        return Data(base64Encoded: str)
    }
}
