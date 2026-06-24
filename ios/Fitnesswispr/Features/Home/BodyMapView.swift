import SwiftUI

/// Two-figure muscle map: an anterior (front) and posterior (back) silhouette.
/// The back figure is what makes the `.back` region reachable — rows, pulldowns,
/// and other back movements live there. Both figures share the same warmth
/// shading (brighter = trained more recently) and "due" outline, and every block
/// pushes that region's detail screen.
struct BodyMapView: View {
    let summaries: [MuscleRegion: MuscleSummary]

    private let canvas = CGSize(width: 132, height: 186)

    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            figure(title: "Front", blocks: frontBlocks)
            figure(title: "Back", blocks: backBlocks)
        }
        .frame(maxWidth: .infinity)
    }

    /// Anterior view: chest, front delts, biceps/forearms, core, quads.
    private var frontBlocks: [(MuscleRegion, CGRect)] {
        [
            (.shoulders, CGRect(x: 30, y: 32, width: 26, height: 12)),
            (.shoulders, CGRect(x: 76, y: 32, width: 26, height: 12)),
            (.chest, CGRect(x: 42, y: 47, width: 48, height: 24)),
            (.arms, CGRect(x: 20, y: 47, width: 15, height: 48)),
            (.arms, CGRect(x: 97, y: 47, width: 15, height: 48)),
            (.core, CGRect(x: 46, y: 73, width: 40, height: 30)),
            (.legs, CGRect(x: 44, y: 107, width: 19, height: 68)),
            (.legs, CGRect(x: 69, y: 107, width: 19, height: 68)),
        ]
    }

    /// Posterior view: the big Back block (lats/upper-mid back), rear delts,
    /// triceps, and the posterior legs (glutes/hamstrings/calves).
    private var backBlocks: [(MuscleRegion, CGRect)] {
        [
            (.shoulders, CGRect(x: 30, y: 32, width: 26, height: 12)),
            (.shoulders, CGRect(x: 76, y: 32, width: 26, height: 12)),
            (.back, CGRect(x: 42, y: 45, width: 48, height: 58)),
            (.arms, CGRect(x: 20, y: 47, width: 15, height: 48)),
            (.arms, CGRect(x: 97, y: 47, width: 15, height: 48)),
            (.legs, CGRect(x: 44, y: 107, width: 19, height: 68)),
            (.legs, CGRect(x: 69, y: 107, width: 19, height: 68)),
        ]
    }

    private func figure(title: String, blocks: [(MuscleRegion, CGRect)]) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(Color.primary.opacity(0.12))
                    .frame(width: 20, height: 20)
                    .position(x: 66, y: 13)

                ForEach(Array(blocks.enumerated()), id: \.offset) { _, item in
                    block(item.0, item.1)
                }
            }
            .frame(width: canvas.width, height: canvas.height)

            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
        }
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
