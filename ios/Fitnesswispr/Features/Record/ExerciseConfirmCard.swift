import SwiftUI

struct ExerciseConfirmCard: View {
    let exercise: Exercise

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(exercise.name).font(.headline)
                Spacer()
                if let mg = exercise.muscleGroup {
                    Text(mg).font(.caption).foregroundColor(.secondary)
                }
            }
            if let equipment = exercise.equipment {
                Text(equipment).font(.caption2).foregroundColor(.secondary)
            }
            Divider()
            ForEach(exercise.sets, id: \.setNumber) { set in
                HStack {
                    Text("Set \(set.setNumber)")
                    Spacer()
                    if let d = set.durationSeconds {
                        Text("\(d)s")
                    } else {
                        if let reps = set.reps { Text("\(reps) reps") }
                        if let weight = set.weight {
                            Text("\(weight, specifier: "%.1f") \(set.weightUnit)")
                        }
                    }
                }
                .font(.subheadline)
            }
        }
        .padding()
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
