import SwiftUI

struct DayWorkoutSheet: View {
    let dateStr: String
    let sessions: [WorkoutSession]
    var appleWorkouts: [AppleFitnessWorkout] = []
    var onChanged: (() -> Void)? = nil

    private var isEmpty: Bool { sessions.isEmpty && appleWorkouts.isEmpty }

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
                                    SessionDetailView(session: session, onChanged: onChanged)
                                } label: {
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            WorkoutTypeBadge(type: session.workoutType)
                                            Spacer()
                                            Text("\(session.exercises.count) exercises")
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
                                    if w.durationMinutes > 0 {
                                        Text("\(w.durationMinutes) min")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
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
