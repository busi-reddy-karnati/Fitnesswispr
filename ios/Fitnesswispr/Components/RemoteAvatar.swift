import SwiftUI

/// Caches profile photos fetched from the backend, keyed by device UUID, so a
/// spotter can see the people they follow with their real photos.
@MainActor
final class AvatarCache: ObservableObject {
    static let shared = AvatarCache()

    @Published private(set) var images: [String: Data] = [:]
    private var inFlight: Set<String> = []
    private var missing: Set<String> = []

    private init() {}

    func data(for uuid: String) -> Data? { images[uuid] }

    func load(_ uuid: String) {
        guard images[uuid] == nil, !inFlight.contains(uuid), !missing.contains(uuid) else { return }
        inFlight.insert(uuid)
        Task {
            defer { inFlight.remove(uuid) }
            if let data = try? await APIClient.shared.download(APIEndpoints.profileAvatar(uuid)),
               !data.isEmpty {
                images[uuid] = data
            } else {
                missing.insert(uuid)   // no avatar yet; don't keep retrying
            }
        }
    }

    /// Forget a cached/missing entry so the next load re-fetches (after upload).
    func invalidate(_ uuid: String) {
        images[uuid] = nil
        missing.remove(uuid)
    }
}

/// An avatar for a profile identified by UUID. Shows the local photo for "me",
/// otherwise the backend-stored photo (falling back to initials).
struct RemoteAvatarView: View {
    let uuid: String
    let initials: String
    var size: CGFloat = 40
    var ringColor: Color? = nil

    @ObservedObject private var profile = ProfileStore.shared
    @ObservedObject private var cache = AvatarCache.shared

    private var isMe: Bool { uuid == profile.meID }

    private var imageData: Data? {
        isMe ? profile.avatarData : cache.data(for: uuid)
    }

    var body: some View {
        AvatarView(imageData: imageData, initials: initials, size: size, ringColor: ringColor)
            .onAppear { if !isMe { cache.load(uuid) } }
    }
}
