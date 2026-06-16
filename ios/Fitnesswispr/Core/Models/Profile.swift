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

    var canWrite: Bool { access.canWrite }

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

/// Payload encoded into an invite code/link when sharing a profile.
struct ProfileInvite: Codable {
    var v: Int = 1
    let uuid: String
    let name: String
    let access: String   // "read" | "write"
}
