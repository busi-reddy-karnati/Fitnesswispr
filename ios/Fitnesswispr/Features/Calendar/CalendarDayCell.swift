import SwiftUI

struct CalendarDayCell: View {
    let day: Int
    let workoutType: String?
    let hasWorkout: Bool
    let isToday: Bool
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 4) {
            Text("\(day)")
                .font(.callout)
                .fontWeight(isToday ? .bold : .regular)
                .foregroundColor(isToday ? .appAccent : .primary)

            if hasWorkout {
                Circle()
                    .fill(Color.workoutTypeColor(workoutType))
                    .frame(width: 6, height: 6)
            } else {
                Circle()
                    .fill(Color.clear)
                    .frame(width: 6, height: 6)
            }
        }
        .frame(height: 44)
        .frame(maxWidth: .infinity)
        .background(isSelected ? Color.appAccent.opacity(0.15) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
