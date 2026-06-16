import SwiftUI

struct SessionDetailView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var session: WorkoutSession
    @State private var isEditing = false
    @State private var pendingDelete: Exercise?
    @State private var working = false
    @State private var error: String?

    /// Called after a successful change so parent screens can refresh.
    private let onChanged: (() -> Void)?

    init(session: WorkoutSession, onChanged: (() -> Void)? = nil) {
        _session = State(initialValue: session)
        self.onChanged = onChanged
    }

    private var canEdit: Bool { ProfileStore.shared.active.canWrite }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    WorkoutTypeBadge(type: session.workoutType)
                    Spacer()
                    if let bw = session.bodyWeightLbs {
                        Label("\(bw, specifier: "%.1f") lbs", systemImage: "scalemass")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                if let cardio = session.cardioNotes {
                    Label(cardio, systemImage: "figure.run")
                        .font(.subheadline)
                }

                ForEach(session.exercises) { exercise in
                    ZStack(alignment: .topTrailing) {
                        ExerciseConfirmCard(exercise: exercise)
                        if isEditing {
                            Button {
                                pendingDelete = exercise
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.title2)
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(.white, .red)
                            }
                            .padding(8)
                        }
                    }
                }

                if let error {
                    ErrorBanner(message: error) { self.error = nil }
                }
            }
            .padding()
        }
        .navigationTitle(Date.from(apiString: session.workoutDate)?.displayString ?? session.workoutDate)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if canEdit && !session.exercises.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isEditing ? "Done" : "Edit") { isEditing.toggle() }
                }
            }
        }
        .overlay {
            if working {
                LoadingOverlay(message: "Saving...")
            }
        }
        .confirmationDialog(
            "Delete this exercise?",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            presenting: pendingDelete
        ) { exercise in
            Button("Delete \(exercise.name)", role: .destructive) {
                delete(exercise)
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func delete(_ exercise: Exercise) {
        guard let sessionId = session.sessionId else { return }
        pendingDelete = nil
        let remaining = session.exercises.filter { $0.id != exercise.id }
        working = true
        Task {
            do {
                if remaining.isEmpty {
                    // Last exercise — remove the whole session.
                    try await APIClient.shared.delete(APIEndpoints.session(sessionId))
                    working = false
                    onChanged?()
                    dismiss()
                } else {
                    let req = UpdateSessionRequest(exercises: remaining)
                    let updated: WorkoutSession = try await APIClient.shared.put(
                        APIEndpoints.session(sessionId), body: req
                    )
                    session = updated
                    working = false
                    if session.exercises.isEmpty { isEditing = false }
                    onChanged?()
                }
            } catch {
                self.error = "Couldn't delete: \(error.localizedDescription)"
                working = false
            }
        }
    }
}
