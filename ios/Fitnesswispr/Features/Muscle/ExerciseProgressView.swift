import SwiftUI
import Charts

struct ExerciseProgressView: View {
    let name: String
    @ObservedObject var store: ProgressStore

    var body: some View {
        Group {
            if let summary = store.summary(forExercise: name) {
                content(summary)
            } else {
                EmptyStateView(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "No data yet",
                    message: "Log this exercise to see your progress."
                )
            }
        }
        .navigationTitle(name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func content(_ s: ExerciseSummary) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                statsRow(s)

                VStack(alignment: .leading, spacing: 8) {
                    Text("\(s.metricLabel.uppercased()) OVER TIME (\(s.unit))")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                    chart(s)
                    Text("Source: your logged sets · last \(s.points.count) session\(s.points.count == 1 ? "" : "s")")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
        }
    }

    private func statsRow(_ s: ExerciseSummary) -> some View {
        HStack(spacing: 12) {
            statBox(title: "Latest", value: "\(formatted(s.latest?.value ?? 0)) \(s.unit)", tint: .primary)
            statBox(title: "Personal record", value: "\(formatted(s.personalRecord)) \(s.unit)", tint: .green)
            statBox(
                title: "Change",
                value: "\(s.gain >= 0 ? "+" : "")\(formatted(s.gain)) \(s.unit)",
                tint: s.gain >= 0 ? .green : .red
            )
        }
    }

    private func statBox(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.title3.weight(.bold)).foregroundColor(tint)
            Text(title).font(.caption2).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func chart(_ s: ExerciseSummary) -> some View {
        Chart {
            ForEach(s.points) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value(s.metricLabel, point.value)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(Color.appAccent)

                PointMark(
                    x: .value("Date", point.date),
                    y: .value(s.metricLabel, point.value)
                )
                .foregroundStyle(Color.appAccent)
            }

            RuleMark(y: .value("PR", s.personalRecord))
                .foregroundStyle(Color.green.opacity(0.6))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [5]))
                .annotation(position: .top, alignment: .trailing) {
                    Text("PR \(formatted(s.personalRecord))")
                        .font(.caption2)
                        .foregroundColor(.green)
                }
        }
        .chartYScale(domain: .automatic(includesZero: false))
        .frame(height: 220)
    }

    private func formatted(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(value))
            : String(format: "%.1f", value)
    }
}
