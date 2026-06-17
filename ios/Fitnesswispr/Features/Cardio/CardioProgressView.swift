import SwiftUI
import Charts

/// Trends for a single cardio activity (e.g. Running): pace, distance and time
/// over the logged sessions. Intentionally lives apart from the strength PRs.
struct CardioProgressView: View {
    let activity: String
    /// When provided (e.g. from the home cache), used directly; otherwise the
    /// view loads the active profile's recent sessions itself.
    var sessions: [WorkoutSession]? = nil

    @State private var loaded: [WorkoutSession] = []
    @State private var isLoading = false
    @State private var metric: Metric = .pace
    @State private var selectedDate: Date?
    @State private var pendingDelete: CardioPoint?

    private enum Metric: String, CaseIterable, Identifiable {
        case pace = "Pace"
        case distance = "Distance"
        case duration = "Time"
        var id: String { rawValue }
        var lowerIsBetter: Bool { self == .pace }
    }

    private var effectiveSessions: [WorkoutSession] { sessions ?? loaded }
    private var progress: CardioProgress? {
        CardioProgress.build(activity: activity, sessions: effectiveSessions)
    }

    var body: some View {
        Group {
            if let p = progress {
                content(p)
            } else if isLoading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                EmptyStateView(
                    icon: "figure.run",
                    title: "No \(activity.lowercased()) yet",
                    message: "Log a \(activity.lowercased()) (e.g. “ran 3 miles in 25 min”) to see your trends."
                )
            }
        }
        .navigationTitle(activity)
        .navigationBarTitleDisplayMode(.inline)
        .task { if sessions == nil { await load() } }
        .confirmationDialog(
            "Delete this entry?",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            presenting: pendingDelete
        ) { pt in
            Button("Delete", role: .destructive) { delete(pt) }
            Button("Cancel", role: .cancel) {}
        } message: { pt in
            Text("\(rowSummary(pt)) on \(pt.date.formatted(.dateTime.month(.abbreviated).day().year()))")
        }
    }

    // MARK: - Content

    private func content(_ p: CardioProgress) -> some View {
        let metrics = availableMetrics(p)
        let active = metrics.contains(metric) ? metric : (metrics.first ?? .duration)
        let series = points(for: active, in: p)
        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                statsRow(p)

                if metrics.count > 1 {
                    Picker("Metric", selection: $metric) {
                        ForEach(metrics) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("\(active.rawValue.uppercased()) OVER TIME (\(unitLabel(active)))")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                    if series.count >= 2 {
                        chart(series, metric: active, progress: p)
                    } else {
                        Text("Log another \(activity.lowercased()) to see a trend.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, minHeight: 120)
                    }
                }

                recentList(p)
            }
            .padding()
        }
    }

    private func statsRow(_ p: CardioProgress) -> some View {
        HStack(spacing: 12) {
            if let pace = p.bestPace {
                statBox(title: "Best pace", value: "\(formatPace(pace)) /mi", tint: .green)
            } else if let longest = p.longestMiles {
                statBox(title: "Longest", value: "\(oneDecimal(longest)) mi", tint: .green)
            } else {
                statBox(title: "Total time", value: "\(p.totalMinutes) min", tint: .green)
            }
            if p.hasDistance {
                statBox(title: "Total distance", value: "\(oneDecimal(p.totalMiles)) mi", tint: .primary)
            } else {
                statBox(title: "Total time", value: "\(p.totalMinutes) min", tint: .primary)
            }
            statBox(title: "Sessions", value: "\(p.sessionsCount)", tint: .appAccent)
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

    // MARK: - Chart

    private struct Sample: Identifiable {
        let id = UUID()
        let date: Date
        let value: Double
    }

    private func chart(_ series: [Sample], metric: Metric, progress p: CardioProgress) -> some View {
        let best = metric.lowerIsBetter ? series.map(\.value).min() : series.map(\.value).max()
        let selected = selectedSample(series)
        return Chart {
            ForEach(series) { s in
                LineMark(x: .value("Date", s.date), y: .value(metric.rawValue, s.value))
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(Color.appAccent)
                PointMark(x: .value("Date", s.date), y: .value(metric.rawValue, s.value))
                    .foregroundStyle(Color.appAccent)
            }
            if let best {
                RuleMark(y: .value("Best", best))
                    .foregroundStyle(Color.green.opacity(0.6))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5]))
                    .annotation(position: .top, alignment: .trailing) {
                        Text("Best \(displayValue(best, metric))")
                            .font(.caption2).foregroundColor(.green)
                    }
            }
            if let selected {
                RuleMark(x: .value("Date", selected.date))
                    .foregroundStyle(Color.secondary.opacity(0.25))
                    .annotation(position: .top, spacing: 0, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                        bubble(selected, metric: metric)
                    }
                PointMark(x: .value("Date", selected.date), y: .value(metric.rawValue, selected.value))
                    .foregroundStyle(Color.appAccent)
                    .symbolSize(160)
            }
        }
        .chartYScale(domain: .automatic(includesZero: false))
        .chartXSelection(value: $selectedDate)
        .frame(height: 220)
    }

    private func bubble(_ s: Sample, metric: Metric) -> some View {
        VStack(spacing: 1) {
            Text(displayValue(s.value, metric))
                .font(.caption.weight(.semibold)).foregroundColor(.primary)
            Text(s.date.formatted(.dateTime.month(.abbreviated).day()))
                .font(.caption2).foregroundColor(.secondary)
        }
        .padding(.horizontal, 8).padding(.vertical, 5)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.12), radius: 3, y: 1)
    }

    // MARK: - Recent sessions

    private func recentList(_ p: CardioProgress) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("RECENT")
                .font(.caption.weight(.semibold)).foregroundColor(.secondary)
            ForEach(p.points.reversed().prefix(10).map { $0 }) { pt in
                HStack {
                    Text(pt.date.formatted(.dateTime.month(.abbreviated).day().year()))
                        .font(.subheadline)
                    Spacer()
                    Text(rowSummary(pt))
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.secondary)
                    if canWrite, pt.sessionId != nil {
                        Button { pendingDelete = pt } label: {
                            Image(systemName: "trash")
                                .font(.footnote)
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                        .padding(.leading, 8)
                    }
                }
                .padding(.vertical, 6)
                Divider()
            }
        }
    }

    private func rowSummary(_ pt: CardioPoint) -> String {
        var parts: [String] = []
        if let mi = pt.distanceMiles { parts.append("\(oneDecimal(mi)) mi") }
        if let m = pt.durationMinutes { parts.append("\(m) min") }
        if let pace = pt.paceMinPerMile { parts.append("\(formatPace(pace)) /mi") }
        return parts.joined(separator: " · ")
    }

    // MARK: - Helpers

    private func availableMetrics(_ p: CardioProgress) -> [Metric] {
        var m: [Metric] = []
        if p.hasPace { m.append(.pace) }
        if p.hasDistance { m.append(.distance) }
        if p.hasDuration { m.append(.duration) }
        return m.isEmpty ? [.duration] : m
    }

    private func points(for metric: Metric, in p: CardioProgress) -> [Sample] {
        p.points.compactMap { pt in
            let v: Double?
            switch metric {
            case .pace: v = pt.paceMinPerMile
            case .distance: v = pt.distanceMiles
            case .duration: v = pt.durationMinutes.map(Double.init)
            }
            guard let value = v else { return nil }
            return Sample(date: pt.date, value: value)
        }
    }

    private func unitLabel(_ metric: Metric) -> String {
        switch metric {
        case .pace: return "min/mi"
        case .distance: return "mi"
        case .duration: return "min"
        }
    }

    private func displayValue(_ value: Double, _ metric: Metric) -> String {
        switch metric {
        case .pace: return formatPace(value)
        case .distance: return oneDecimal(value)
        case .duration: return String(Int(value.rounded()))
        }
    }

    private func selectedSample(_ series: [Sample]) -> Sample? {
        guard let selectedDate else { return nil }
        return series.min {
            abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate))
        }
    }

    private func oneDecimal(_ v: Double) -> String {
        v.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(v)) : String(format: "%.1f", v)
    }

    private var canWrite: Bool { ProfileStore.shared.active.canWrite }

    /// Delete a cardio entry: drop it locally for an instant update, hit the API,
    /// and notify the rest of the app to refresh its caches.
    private func delete(_ pt: CardioPoint) {
        guard let id = pt.sessionId else { return }
        loaded.removeAll { $0.sessionId == id }
        pendingDelete = nil
        Task {
            try? await APIClient.shared.delete(APIEndpoints.session(id))
            NotificationCenter.default.post(name: .workoutLogged, object: nil)
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        let uuid = ProfileStore.shared.activeID
        let end = Date()
        let start = Calendar.current.date(byAdding: .day, value: -365, to: end) ?? end
        let url = APIEndpoints.sessions(
            deviceUUID: uuid,
            startDate: start.apiDateString,
            endDate: end.apiDateString,
            limit: 200
        )
        if let result: [WorkoutSession] = try? await APIClient.shared.get(url) {
            loaded = result
        }
    }
}
