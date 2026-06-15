import Foundation

@MainActor
final class CalendarViewModel: ObservableObject {
    @Published var workoutDays: [String: String?] = [:]  // date string -> workout_type (nil value = workout exists but no type)
    @Published var selectedDate: String?
    @Published var selectedSessions: [WorkoutSession] = []
    @Published var isLoading = false
    @Published var currentYear: Int
    @Published var currentMonth: Int

    init() {
        let now = Calendar.current.dateComponents([.year, .month], from: Date())
        currentYear = now.year!
        currentMonth = now.month!
    }

    func fetchCalendar() async {
        isLoading = true
        defer { isLoading = false }
        let url = APIEndpoints.calendar(deviceUUID: DeviceUUID.shared.id, year: currentYear, month: currentMonth)
        if let response = try? await APIClient.shared.get(url) as CalendarResponse {
            workoutDays = Dictionary(uniqueKeysWithValues: response.dates.map { ($0.date, $0.workoutType) })
        }
    }

    func selectDate(_ dateStr: String) async {
        selectedDate = dateStr
        let url = APIEndpoints.sessions(deviceUUID: DeviceUUID.shared.id, startDate: dateStr, endDate: dateStr)
        if let sessions = try? await APIClient.shared.get(url) as [WorkoutSession] {
            selectedSessions = sessions
        }
    }

    func nextMonth() {
        if currentMonth == 12 { currentMonth = 1; currentYear += 1 }
        else { currentMonth += 1 }
    }

    func prevMonth() {
        if currentMonth == 1 { currentMonth = 12; currentYear -= 1 }
        else { currentMonth -= 1 }
    }
}
