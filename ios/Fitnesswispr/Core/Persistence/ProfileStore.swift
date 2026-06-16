import SwiftUI

/// Central store for the user's own profile (name, body metrics, avatar) and
/// any linked profiles shared with them ("Spotter" sharing). Persisted locally.
///
/// Note: the backend has no authentication, so read/write access here is
/// enforced client-side (trust-based). Real enforcement would require backend
/// auth + per-profile permissions.
final class ProfileStore: ObservableObject {
    static let shared = ProfileStore()

    @Published var myName: String { didSet { persist() } }
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
        activeID = loaded.activeID.isEmpty ? DeviceUUID.shared.id : loaded.activeID
        avatarData = ProfileStore.loadAvatar()

        // Ensure the active profile still exists.
        if activeID != DeviceUUID.shared.id && !linked.contains(where: { $0.id == activeID }) {
            activeID = DeviceUUID.shared.id
        }
    }

    // MARK: - Derived

    var meID: String { DeviceUUID.shared.id }

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

    func remove(_ id: String) {
        linked.removeAll { $0.id == id }
        if activeID == id { activeID = meID }
    }

    func setAvatar(_ data: Data?) {
        avatarData = data
        ProfileStore.saveAvatar(data)
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
