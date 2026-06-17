import Foundation

/// One logged cardio session, normalised for trend charts.
struct CardioPoint: Identifiable {
    let id = UUID()
    let sessionId: String?
    let date: Date
    let distanceMiles: Double?
    let durationMinutes: Int?
    /// Minutes per mile (lower is better). Only set when both distance & time exist.
    let paceMinPerMile: Double?
}

/// Progress over time for a single cardio activity (e.g. "Running"). Kept fully
/// separate from strength PRs / the muscle map.
struct CardioProgress: Identifiable {
    let id = UUID()
    let activity: String
    let points: [CardioPoint]   // sorted oldest → newest

    var sessionsCount: Int { points.count }
    var totalMiles: Double { points.compactMap(\.distanceMiles).reduce(0, +) }
    var totalMinutes: Int { points.compactMap(\.durationMinutes).reduce(0, +) }
    var longestMiles: Double? { points.compactMap(\.distanceMiles).max() }
    var bestPace: Double? { points.compactMap(\.paceMinPerMile).min() }

    var hasDistance: Bool { points.contains { $0.distanceMiles != nil } }
    var hasDuration: Bool { points.contains { $0.durationMinutes != nil } }
    var hasPace: Bool { points.contains { $0.paceMinPerMile != nil } }

    /// Convert a logged distance to miles for a consistent pace/scale.
    static func miles(_ distance: Double, unit: String?) -> Double {
        switch (unit ?? "mi").lowercased() {
        case "km", "kilometer", "kilometers": return distance * 0.621371
        case "m", "meter", "meters": return distance * 0.000621371
        default: return distance   // mi / mile / miles / unknown → assume miles
        }
    }

    /// Build a progress series for one activity from the user's sessions.
    /// Matching is case-insensitive on the activity name.
    static func build(activity: String, sessions: [WorkoutSession]) -> CardioProgress? {
        let key = activity.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return nil }

        var points: [CardioPoint] = []
        var displayName = activity
        var latest = Date.distantPast

        for s in sessions where s.isCardioOnly {
            guard let raw = s.cardioActivity?.trimmingCharacters(in: .whitespacesAndNewlines),
                  raw.lowercased() == key,
                  let date = Date.from(apiString: s.workoutDate) else { continue }

            let miles = s.cardioDistance.map { CardioProgress.miles($0, unit: s.cardioDistanceUnit) }
            let distance = (miles ?? 0) > 0 ? miles : nil
            let duration = (s.durationMinutes ?? 0) > 0 ? s.durationMinutes : nil
            var pace: Double?
            if let mi = distance, let mins = duration, mi > 0 { pace = Double(mins) / mi }

            points.append(CardioPoint(
                sessionId: s.sessionId,
                date: date,
                distanceMiles: distance,
                durationMinutes: duration,
                paceMinPerMile: pace
            ))
            if date >= latest { latest = date; displayName = raw }
        }

        guard !points.isEmpty else { return nil }
        points.sort { $0.date < $1.date }
        return CardioProgress(activity: displayName, points: points)
    }

    /// Distinct cardio activity names in the sessions, most-recent first.
    static func activities(in sessions: [WorkoutSession]) -> [String] {
        var lastSeen: [String: Date] = [:]
        var display: [String: String] = [:]
        for s in sessions where s.isCardioOnly {
            guard let raw = s.cardioActivity?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !raw.isEmpty,
                  let date = Date.from(apiString: s.workoutDate) else { continue }
            let key = raw.lowercased()
            if lastSeen[key] == nil || date > lastSeen[key]! {
                lastSeen[key] = date
                display[key] = raw
            }
        }
        return lastSeen.sorted { $0.value > $1.value }.compactMap { display[$0.key] }
    }
}

/// "8:30" from 8.5 minutes-per-mile.
func formatPace(_ minutesPerMile: Double) -> String {
    let totalSeconds = Int((minutesPerMile * 60).rounded())
    return String(format: "%d:%02d", totalSeconds / 60, totalSeconds % 60)
}
