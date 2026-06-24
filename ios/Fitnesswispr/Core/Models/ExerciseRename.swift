import Foundation

/// One logged entry that a bulk rename will touch, shown in the confirm preview.
struct RenameOccurrence: Decodable, Identifiable {
    let sessionId: String
    let workoutDate: String
    let oldName: String
    let setCount: Int

    var id: String { "\(sessionId)\u{0}\(oldName)" }
}

/// Rename/merge every matching exercise across a device's history.
/// `match == "canonical"` also folds plural/synonym variants (e.g. "Lat
/// Pulldown" / "Lat Pulldowns"); `"exact"` matches the literal name only.
struct RenameExerciseRequest: Encodable {
    let deviceUuid: String
    let fromNames: [String]
    let toName: String
    var match: String = "canonical"
    var dryRun: Bool
}

struct RenameExerciseResponse: Decodable {
    let toName: String
    let matchedCount: Int
    let sessionCount: Int
    let occurrences: [RenameOccurrence]
    let applied: Bool
}

/// Ask the backend's LLM for one clean common name across several variants.
struct SuggestNameRequest: Encodable {
    let names: [String]
}

struct SuggestNameResponse: Decodable {
    let name: String
}

/// Interpret a free-form chat message as a rename/merge command.
struct ParseCommandRequest: Encodable {
    let deviceUuid: String
    let message: String
    let knownNames: [String]
}

struct ParseCommandResponse: Decodable {
    let isRename: Bool
    let fromNames: [String]
    let toName: String?
}

/// A pending bulk rename awaiting the user's confirmation in chat.
struct RenamePreview {
    let messageID: UUID
    let fromNames: [String]
    let toName: String
    let occurrences: [RenameOccurrence]
    let matchedCount: Int
    /// Whether to match plural/synonym variants ("canonical") or just the exact
    /// names ("exact"). Chat rename uses canonical; explicit two-item merges use
    /// exact so unrelated names aren't swept in.
    let match: String
}
