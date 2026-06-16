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

    private init() {}

    func triggerRecordNow() {
        autoStartRecording = true
        showRecorder = true
    }
}
