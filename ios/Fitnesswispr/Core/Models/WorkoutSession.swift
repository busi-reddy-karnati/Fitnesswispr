import Foundation

struct ExerciseSet: Codable, Identifiable {
    var id: String { "\(setNumber)" }
    let setNumber: Int
    var reps: Int?
    var weight: Double?
    var weightUnit: String
    var durationSeconds: Int?
}

struct Exercise: Codable, Identifiable {
    var id: String = UUID().uuidString
    var exerciseId: String?
    var name: String
    var equipment: String?
    var muscleGroup: String?
    var notes: String?
    var sets: [ExerciseSet]

    enum CodingKeys: String, CodingKey {
        case exerciseId, name, equipment, muscleGroup, notes, sets
    }
}

struct WorkoutSession: Codable, Identifiable {
    var id: String { sessionId ?? tempId }
    private let tempId: String = UUID().uuidString
    var sessionId: String?
    var deviceUuid: String?
    var workoutDate: String
    var createdAt: String?
    var source: String?
    var rawTranscript: String?
    var workoutType: String?
    var bodyWeightLbs: Double?
    var cardioNotes: String?
    var sessionNotes: String?
    var durationMinutes: Int?
    var exercises: [Exercise]

    enum CodingKeys: String, CodingKey {
        case sessionId, deviceUuid, workoutDate, createdAt, source, rawTranscript
        case workoutType, bodyWeightLbs, cardioNotes, sessionNotes, durationMinutes, exercises
    }
}

struct ParsedSession: Codable {
    var workoutType: String?
    var bodyWeightLbs: Double?
    var cardioNotes: String?
    var exercises: [Exercise]
}

struct CreateSessionRequest: Encodable {
    var deviceUuid: String? = nil
    let workoutDate: String
    let source: String
    let rawTranscript: String?
    let workoutType: String?
    let bodyWeightLbs: Double?
    let cardioNotes: String?
    let sessionNotes: String?
    let exercises: [Exercise]

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(deviceUuid, forKey: .deviceUuid)
        try container.encode(workoutDate, forKey: .workoutDate)
        try container.encode(source, forKey: .source)
        try container.encodeIfPresent(rawTranscript, forKey: .rawTranscript)
        try container.encodeIfPresent(workoutType, forKey: .workoutType)
        try container.encodeIfPresent(bodyWeightLbs, forKey: .bodyWeightLbs)
        try container.encodeIfPresent(cardioNotes, forKey: .cardioNotes)
        try container.encodeIfPresent(sessionNotes, forKey: .sessionNotes)
        try container.encode(exercises, forKey: .exercises)
    }

    enum CodingKeys: String, CodingKey {
        case deviceUuid = "device_uuid"
        case workoutDate = "workout_date"
        case source
        case rawTranscript = "raw_transcript"
        case workoutType = "workout_type"
        case bodyWeightLbs = "body_weight_lbs"
        case cardioNotes = "cardio_notes"
        case sessionNotes = "session_notes"
        case exercises
    }
}
