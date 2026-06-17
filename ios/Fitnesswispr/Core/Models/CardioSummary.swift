import Foundation

/// Formats a one-line summary of a cardio entry, e.g. "Running · 3.0 mi · 25 min".
/// Cardio is intentionally kept out of the muscle map and strength PRs; this is
/// only used where sessions are listed/reviewed.
enum CardioSummary {
    static let symbol = "figure.run"

    static func line(
        activity: String?,
        distance: Double?,
        unit: String?,
        durationMinutes: Int?,
        notes: String? = nil
    ) -> String? {
        var parts: [String] = []
        if let a = activity?.trimmingCharacters(in: .whitespacesAndNewlines), !a.isEmpty {
            parts.append(a)
        }
        if let d = distance, d > 0 {
            let num = d == d.rounded() ? String(Int(d)) : String(format: "%.2f", d)
            parts.append("\(num) \(unit ?? "mi")")
        }
        if let m = durationMinutes, m > 0 {
            parts.append("\(m) min")
        }
        if parts.isEmpty, let n = notes?.trimmingCharacters(in: .whitespacesAndNewlines), !n.isEmpty {
            return n
        }
        var line = parts.joined(separator: " · ")
        if let n = notes?.trimmingCharacters(in: .whitespacesAndNewlines), !n.isEmpty,
           !line.localizedCaseInsensitiveContains(n) {
            line += line.isEmpty ? n : " · \(n)"
        }
        return line.isEmpty ? nil : line
    }
}

extension ParsedSession {
    var cardioSummaryLine: String? {
        CardioSummary.line(
            activity: cardioActivity,
            distance: cardioDistance,
            unit: cardioDistanceUnit,
            durationMinutes: durationMinutes,
            notes: cardioNotes
        )
    }
}

extension WorkoutSession {
    var cardioSummaryLine: String? {
        CardioSummary.line(
            activity: cardioActivity,
            distance: cardioDistance,
            unit: cardioDistanceUnit,
            durationMinutes: durationMinutes,
            notes: cardioNotes
        )
    }
}
