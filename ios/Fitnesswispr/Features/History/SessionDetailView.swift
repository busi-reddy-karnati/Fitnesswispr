import SwiftUI

struct SessionDetailView: View {
    let session: WorkoutSession

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
                    ExerciseConfirmCard(exercise: exercise)
                }
            }
            .padding()
        }
        .navigationTitle(Date.from(apiString: session.workoutDate)?.displayString ?? session.workoutDate)
        .navigationBarTitleDisplayMode(.inline)
    }
}
