import SwiftUI

struct SessionDetailView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var session: WorkoutSession
    @State private var isEditing = false
    @State private var pendingDelete: Exercise?
    @State private var error: String?
    @State private var editedDate = Date()

    /// Called after a successful change so parent screens can refresh.
    private let onChanged: (() -> Void)?
    /// Optimistic callbacks — when provided, parents update their cache without
    /// a full refetch (instant UI). Falls back to `onChanged` otherwise.
    private let onUpdated: ((WorkoutSession) -> Void)?
    private let onDeleted: ((String) -> Void)?

    init(
        session: WorkoutSession,
        onChanged: (() -> Void)? = nil,
        onUpdated: ((WorkoutSession) -> Void)? = nil,
        onDeleted: ((String) -> Void)? = nil
    ) {
        _session = State(initialValue: session)
        self.onChanged = onChanged
        self.onUpdated = onUpdated
        self.onDeleted = onDeleted
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

                if isEditing {
                    DatePicker(
                        "Date",
                        selection: $editedDate,
                        displayedComponents: .date
                    )
                    .padding(12)
                    .background(Color.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
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
                    Button(isEditing ? "Done" : "Edit") {
                        if isEditing {
                            saveDateIfChanged()
                        } else {
                            editedDate = Date.from(apiString: session.workoutDate) ?? Date()
                        }
                        isEditing.toggle()
                    }
                }
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

    private func saveDateIfChanged() {
        guard let sessionId = session.sessionId else { return }
        let newStr = editedDate.apiDateString
        guard newStr != session.workoutDate else { return }

        // Optimistic: reflect the new date immediately, sync in the background.
        let previous = session
        session.workoutDate = newStr
        onUpdated?(session)
        Task {
            do {
                let req = UpdateSessionRequest(workoutDate: newStr)
                let updated: WorkoutSession = try await APIClient.shared.put(
                    APIEndpoints.session(sessionId), body: req
                )
                session = updated
                onUpdated?(updated)
                onChanged?()
            } catch {
                session = previous
                onUpdated?(previous)
                self.error = "Couldn't change the date: \(error.localizedDescription)"
            }
        }
    }

    private func delete(_ exercise: Exercise) {
        guard let sessionId = session.sessionId else { return }
        pendingDelete = nil
        let previous = session
        let remaining = session.exercises.filter { $0.id != exercise.id }

        if remaining.isEmpty {
            // Last exercise — remove the whole session. Dismiss immediately.
            onDeleted?(sessionId)
            onChanged?()
            dismiss()
            Task {
                do {
                    try await APIClient.shared.delete(APIEndpoints.session(sessionId))
                } catch {
                    // Best-effort; the parent can recover on its next refresh.
                }
            }
            return
        }

        // Optimistic: drop the exercise now, sync in the background.
        session.exercises = remaining
        onUpdated?(session)
        Task {
            do {
                let req = UpdateSessionRequest(exercises: remaining)
                let updated: WorkoutSession = try await APIClient.shared.put(
                    APIEndpoints.session(sessionId), body: req
                )
                session = updated
                onUpdated?(updated)
                onChanged?()
            } catch {
                session = previous
                onUpdated?(previous)
                self.error = "Couldn't delete: \(error.localizedDescription)"
            }
        }
    }
}
