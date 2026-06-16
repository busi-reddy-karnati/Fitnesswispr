import Foundation

struct HealthDayDTO: Codable {
    let workoutDate: String
    let category: String
    let symbol: String
    let durationMinutes: Int
}

struct HealthSyncRequest: Encodable {
    let deviceUuid: String
    let workouts: [HealthDayDTO]
}

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

    private var inFlight: Task<Void, Never>?

    func loadIfNeeded() async {
        if !loaded { await load() }
    }

    /// Latest-wins load. The fetch runs in an unstructured task so SwiftUI
    /// tearing down `.task` / `.refreshable` can't surface a spurious
    /// "cancelled" error; a newer load simply supersedes the previous one.
    func load() async {
        inFlight?.cancel()
        let task = Task<Void, Never> { [weak self] in
            guard let self else { return }
            await self.performLoad()
        }
        inFlight = task
        await task.value
    }

    private func performLoad() async {
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
        } catch is CancellationError {
            return // superseded — not a real failure
        } catch let urlError as URLError where urlError.code == .cancelled {
            return
        } catch {
            self.error = error.localizedDescription
        }

        // Apple Health enriches consistency. For yourself, live HealthKit is
        // authoritative (no extra network round-trip), and we push it so your
        // spotters can see it. For people you spot, fetch their pushed days.
        if deviceUUID == Identity.current {
            if HealthKitManager.shared.didSync {
                appleDays = HealthKitManager.shared.workoutsByDay
                Task { [weak self] in await self?.pushHealthToBackend(HealthKitManager.shared.workoutsByDay) }
            } else {
                appleDays = [:]
                Task { [weak self] in await self?.syncAppleFitness() }
            }
        } else {
            appleDays = await fetchBackendHealth(
                deviceUUID, start: start.apiDateString, end: end.apiDateString
            )
        }
    }

    /// Pulls Apple Health workout days to enrich the consistency view, and
    /// pushes them so anyone spotting you sees your Apple Fitness consistency.
    func syncAppleFitness() async {
        await HealthKitManager.shared.sync()
        appleDays = HealthKitManager.shared.workoutsByDay
        await pushHealthToBackend(appleDays)
    }

    private func pushHealthToBackend(_ byDay: [String: [AppleFitnessWorkout]]) async {
        let items = byDay.flatMap { day, workouts in
            workouts.map {
                HealthDayDTO(
                    workoutDate: day,
                    category: $0.category,
                    symbol: $0.symbol,
                    durationMinutes: $0.durationMinutes
                )
            }
        }
        let req = HealthSyncRequest(deviceUuid: Identity.current, workouts: items)
        try? await APIClient.shared.postNoContent(APIEndpoints.healthSync, body: req)
    }

    private func fetchBackendHealth(
        _ uuid: String, start: String, end: String
    ) async -> [String: [AppleFitnessWorkout]] {
        guard let dtos: [HealthDayDTO] = try? await APIClient.shared.get(
            APIEndpoints.health(deviceUUID: uuid, startDate: start, endDate: end)
        ) else { return [:] }
        var byDay: [String: [AppleFitnessWorkout]] = [:]
        for d in dtos {
            guard let date = Date.from(apiString: d.workoutDate) else { continue }
            byDay[d.workoutDate, default: []].append(
                AppleFitnessWorkout(
                    category: d.category,
                    symbol: d.symbol,
                    date: date,
                    durationMinutes: d.durationMinutes
                )
            )
        }
        return byDay
    }

    // MARK: - Optimistic local mutations
    // Keep the UI instant after add/edit/delete instead of waiting on a refetch.

    /// Insert or replace a session in the local cache (after a create/update).
    func applyLocally(_ session: WorkoutSession) {
        if let id = session.sessionId,
           let idx = sessions.firstIndex(where: { $0.sessionId == id }) {
            sessions[idx] = session
        } else {
            sessions.insert(session, at: 0)
        }
    }

    /// Drop a session from the local cache (after a delete).
    func removeLocally(sessionId: String) {
        sessions.removeAll { $0.sessionId == sessionId }
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
