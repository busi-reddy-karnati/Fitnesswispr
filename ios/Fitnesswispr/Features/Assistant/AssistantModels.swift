import Foundation

/// A single bubble in the assistant chat transcript.
struct ChatMessage: Identifiable {
    enum Author {
        case user
        case assistant
    }

    enum Body {
        /// Plain text from the user or assistant.
        case text(String)
        /// A parsed workout awaiting the user's confirmation before saving.
        case workoutDraft(ParsedSession)
        /// A short confirmation that a workout was saved.
        case saved(String)
        /// The assistant needs one more detail before it can log the workout,
        /// and offers quick options the user can tap (or type their own).
        case clarify(Clarification)
        /// The assistant is thinking.
        case thinking
    }

    let id = UUID()
    let author: Author
    var body: Body
    let timestamp = Date()
}

/// A request for a missing detail needed to log a workout. The user can tap one
/// of `options` or type their own answer.
///
/// - `.exercise` answers are re-parsed (prepended to `pendingText`).
/// - `.weight` / `.reps` / `.sets` answers are numbers applied directly to `draft`.
struct Clarification {
    enum Kind {
        case exercise
        /// A generic exercise name (e.g. "Squats") that has more specific
        /// variants in the user's history to choose from.
        case variant
        case weight
        case reps
        case sets
    }

    let messageID: UUID
    let kind: Kind
    let prompt: String
    let options: [String]
    /// Original text to re-parse with the answer (used by `.exercise`).
    let pendingText: String
    /// Draft to fill the missing number into (used by `.weight` / `.reps` / `.sets`).
    let draft: ParsedSession?
}

struct AssistantChatRequest: Encodable {
    let deviceUuid: String
    let message: String
}

struct AssistantChatResponse: Decodable {
    let reply: String
}
