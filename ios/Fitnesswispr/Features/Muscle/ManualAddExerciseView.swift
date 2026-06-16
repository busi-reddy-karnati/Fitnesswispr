import SwiftUI

/// Quick, type-it-in exercise logging (no voice) for a specific muscle group.
struct ManualAddExerciseView: View {
    let region: MuscleRegion
    let prefillName: String?
    var onSaved: (WorkoutSession) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var date = Date()
    @State private var sets: [DraftSet] = [DraftSet()]
    @State private var saving = false
    @State private var error: String?

    private let unit = UserPreferences().unitPreference

    struct DraftSet: Identifiable {
        let id = UUID()
        var reps = ""
        var weight = ""
    }

    init(region: MuscleRegion, prefillName: String? = nil, onSaved: @escaping (WorkoutSession) -> Void) {
        self.region = region
        self.prefillName = prefillName
        self.onSaved = onSaved
        _name = State(initialValue: prefillName ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Exercise") {
                    TextField("Name (e.g. Bench Press)", text: $name)
                        .textInputAutocapitalization(.words)
                    DatePicker("Date", selection: $date, in: ...Date(), displayedComponents: .date)
                }

                Section("Sets") {
                    ForEach($sets) { $s in
                        HStack(spacing: 12) {
                            TextField("Reps", text: $s.reps)
                                .keyboardType(.numberPad)
                                .frame(width: 70)
                            Divider()
                            TextField("Weight", text: $s.weight)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                            Text(unit).foregroundColor(.secondary)
                        }
                    }
                    .onDelete { sets.remove(atOffsets: $0) }

                    Button {
                        sets.append(DraftSet())
                    } label: {
                        Label("Add set", systemImage: "plus.circle")
                    }
                }

                if let error {
                    Text(error).font(.caption).foregroundColor(.red)
                }
            }
            .navigationTitle("Add \(region.rawValue)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || saving)
                }
            }
            .overlay {
                if saving { LoadingOverlay(message: "Saving...") }
            }
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        let parsedSets: [ExerciseSet] = sets.enumerated().compactMap { index, draft in
            let reps = Int(draft.reps.trimmingCharacters(in: .whitespaces))
            let weight = Double(draft.weight.trimmingCharacters(in: .whitespaces))
            guard reps != nil || weight != nil else { return nil }
            return ExerciseSet(
                setNumber: index + 1,
                reps: reps,
                weight: weight,
                weightUnit: unit,
                durationSeconds: nil
            )
        }
        let finalSets = parsedSets.isEmpty
            ? [ExerciseSet(setNumber: 1, reps: nil, weight: nil, weightUnit: unit, durationSeconds: nil)]
            : parsedSets

        let exercise = Exercise(
            exerciseId: nil,
            name: trimmedName,
            equipment: nil,
            muscleGroup: region.rawValue,
            notes: nil,
            sets: finalSets
        )
        let req = CreateSessionRequest(
            deviceUuid: ProfileStore.shared.activeID,
            workoutDate: date.apiDateString,
            source: "manual",
            rawTranscript: nil,
            workoutType: region.rawValue,
            bodyWeightLbs: nil,
            cardioNotes: nil,
            sessionNotes: nil,
            exercises: [exercise]
        )

        saving = true
        Task {
            do {
                let created: WorkoutSession = try await APIClient.shared.post(APIEndpoints.sessions, body: req)
                saving = false
                onSaved(created)
                dismiss()
            } catch {
                self.error = "Couldn't save: \(error.localizedDescription)"
                saving = false
            }
        }
    }
}
