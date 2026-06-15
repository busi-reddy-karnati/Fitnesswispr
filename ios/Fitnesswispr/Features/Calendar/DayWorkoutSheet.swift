import SwiftUI

struct DayWorkoutSheet: View {
    let dateStr: String
    let sessions: [WorkoutSession]

    var body: some View {
        NavigationStack {
            if sessions.isEmpty {
                EmptyStateView(icon: "calendar.badge.exclamationmark", title: "No workout", message: "No workout recorded for this day")
            } else {
                List(sessions) { session in
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
        .navigationTitle(dateStr)
        .navigationBarTitleDisplayMode(.inline)
    }
}
