import SwiftUI

struct MuscleDetailView: View {
    let region: MuscleRegion
    @ObservedObject var store: ProgressStore

    var body: some View {
        let summary = store.summary(for: region)

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                coachCard(summary)

                if summary.exercises.isEmpty {
                    EmptyStateView(
                        icon: "dumbbell",
                        title: "No \(region.rawValue.lowercased()) exercises yet",
                        message: "Log a \(region.rawValue.lowercased()) workout and it will show up here."
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.top, 24)
                } else {
                    Text("YOUR EXERCISES")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                    ForEach(summary.exercises) { ex in
                        NavigationLink(value: ExerciseRef(name: ex.name)) {
                            ExerciseRow(summary: ex)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding()
        }
        .navigationTitle(region.rawValue)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func coachCard(_ summary: MuscleSummary) -> some View {
        let due = summary.isDue
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(statusText(summary))
                    .font(.caption.weight(.semibold))
                    .foregroundColor(due ? .white : .secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(due ? Color.appAccent : Color.gray.opacity(0.2))
                    .clipShape(Capsule())
                Spacer()
                Text("\(summary.exercises.count) tracked")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Text(coachNote(summary))
                .font(.subheadline)
                .foregroundColor(.primary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func statusText(_ s: MuscleSummary) -> String {
        guard let days = s.daysSince else { return "Not trained yet" }
        return s.isDue ? "Due · \(days)d" : daysAgoText(s.lastDate).capitalized
    }

    private func coachNote(_ s: MuscleSummary) -> String {
        guard let days = s.daysSince else {
            return "No \(s.region.rawValue.lowercased()) sessions logged yet — add one to start tracking progress."
        }
        if s.isDue {
            return "Overdue — last trained \(days) days ago. A good day to prioritize \(s.region.rawValue.lowercased())."
        }
        if days <= 1 {
            return "Trained recently. Give it a day or so to recover before hitting it hard again."
        }
        return "On track — last trained \(days) days ago."
    }
}

struct ExerciseRow: View {
    let summary: ExerciseSummary

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(summary.name)
                    .font(.body.weight(.semibold))
                    .foregroundColor(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            if summary.points.count > 1 {
                SparklineView(values: summary.points.map(\.value))
            }
            VStack(alignment: .trailing, spacing: 0) {
                if let latest = summary.latest {
                    Text(formatted(latest.value))
                        .font(.headline)
                        .foregroundColor(.primary)
                    + Text(" \(summary.unit)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Text("latest").font(.caption2).foregroundColor(.secondary)
            }
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var subtitle: String {
        guard let latest = summary.latest else { return "" }
        let setsText: String
        if let reps = latest.reps {
            setsText = "\(latest.sets)×\(reps)"
        } else {
            setsText = latest.sets == 1 ? "1 set" : "\(latest.sets) sets"
        }
        return "\(setsText) · \(daysAgoText(summary.lastDate))"
    }

    private func formatted(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(value))
            : String(format: "%.1f", value)
    }
}
