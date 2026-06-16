import SwiftUI

/// Shared routing state used by the Home screen, App Intents, and Home Screen
/// quick actions to open the recorder and start logging immediately.
@MainActor
final class QuickActionCoordinator: ObservableObject {
    static let shared = QuickActionCoordinator()

    /// Presents the full-screen recorder.
    @Published var showRecorder = false
    /// When true, the recorder starts the microphone automatically on appear.
    @Published var autoStartRecording = false
    /// When true, the assistant opens its attach menu (import a spreadsheet/photo).
    @Published var pendingAttach = false

    private init() {}

    /// Opens the assistant and immediately starts the microphone (Action Button,
    /// long-press quick action, "Hey Siri, log a workout").
    func triggerRecordNow() {
        autoStartRecording = true
        showRecorder = true
    }

    /// Opens the assistant chat without auto-starting the mic — for typing a log
    /// or asking a question.
    func openChat() {
        autoStartRecording = false
        showRecorder = true
    }

    /// Opens the assistant and presents the attach menu to import a spreadsheet
    /// or photo of past records.
    func openImport() {
        autoStartRecording = false
        pendingAttach = true
        showRecorder = true
    }
}
