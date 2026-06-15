import SwiftUI

struct WorkoutTypeBadge: View {
    let type: String?

    var body: some View {
        if let type {
            Text(type)
                .font(.caption.weight(.semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.workoutTypeColor(type))
                .clipShape(Capsule())
        }
    }
}
