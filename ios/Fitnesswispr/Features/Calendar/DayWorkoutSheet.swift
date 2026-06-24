import SwiftUI

struct DayWorkoutSheet: View {
    let dateStr: String
    var appleWorkouts: [AppleFitnessWorkout] = []
    var onChanged: (() -> Void)? = nil
    /// Optimistic callbacks — preferred over `onChanged` when the caller can
    /// update its cache without a full refetch.
    var onUpdated: ((WorkoutSession) -> Void)? = nil
    var onDeleted: ((String) -> Void)? = nil

    /// Held locally so edits made in the pushed detail view (renames, deletes)
    /// reflect in these rows the moment you pop back — not only on reopen.
    @State private var sessions: [WorkoutSession]

    init(
        dateStr: String,
        sessions: [WorkoutSession],
        appleWorkouts: [AppleFitnessWorkout] = [],
        onChanged: (() -> Void)? = nil,
        onUpdated: ((WorkoutSession) -> Void)? = nil,
        onDeleted: ((String) -> Void)? = nil
    ) {
        self.dateStr = dateStr
        _sessions = State(initialValue: sessions)
        self.appleWorkouts = appleWorkouts
        self.onChanged = onChanged
        self.onUpdated = onUpdated
        self.onDeleted = onDeleted
    }

    private var isEmpty: Bool { sessions.isEmpty && appleWorkouts.isEmpty }

    /// Distance (when available) + duration for an Apple Fitness workout,
    /// e.g. "3.1 mi · 25 min".
    private func appleMetrics(_ w: AppleFitnessWorkout) -> String {
        var parts: [String] = []
        if let dist = w.distanceText { parts.append(dist) }
        if w.durationMinutes > 0 { parts.append("\(w.durationMinutes) min") }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        NavigationStack {
            if isEmpty {
                EmptyStateView(icon: "calendar.badge.exclamationmark", title: "No workout", message: "No workout recorded for this day")
            } else {
                List {
                    if !sessions.isEmpty {
                        Section("Logged in SpotRep") {
                            ForEach(sessions) { session in
                                NavigationLink {
                                    if session.isCardioOnly {
                                        CardioProgressView(activity: session.cardioActivity ?? "Cardio")
                                    } else {
                                        SessionDetailView(
                                            session: session,
                                            onChanged: onChanged,
                                            onUpdated: { updated in
                                                if let idx = sessions.firstIndex(where: { $0.sessionId == updated.sessionId }) {
                                                    sessions[idx] = updated
                                                }
                                                onUpdated?(updated)
                                            },
                                            onDeleted: { id in
                                                sessions.removeAll { $0.sessionId == id }
                                                onDeleted?(id)
                                            }
                                        )
                                    }
                                } label: {
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            WorkoutTypeBadge(type: session.workoutType)
                                            Spacer()
                                            if !session.isCardioOnly {
                                                Text("\(session.exercises.count) exercises")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        if session.isCardioOnly, let line = session.cardioSummaryLine {
                                            Label(line, systemImage: CardioSummary.symbol)
                                                .font(.subheadline)
                                                .foregroundColor(.appAccent)
                                            Label("View progress", systemImage: "chart.line.uptrend.xyaxis")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        ForEach(session.exercises) { ex in
                                            Text(ex.name).font(.subheadline)
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                    }

                    if !appleWorkouts.isEmpty {
                        Section("Apple Fitness") {
                            ForEach(appleWorkouts) { w in
                                HStack(spacing: 12) {
                                    Image(systemName: w.symbol)
                                        .foregroundColor(.appAccent)
                                        .frame(width: 24)
                                    Text(w.category)
                                        .font(.subheadline)
                                    Spacer()
                                    Text(appleMetrics(w))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(dateStr)
        .navigationBarTitleDisplayMode(.inline)
    }
}
