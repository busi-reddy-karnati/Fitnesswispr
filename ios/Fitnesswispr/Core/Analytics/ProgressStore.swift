import Foundation

struct ExercisePoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
    let reps: Int?
    let sets: Int
}

struct ExerciseSummary: Identifiable {
    let id = UUID()
    let name: String
    let unit: String        // "lbs" | "kg" | "sec" | "reps"
    let metricLabel: String // "Top set" | "Hold" | "Reps"
    let points: [ExercisePoint]

    var latest: ExercisePoint? { points.last }
    var first: ExercisePoint? { points.first }
    var personalRecord: Double { points.map(\.value).max() ?? 0 }
    var lastDate: Date? { points.last?.date }
    var gain: Double { (latest?.value ?? 0) - (first?.value ?? 0) }
}

struct MuscleSummary {
    let region: MuscleRegion
    let lastDate: Date?
    let exercises: [ExerciseSummary]

    var daysSince: Int? {
        guard let d = lastDate else { return nil }
        let cal = Calendar.current
        return cal.dateComponents([.day], from: cal.startOfDay(for: d), to: cal.startOfDay(for: Date())).day
    }

    var isDue: Bool { (daysSince ?? Int.max) >= MuscleRegion.dueAfterDays }
}

@MainActor
final class ProgressStore: ObservableObject {
    @Published var sessions: [WorkoutSession] = []
    @Published var appleDays: [String: [AppleFitnessWorkout]] = [:]
    @Published var isLoading = false
    @Published var loaded = false
    @Published var error: String?

