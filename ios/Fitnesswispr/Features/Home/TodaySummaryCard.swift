import SwiftUI

struct TodaySummaryCard: View {
    let session: WorkoutSession

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(session.workoutType ?? "Workout")
                    .font(.headline)
                Spacer()
                WorkoutTypeBadge(type: session.workoutType)
            }
            Text("\(session.exercises.count) exercises")
                .font(.subheadline)
                .foregroundColor(.secondary)
            if let bw = session.bodyWeightLbs {
                Text("Body weight: \(bw, specifier: "%.1f") lbs")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
