import SwiftUI

struct SessionRowView: View {
    let session: WorkoutSession

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(displayDate).font(.subheadline.weight(.medium))
                if session.isCardioOnly, let line = session.cardioSummaryLine {
                    Label(line, systemImage: CardioSummary.symbol)
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("\(session.exercises.count) exercises")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            WorkoutTypeBadge(type: session.workoutType)
        }
        .padding(.vertical, 4)
    }

    private var displayDate: String {
        Date.from(apiString: session.workoutDate)?.displayString ?? session.workoutDate
    }
}