    func loadIfNeeded() async {
        if !loaded { await load() }
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        let deviceUUID = ProfileStore.shared.activeID
        let end = Date()
        let start = Calendar.current.date(byAdding: .day, value: -180, to: end) ?? end
        let url = APIEndpoints.sessions(
            deviceUUID: deviceUUID,
            startDate: start.apiDateString,
            endDate: end.apiDateString,
            limit: 200
        )
        do {
            sessions = try await APIClient.shared.get(url)
            loaded = true
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
        // Apple Health only reflects this device's owner, not a linked profile.
        if deviceUUID == DeviceUUID.shared.id {
            await syncAppleFitness()
        } else {
            appleDays = [:]
        }
    }

    /// Pulls Apple Health workout days to enrich the consistency view.
    func syncAppleFitness() async {
        await HealthKitManager.shared.sync()
        appleDays = HealthKitManager.shared.workoutsByDay
    }

    // MARK: - Consistency

    /// apiDateString -> total sets logged that day (heatmap intensity).
    /// Days with only an Apple Health workout still count toward consistency.
    func dayIntensities() -> [String: Int] {
        var map: [String: Int] = [:]
        for s in sessions {
            let sets = s.exercises.reduce(0) { $0 + $1.sets.count }
            map[s.workoutDate, default: 0] += max(sets, 1)
        }
        for (day, workouts) in appleDays {
            // Give Apple-only days a visible baseline without overriding richer in-app logs.
            map[day] = max(map[day] ?? 0, workouts.count * 4)
        }
        return map
    }

    /// Union of in-app logged days and Apple Health workout days.
    private func activeDays() -> Set<String> {
        Set(sessions.map { $0.workoutDate }).union(appleDays.keys)
    }

    func currentStreak() -> Int {
        let days = activeDays()
        guard !days.isEmpty else { return 0 }
        let cal = Calendar.current
        var cursor = cal.startOfDay(for: Date())
        if !days.contains(cursor.apiDateString) {
            cursor = cal.date(byAdding: .day, value: -1, to: cursor) ?? cursor
            if !days.contains(cursor.apiDateString) { return 0 }
        }
        var streak = 0
        while days.contains(cursor.apiDateString) {
            streak += 1
            cursor = cal.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }
        return streak
    }

    func trainedToday() -> Bool {
        activeDays().contains(Date().apiDateString)
    }

    /// All sessions recorded on the given calendar day.
    func sessions(on dateStr: String) -> [WorkoutSession] {
        sessions.filter { $0.workoutDate == dateStr }
    }

    /// Apple Health workouts on the given calendar day.
    func appleWorkouts(on dateStr: String) -> [AppleFitnessWorkout] {
        appleDays[dateStr] ?? []
    }

    // MARK: - Muscle aggregation

    func allSummaries() -> [MuscleRegion: MuscleSummary] {
        var result: [MuscleRegion: MuscleSummary] = [:]
        for region in MuscleRegion.allCases {
            result[region] = summary(for: region)
        }
        return result
    }

    func summary(for region: MuscleRegion) -> MuscleSummary {
        var byName: [String: [(date: Date, ex: Exercise)]] = [:]
        var lastDate: Date?
        for s in sessions {
            guard let d = Date.from(apiString: s.workoutDate) else { continue }
            for ex in s.exercises {
                guard MuscleRegion.classify(muscleGroup: ex.muscleGroup, exerciseName: ex.name) == region else { continue }
                byName[ex.name, default: []].append((d, ex))
                if lastDate == nil || d > lastDate! { lastDate = d }
            }
        }
        let summaries = byName
            .map { buildExerciseSummary(name: $0.key, occurrences: $0.value) }
            .sorted { ($0.lastDate ?? .distantPast) > ($1.lastDate ?? .distantPast) }
        return MuscleSummary(region: region, lastDate: lastDate, exercises: summaries)
    }

    func summary(forExercise name: String) -> ExerciseSummary? {
        var occ: [(date: Date, ex: Exercise)] = []
        for s in sessions {
            guard let d = Date.from(apiString: s.workoutDate) else { continue }
            for ex in s.exercises where ex.name.caseInsensitiveCompare(name) == .orderedSame {
                occ.append((d, ex))
            }
        }
        guard !occ.isEmpty else { return nil }
        return buildExerciseSummary(name: name, occurrences: occ)
    }

    private func buildExerciseSummary(name: String, occurrences: [(date: Date, ex: Exercise)]) -> ExerciseSummary {
        let allSets = occurrences.flatMap { $0.ex.sets }

        let metric: String
        let unit: String
        let metricLabel: String
        if allSets.contains(where: { $0.weight != nil }) {
            metric = "weight"
            unit = allSets.first(where: { $0.weight != nil })?.weightUnit ?? "lbs"
            metricLabel = "Top set"
        } else if allSets.contains(where: { $0.durationSeconds != nil }) {
            metric = "duration"
            unit = "sec"
            metricLabel = "Hold"
        } else {
            metric = "reps"
            unit = "reps"
            metricLabel = "Reps"
        }

        let cal = Calendar.current
        let grouped = Dictionary(grouping: occurrences) { cal.startOfDay(for: $0.date) }
        var points: [ExercisePoint] = []
        for (date, occs) in grouped {
            let sets = occs.flatMap { $0.ex.sets }
            var value = 0.0
            var reps: Int?
            switch metric {
            case "weight":
                if let top = sets.filter({ $0.weight != nil }).max(by: { ($0.weight ?? 0) < ($1.weight ?? 0) }) {
                    value = top.weight ?? 0
                    reps = top.reps
                }
            case "duration":
                value = Double(sets.compactMap { $0.durationSeconds }.max() ?? 0)
            default:
                value = Double(sets.compactMap { $0.reps }.max() ?? 0)
            }
            points.append(ExercisePoint(date: date, value: value, reps: reps, sets: sets.count))
        }
        points.sort { $0.date < $1.date }
        return ExerciseSummary(name: name, unit: unit, metricLabel: metricLabel, points: points)
    }
}

func daysAgoText(_ date: Date?) -> String {
    guard let d = date else { return "" }
    let cal = Calendar.current
    let days = cal.dateComponents([.day], from: cal.startOfDay(for: d), to: cal.startOfDay(for: Date())).day ?? 0
    if days <= 0 { return "today" }
    if days == 1 { return "yesterday" }
    return "\(days)d ago"
}
