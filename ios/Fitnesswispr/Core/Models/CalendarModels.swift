import Foundation

struct CalendarDay: Decodable {
    let date: String
    let workoutType: String?
}

struct CalendarResponse: Decodable {
    let dates: [CalendarDay]
}

struct DeviceContextResponse: Decodable {
    let lastBodyWeightLbs: Double?
    let lastUpdated: String?
}
