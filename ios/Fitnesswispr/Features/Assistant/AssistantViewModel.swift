import Foundation
import SwiftUI

@MainActor
final class AssistantViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var composer: String = ""
    @Published var isBusy = false
    @Published var importPreview: ImportPreviewResponse?

    let speech = SpeechRecognizer()
    private let preferences: UserPreferences
    private var bodyWeightLbs: Double?

    private var targetUUID: String { ProfileStore.shared.activeID }

    init(preferences: UserPreferences) {
        self.preferences = preferences
        messages = [greeting]
    }

    private var greeting: ChatMessage {
        let name = ProfileStore.shared.isViewingSelf ? "" : " for \(ProfileStore.shared.active.name)"
        return ChatMessage(
            author: .assistant,
            body: .text(
                "Hey! I'm your SpotRep coach\(name). Tell me what you trained (“bench 3x10 at 135”), tap the mic, or ask me anything — “what's my PR on squat?”"
            )
        )
    }

    func onAppear() {
        Task {
            let url = APIEndpoints.deviceContext(targetUUID)
            if let ctx = try? await APIClient.shared.get(url) as DeviceContextResponse {
                bodyWeightLbs = ctx.lastBodyWeightLbs
            }
        }
    }

    // MARK: - Sending

    func sendComposer() {
        let text = composer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        composer = ""
        send(text)
    }

    func send(_ text: String) {
        messages.append(ChatMessage(author: .user, body: .text(text)))
        let thinkingID = appendThinking()
        isBusy = true

        Task {
            if looksLikeQuestion(text) {
                await answer(text, replacing: thinkingID)
            } else {
                await logWorkout(text, replacing: thinkingID, allowQuestionFallback: true)
            }
            isBusy = false
        }
    }

    // MARK: - Routing

    /// Heuristic to decide whether the message is a question vs. a workout to log.
    private func looksLikeQuestion(_ text: String) -> Bool {
        let t = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if t.hasSuffix("?") { return true }
        let prefixes = [
            "what", "when", "how", "why", "who", "which", "whats", "what's",
            "did i", "do i", "have i", "show", "tell", "can you", "should i",
            "explain", "summarize", "compare", "am i", "is my", "are my"
        ]
        if prefixes.contains(where: { t.hasPrefix($0) }) { return true }
        let keywords = [
            "my pr", "personal record", " pr ", "last time", "how much",
            "how many", "progress on", "best ", "average", "trend"
        ]
        return keywords.contains(where: { t.contains($0) })
    }

    // MARK: - Logging

    private func logWorkout(_ text: String, replacing id: UUID, allowQuestionFallback: Bool) async {
        let context = ParseContext(bodyWeightLbs: bodyWeightLbs)
        let req = ParseRequest(
            transcript: text,
            deviceUuid: targetUUID,
            unitPreference: preferences.unitPreference,
            context: context
        )
        do {
            let parsed: ParsedSession = try await APIClient.shared.post(APIEndpoints.parse, body: req)
            if parsed.exercises.isEmpty {
                if allowQuestionFallback {
                    await answer(text, replacing: id)
                } else {
                    replace(id, with: .text("I couldn't find a workout in that. Try “incline press 3x8 at 50”."))
                }
                return
            }
            replace(id, with: .workoutDraft(parsed))
        } catch NetworkError.httpError(422, _) {
            // Not a parseable workout — treat as a question instead.
            if allowQuestionFallback {
                await answer(text, replacing: id)
            } else {
                replace(id, with: .text("I couldn't parse that as a workout."))
            }
        } catch {
            replace(id, with: .text("Something went wrong: \(error.localizedDescription)"))
        }
    }

    func saveDraft(_ parsed: ParsedSession, date: Date, draftID: UUID) {
        isBusy = true
        Task {
            let req = CreateSessionRequest(
                deviceUuid: targetUUID,
                workoutDate: date.apiDateString,
                source: "assistant",
                rawTranscript: nil,
                workoutType: parsed.workoutType,
                bodyWeightLbs: parsed.bodyWeightLbs,
                cardioNotes: parsed.cardioNotes,
                sessionNotes: nil,
                exercises: parsed.exercises
            )
            do {
                let _: WorkoutSession = try await APIClient.shared.post(APIEndpoints.sessions, body: req)
                let count = parsed.exercises.count
                replace(draftID, with: .saved("Logged \(count) exercise\(count == 1 ? "" : "s") ✓"))
                NotificationCenter.default.post(name: .workoutLogged, object: nil)
            } catch {
                appendAssistant(.text("Couldn't save that: \(error.localizedDescription)"))
            }
            isBusy = false
        }
    }

    func discardDraft(_ draftID: UUID) {
        replace(draftID, with: .text("No worries — nothing was saved."))
    }

    // MARK: - Questions

    private func answer(_ question: String, replacing id: UUID) async {
        let req = AssistantChatRequest(deviceUuid: targetUUID, message: question)
        do {
            let resp: AssistantChatResponse = try await APIClient.shared.post(APIEndpoints.assistantChat, body: req)
            replace(id, with: .text(resp.reply.isEmpty ? "I'm not sure about that one." : resp.reply))
        } catch {
            replace(id, with: .text("I couldn't reach the coach right now. \(error.localizedDescription)"))
        }
    }

    // MARK: - Voice

    func startVoice() {
        Task {
            let granted = await speech.requestPermission()
            guard granted else {
                appendAssistant(.text("I need microphone and speech permission to listen."))
                return
            }
            speech.start()
        }
    }

    func stopVoiceAndSend() {
        let text = speech.stop().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        send(text)
    }

    // MARK: - Import

    func startImport(kind: String, data: Data, filename: String?, mime: String?) {
        let label = kind == "spreadsheet" ? "spreadsheet" : "photo"
        messages.append(ChatMessage(author: .user, body: .text("📎 \(filename ?? label)")))
        let thinkingID = appendThinking()
        isBusy = true
        let b64 = data.base64EncodedString()
        Task {
            do {
                let req = ImportPreviewRequest(kind: kind, contentBase64: b64, filename: filename, mime: mime)
                // Spreadsheet extraction can take ~30–60s; allow plenty of time.
                let resp: ImportPreviewResponse = try await APIClient.shared.post(
                    APIEndpoints.importPreview, body: req, timeout: 180
                )
                replace(thinkingID, with: .text("I found \(resp.summary). Review the details and import below."))
                importPreview = resp
            } catch NetworkError.httpError(422, let data) {
                let msg = (try? JSONDecoder().decode([String: String].self, from: data))?["detail"]
                    ?? "I couldn't read that file."
                replace(thinkingID, with: .text(msg))
            } catch {
                replace(thinkingID, with: .text("Import failed: \(error.localizedDescription)"))
            }
            isBusy = false
        }
    }

    func commitImport(items: [ImportCommitItem]) {
        importPreview = nil
        guard !items.isEmpty else {
            appendAssistant(.text("Nothing was selected to import."))
            return
        }
        let thinkingID = appendThinking()
        isBusy = true
        Task {
            do {
                let resp: ImportCommitResponse = try await APIClient.shared.post(
                    APIEndpoints.importCommit, body: ImportCommitRequest(items: items), timeout: 60
                )
                replace(thinkingID, with: .saved("Imported \(resp.created) workouts ✓"))
                NotificationCenter.default.post(name: .workoutLogged, object: nil)
            } catch {
                replace(thinkingID, with: .text("Couldn't import: \(error.localizedDescription)"))
            }
            isBusy = false
        }
    }

    // MARK: - Message helpers

    private func appendThinking() -> UUID {
        let msg = ChatMessage(author: .assistant, body: .thinking)
        messages.append(msg)
        return msg.id
    }

    private func appendAssistant(_ body: ChatMessage.Body) {
        messages.append(ChatMessage(author: .assistant, body: body))
    }

    private func replace(_ id: UUID, with body: ChatMessage.Body) {
        guard let idx = messages.firstIndex(where: { $0.id == id }) else {
            appendAssistant(body)
            return
        }
        messages[idx].body = body
    }
}

extension Notification.Name {
    static let workoutLogged = Notification.Name("spotrep.workoutLogged")
}
