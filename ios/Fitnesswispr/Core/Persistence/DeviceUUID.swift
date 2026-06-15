import Foundation
import Security

final class DeviceUUID {
    static let shared = DeviceUUID()
    let id: String

    private init() {
        let service = "fitnesswispr"
        let account = "device_uuid"

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess, let data = result as? Data, let uuid = String(data: data, encoding: .utf8) {
            self.id = uuid
        } else {
            let newUUID = UUID().uuidString
            let data = newUUID.data(using: .utf8)!
            let addQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account,
                kSecValueData as String: data
            ]
            SecItemAdd(addQuery as CFDictionary, nil)
            self.id = newUUID
        }
    }
}
