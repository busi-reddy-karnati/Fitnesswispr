import SwiftUI

extension Color {
    static let appBackground = Color(UIColor.systemBackground)
    static let cardBackground = Color(UIColor.secondarySystemBackground)
    static let appAccent = Color.blue

    static func workoutTypeColor(_ type: String?) -> Color {
        switch type {
        case "Push": return .orange
        case "Pull": return .blue
        case "Legs": return .green
        case "Upper": return .purple
        case "Lower": return .indigo
        case "Full Body": return .purple
        case "Cardio": return .red
        default: return .gray
        }
    }
}
