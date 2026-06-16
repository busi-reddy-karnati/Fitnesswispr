import Foundation

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var todaySessions: [WorkoutSession] = []
    @Published var isLoading = false
    @Published var error: String?

    func fetchToday() async {
        isLoading = true
        defer { isLoading = false }
        let today = Date().apiDateString
        let url = APIEndpoints.sessions(deviceUUID: Identity.current, startDate: today, endDate: today)
        do {
            todaySessions = try await APIClient.shared.get(url)
        } catch {
            self.error = error.localizedDescription
        }
    }
}
