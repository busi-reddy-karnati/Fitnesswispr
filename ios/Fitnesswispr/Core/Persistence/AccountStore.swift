import Foundation
import Security

struct AppleAuthRequest: Encodable {
    let identityToken: String
    let deviceUuid: String
    let fullName: String?
}

struct AuthResponse: Decodable {
    let token: String
    let primaryUuid: String
    let email: String?
    let fullName: String?
    let isNew: Bool
}

/// The identity the app uses for "me" across all API calls.
///
/// When the user is signed in with Apple, this is the account's canonical UUID
/// (so their data follows them across devices and reinstalls). Otherwise it
/// falls back to the anonymous per-device UUID.
enum Identity {
    static var current: String {
        AccountStore.shared.primaryUUID ?? DeviceUUID.shared.id
    }
}

/// A signed-in account, persisted in the Keychain.
struct Account: Codable {
    let uuid: String      // canonical primary_uuid from the backend
    let token: String     // our session JWT
    var email: String?
    var name: String?
}

final class AccountStore: ObservableObject {
    static let shared = AccountStore()

    @Published private(set) var account: Account?

    private let service = "fitnesswispr"
    private let key = "account_v1"

    private init() {
        account = Self.load(service: service, key: key)
    }

    var isSignedIn: Bool { account != nil }
    var primaryUUID: String? { account?.uuid }
    var token: String? { account?.token }

    /// Exchange an Apple identity token for an account, sending the device's
    /// local UUID so existing anonymous data is claimed/merged into the account.
    @MainActor
    func signInWithApple(identityToken: String, fullName: String?) async throws {
        let req = AppleAuthRequest(
            identityToken: identityToken,
            deviceUuid: DeviceUUID.shared.id,
            fullName: fullName
        )
        let resp: AuthResponse = try await APIClient.shared.post(APIEndpoints.authApple, body: req)
        signIn(Account(
            uuid: resp.primaryUuid,
            token: resp.token,
            email: resp.email,
            name: resp.fullName
        ))
        ProfileStore.shared.switchToSelf()
    }

    func signIn(_ account: Account) {
        self.account = account
        Self.save(account, service: service, key: key)
    }

    @MainActor
    func signOut() {
        account = nil
        Self.delete(service: service, key: key)
        ProfileStore.shared.switchToSelf()
    }

    // MARK: - Keychain

    private static func load(service: String, key: String) -> Account? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let account = try? JSONDecoder().decode(Account.self, from: data)
        else { return nil }
        return account
    }

    private static func save(_ account: Account, service: String, key: String) {
        guard let data = try? JSONEncoder().encode(account) else { return }
        delete(service: service, key: key)
        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        SecItemAdd(attributes as CFDictionary, nil)
    }

    private static func delete(service: String, key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}
