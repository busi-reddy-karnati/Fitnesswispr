import Foundation

// MARK: - Preview (request/response)

struct ImportPreviewRequest: Encodable {
    let kind: String          // "spreadsheet" | "photo"
    let contentBase64: String
    let filename: String?
    let mime: String?
}

struct ImportSetDTO: Codable, Hashable {
    var reps: Int?
    var weight: Double?
    var weightUnit: String = "lbs"
    var durationSeconds: Int?
}

struct ImportExerciseDTO: Codable, Hashable, Identifiable {
    var id: String { name + "\(sets.count)" }
    var name: String
    var muscleGroup: String?
    var notes: String?
    var sets: [ImportSetDTO] = []
}

struct ImportWorkoutDTO: Codable, Hashable, Identifiable {
    var id: String { "\(person ?? "")-\(week ?? 0)-\(day ?? 0)-\(workoutType ?? "")" }
    var person: String?
    var week: Int?
    var day: Int?
    var dayLabel: String?
    var workoutDate: String?
    var workoutType: String?
    var exercises: [ImportExerciseDTO] = []
}

struct ImportPreviewResponse: Codable, Identifiable {
    let id = UUID()
    let sourceKind: String
    let detectedUnit: String
    let people: [String]
    let needsStartDate: Bool
    let totalWorkouts: Int
    let totalSets: Int
    let summary: String
    let workouts: [ImportWorkoutDTO]

    enum CodingKeys: String, CodingKey {
        case sourceKind, detectedUnit, people, needsStartDate
        case totalWorkouts, totalSets, summary, workouts
    }
}

// MARK: - Commit (request/response)

struct ImportCommitItem: Encodable {
    let deviceUuid: String
    let workoutDate: String   // YYYY-MM-DD
    let workoutType: String?
    let source: String
    let exercises: [ImportExerciseDTO]
}

struct ImportCommitRequest: Encodable {
    let items: [ImportCommitItem]
}

struct ImportCommitResponse: Decodable {
    let created: Int
}
