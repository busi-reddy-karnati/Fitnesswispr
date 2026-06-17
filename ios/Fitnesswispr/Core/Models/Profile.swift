import Foundation

enum ProfileAccess: String, Codable, Hashable {
    case owner   // your own profile
    case write   // spotter who can log on this person's behalf
    case read    // spotter who can only view

    var canWrite: Bool { self == .owner || self == .write }

    var label: String {
        switch self {
        case .owner: return "You"
        case .write: return "Can log"
        case .read: return "View only"
        }
    }
}

/// A person whose training the app can show on Home. The owner is "you";
/// linked profiles are people who shared their training with you (Spotter).
struct Profile: Codable, Identifiable, Hashable {
    let id: String          // device_uuid
    var name: String
    var access: ProfileAccess
    /// True once a grant has been registered with the backend for this link.
    /// Only server-managed links are auto-removed when access is revoked, so
    /// legacy links (created before grants existed) are left untouched.
    var serverManaged: Bool?

    var canWrite: Bool { access.canWrite }
    var isServerManaged: Bool { serverManaged ?? false }

    var initials: String {
        let parts = name.split(separator: " ").prefix(2)
        let chars = parts.compactMap { $0.first }.map(String.init)
        let joined = chars.joined().uppercased()
        return joined.isEmpty ? "?" : joined
    }
}

/// Shared profile info fetched from the backend (current name, photo flag).
struct ProfileInfo: Decodable {
    let deviceUuid: String
    let name: String?
    let hasAvatar: Bool
}

struct ProfileUpdateRequest: Encodable {
    let name: String?
}

/// Sent by a spotter to register access to someone's profile after redeeming
/// their invite.
struct GrantCreateRequest: Encodable {
    let granteeUuid: String
    let access: String
    let granteeName: String?
}

/// A spotter who has access to your profile (owner's "People with access" list).
struct Grantee: Decodable, Identifiable {
    let ownerUuid: String
    let granteeUuid: String
    let access: String
    let granteeName: String?

    var id: String { granteeUuid }
    var displayName: String { (granteeName?.isEmpty == false ? granteeName : nil) ?? "Spotter" }
}

/// A profile you are currently spotting (used to drop revoked access).
struct Spotting: Decodable {
    let ownerUuid: String
    let ownerName: String?
    let access: String
}

/// Payload encoded into an invite code/link when sharing a profile.
struct ProfileInvite: Codable {
    var v: Int = 1
    let uuid: String
    let name: String
    let access: String   // "read" | "write"
}
