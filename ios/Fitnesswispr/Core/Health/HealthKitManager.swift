import Foundation
import HealthKit

/// A workout pulled from Apple Health, used only to enrich the consistency
/// heatmap (whether a workout happened that day and what category).
struct AppleFitnessWorkout: Identifiable, Hashable {
    let id = UUID()
    let category: String
    let symbol: String
    let date: Date
    let durationMinutes: Int
}

@MainActor
final class HealthKitManager: ObservableObject {
    static let shared = HealthKitManager()

    private let store = HKHealthStore()

    /// apiDateString -> Apple Health workouts logged that day.
    @Published private(set) var workoutsByDay: [String: [AppleFitnessWorkout]] = [:]
    @Published private(set) var didSync = false

    private init() {}

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    /// Requests read access to workouts, then loads recent ones.
    /// HealthKit never reveals read-permission status, so we simply request and query.
    func sync(daysBack: Int = 180) async {
        guard isAvailable else { return }
        let types: Set<HKObjectType> = [HKObjectType.workoutType()]
        do {
            try await store.requestAuthorization(toShare: [], read: types)
        } catch {
            // User may deny; queries will just return nothing.
        }
        await fetchWorkouts(daysBack: daysBack)
    }

    private func fetchWorkouts(daysBack: Int) async {
        guard isAvailable else { return }
        let end = Date()
        let start = Calendar.current.date(byAdding: .day, value: -daysBack, to: end) ?? end
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        let workouts: [HKWorkout] = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, samples, _ in
                continuation.resume(returning: (samples as? [HKWorkout]) ?? [])
            }
            store.execute(query)
        }

        var byDay: [String: [AppleFitnessWorkout]] = [:]
        for w in workouts {
            let (name, symbol) = Self.describe(w.workoutActivityType)
            let minutes = Int((w.duration / 60).rounded())
            let item = AppleFitnessWorkout(
                category: name,
                symbol: symbol,
                date: w.startDate,
                durationMinutes: minutes
            )
            byDay[w.startDate.apiDateString, default: []].append(item)
        }
        workoutsByDay = byDay
        didSync = true
    }

    func workouts(on dateStr: String) -> [AppleFitnessWorkout] {
        workoutsByDay[dateStr] ?? []
    }

    static func describe(_ type: HKWorkoutActivityType) -> (name: String, symbol: String) {
        switch type {
        case .traditionalStrengthTraining, .functionalStrengthTraining:
            return ("Strength", "dumbbell.fill")
        case .running:
            return ("Running", "figure.run")
        case .walking:
            return ("Walking", "figure.walk")
        case .cycling:
            return ("Cycling", "figure.outdoor.cycle")
        case .highIntensityIntervalTraining:
            return ("HIIT", "bolt.fill")
        case .coreTraining:
            return ("Core", "figure.core.training")
        case .yoga:
            return ("Yoga", "figure.yoga")
        case .pilates:
            return ("Pilates", "figure.pilates")
        case .swimming:
            return ("Swimming", "figure.pool.swim")
        case .hiking:
            return ("Hiking", "figure.hiking")
        case .elliptical:
            return ("Elliptical", "figure.elliptical")
        case .rowing:
            return ("Rowing", "figure.rower")
        case .stairClimbing, .stairs:
            return ("Stairs", "figure.stairs")
        case .dance, .cardioDance:
            return ("Dance", "figure.dance")
        case .boxing, .kickboxing:
            return ("Boxing", "figure.boxing")
        case .mixedCardio, .crossTraining:
            return ("Cardio", "figure.mixed.cardio")
        default:
            return ("Workout", "figure.strengthtraining.traditional")
        }
    }
}
