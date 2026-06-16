import SwiftUI

/// Reviews a parsed import, asks the few questions needed (who, units, start
/// date), and commits the workouts.
struct ImportPreviewView: View {
    let preview: ImportPreviewResponse
    let onImport: ([ImportCommitItem]) -> Void
    @Environment(\.dismiss) private var dismiss

    @ObservedObject private var profile = ProfileStore.shared

    @State private var mapping: [String: String] = [:]
    @State private var unit: String
    @State private var startDate: Date

    private let skipID = "__skip__"

    init(preview: ImportPreviewResponse, onImport: @escaping ([ImportCommitItem]) -> Void) {
        self.preview = preview
        self.onImport = onImport
        _unit = State(initialValue: preview.detectedUnit)
        // Default the program start so the latest week lands near today.
        let maxWeek = preview.workouts.compactMap { $0.week }.max() ?? 1
        let back = -((maxWeek - 1) * 7)
        _startDate = State(initialValue: Calendar.current.date(byAdding: .day, value: back, to: Date()) ?? Date())
    }

    var body: some View {
        NavigationStack {
            Form {
                summarySection
                if !preview.people.isEmpty {
                    peopleSection
                } else {
                    Section("Importing to") {
                        Label(profile.active.name, systemImage: "person.fill")
                    }
                }
                optionsSection
                workoutsSection
            }
            .navigationTitle("Review import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Import") { commit() }
                        .fontWeight(.semibold)
                        .disabled(buildItems().isEmpty)
                }
            }
            .onAppear(perform: seedMapping)
        }
    }

    // MARK: Sections

    private var summarySection: some View {
        Section {
            Label(preview.summary, systemImage: "doc.text.magnifyingglass")
                .font(.subheadline)
        }
    }

    private var peopleSection: some View {
        Section("Who is this for?") {
            ForEach(preview.people, id: \.self) { person in
                Picker(person, selection: bindingFor(person)) {
                    ForEach(profile.profiles) { p in
                        Text(p.name).tag(p.id)
                    }
                    Text("Don't import").tag(skipID)
                }
            }
        }
    }

    private var optionsSection: some View {
        Section {
            Picker("Units", selection: $unit) {
                Text("lbs").tag("lbs")
                Text("kg").tag("kg")
            }
            .pickerStyle(.segmented)

            if preview.needsStartDate {
                DatePicker("Week 1 started", selection: $startDate, displayedComponents: .date)
            }
        } footer: {
            if preview.needsStartDate {
                Text("Workout dates are estimated from the week/day in your sheet, anchored to this start date. You can edit any workout later.")
            }
        }
    }

    private var workoutsSection: some View {
        Section("Preview") {
            ForEach(preview.workouts) { w in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(headline(for: w))
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text(dateString(for: w))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    ForEach(w.exercises) { ex in
                        Text("• \(ex.name) — \(setSummary(ex))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    // MARK: Logic

    private func seedMapping() {
        guard mapping.isEmpty else { return }
        for person in preview.people {
            let match = profile.profiles.first { $0.name.lowercased() == person.lowercased() }
                ?? profile.profiles.first { $0.name.lowercased().contains(person.lowercased()) || person.lowercased().contains($0.name.lowercased()) }
            // No name match → default to the owner (You); the user can change it.
            mapping[person] = match?.id ?? profile.profiles.first?.id ?? skipID
        }
    }

    private func bindingFor(_ person: String) -> Binding<String> {
        Binding(
            get: { mapping[person] ?? skipID },
            set: { mapping[person] = $0 }
        )
    }

    private func headline(for w: ImportWorkoutDTO) -> String {
        var parts: [String] = []
        if let p = w.person { parts.append(p) }
        if let wk = w.week { parts.append("Wk \(wk)") }
        parts.append(w.workoutType ?? "Workout")
        return parts.joined(separator: " · ")
    }

    private func dateString(for w: ImportWorkoutDTO) -> String {
        if let ds = w.workoutDate, !ds.isEmpty { return ds }
        let week = max((w.week ?? 1) - 1, 0)
        let dayOffset = min(max((w.day ?? 1) - 1, 0) * 2, 6)
        let d = Calendar.current.date(byAdding: .day, value: week * 7 + dayOffset, to: startDate) ?? startDate
        return d.apiDateString
    }

    private func setSummary(_ ex: ImportExerciseDTO) -> String {
        guard let first = ex.sets.first else { return "—" }
        if ex.sets.allSatisfy({ $0.reps == first.reps && $0.weight == first.weight }) {
            let reps = first.reps.map { "\($0)" } ?? "—"
            if let w = first.weight { return "\(ex.sets.count)×\(reps) @ \(fmt(w)) \(unit)" }
            if let s = first.durationSeconds { return "\(ex.sets.count)×\(s)s" }
            return "\(ex.sets.count)×\(reps)"
        }
        return ex.sets.map { s in
            let r = s.reps.map { "\($0)" } ?? "—"
            if let w = s.weight { return "\(r)@\(fmt(w))" }
            return r
        }.joined(separator: ", ")
    }

    private func fmt(_ v: Double) -> String { v == v.rounded() ? String(Int(v)) : String(v) }

    private func buildItems() -> [ImportCommitItem] {
        preview.workouts.compactMap { w in
            let targetID: String
            if preview.people.isEmpty {
                targetID = profile.activeID
            } else {
                guard let person = w.person,
                      let mapped = mapping[person], mapped != skipID else { return nil }
                targetID = mapped
            }
            var exercises = w.exercises
            if unit != preview.detectedUnit {
                exercises = exercises.map { ex in
                    var e = ex
                    e.sets = e.sets.map { var s = $0; s.weightUnit = unit; return s }
                    return e
                }
            }
            return ImportCommitItem(
                deviceUuid: targetID,
                workoutDate: dateString(for: w),
                workoutType: w.workoutType,
                source: "import",
                exercises: exercises
            )
        }
    }

    private func commit() {
        onImport(buildItems())
        dismiss()
    }
}
