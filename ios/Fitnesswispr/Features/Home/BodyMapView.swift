import SwiftUI

struct BodyMapView: View {
    let summaries: [MuscleRegion: MuscleSummary]

    private let canvas = CGSize(width: 150, height: 190)

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.primary.opacity(0.12))
                .frame(width: 22, height: 22)
                .position(x: 75, y: 16)

            block(.shoulders, CGRect(x: 36, y: 33, width: 30, height: 12))
            block(.shoulders, CGRect(x: 84, y: 33, width: 30, height: 12))
            block(.chest, CGRect(x: 48, y: 48, width: 54, height: 24))
            block(.arms, CGRect(x: 24, y: 48, width: 16, height: 50))
            block(.arms, CGRect(x: 110, y: 48, width: 16, height: 50))
            block(.core, CGRect(x: 52, y: 74, width: 46, height: 32))
            block(.legs, CGRect(x: 50, y: 110, width: 21, height: 70))
            block(.legs, CGRect(x: 79, y: 110, width: 21, height: 70))
        }
        .frame(width: canvas.width, height: canvas.height)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func block(_ region: MuscleRegion, _ rect: CGRect) -> some View {
        let summary = summaries[region]
        let warmth = warmthValue(summary?.daysSince)
        let due = summary?.isDue ?? false

        NavigationLink(value: region) {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.primary.opacity(0.12 + 0.55 * warmth))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(due ? Color.appAccent : Color.clear, lineWidth: 2)
                )
                .frame(width: rect.width, height: rect.height)
        }
        .buttonStyle(.plain)
        .position(x: rect.midX, y: rect.midY)
    }

    private func warmthValue(_ daysSince: Int?) -> Double {
        guard let days = daysSince else { return 0 }
        if days <= 1 { return 1 }
        let ceiling = Double(MuscleRegion.dueAfterDays + 3)
        return max(0, 1 - Double(days) / ceiling)
    }
}
