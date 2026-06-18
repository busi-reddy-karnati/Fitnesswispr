import Foundation
import UIKit

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var isExporting = false
    @Published var error: String?

    func exportWorkouts(format: String) async -> Data? {
        isExporting = true
        defer { isExporting = false }
        let url = APIEndpoints.export(deviceUUID: Identity.current, format: format)
        do {
            return try await APIClient.shared.download(url)
        } catch {
            self.error = error.localizedDescription
            return nil
        }
    }
}
