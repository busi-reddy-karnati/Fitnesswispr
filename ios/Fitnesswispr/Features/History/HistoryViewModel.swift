import Foundation

@MainActor
final class HistoryViewModel: ObservableObject {
    @Published var sessions: [WorkoutSession] = []
    @Published var isLoading = false
    @Published var hasMore = true
    @Published var error: String?

    private var offset = 0
    private let limit = 20

    func fetchInitial() async {
        offset = 0
        sessions = []
        hasMore = true
        await fetchMore()
    }

    func fetchMore() async {
        guard hasMore, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        let url = APIEndpoints.sessions(deviceUUID: DeviceUUID.shared.id, limit: limit, offset: offset)
        do {
            let new: [WorkoutSession] = try await APIClient.shared.get(url)
            sessions += new
            offset += new.count
            hasMore = new.count == limit
        } catch {
            self.error = error.localizedDescription
        }
    }

    var groupedSessions: [(String, [WorkoutSession])] {
        var dict: [String: [WorkoutSession]] = [:]

        for session in sessions {
            let key = monthKey(from: session.workoutDate)
            dict[key, default: []].append(session)
        }

        let sorted = dict.keys.sorted(by: >)
        return sorted.map { key in (key, dict[key]!) }
    }

    private func monthKey(from dateStr: String) -> String {
        guard let date = Date.from(apiString: dateStr) else { return dateStr }
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: date)
    }
}
