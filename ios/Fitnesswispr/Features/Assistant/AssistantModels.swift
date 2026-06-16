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
        /// The assistant is thinking.
        case thinking
    }

    let id = UUID()
    let author: Author
    var body: Body
    let timestamp = Date()
}

struct AssistantChatRequest: Encodable {
    let deviceUuid: String
    let message: String
}

struct AssistantChatResponse: Decodable {
    let reply: String
}
