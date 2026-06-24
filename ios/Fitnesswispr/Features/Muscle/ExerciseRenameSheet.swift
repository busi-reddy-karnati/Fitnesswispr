import SwiftUI

/// Rename an exercise everywhere it's been logged, or merge it with other
/// near-identical exercises under one clean name. Renaming uses canonical
/// matching (so plural/synonym variants of the same movement fold in too);
/// merging uses exact matching across the picked names.
struct ExerciseRenameSheet: View {
    let currentName: String
    @ObservedObject var store: ProgressStore
    /// Called after a successful rename so the caller can pop the now-renamed
    /// progress screen.
    var onRenamed: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var newName: String
    @State private var mergeSelections: Set<String> = []
    @State private var isApplying = false
    @State private var error: String?

    init(currentName: String, store: ProgressStore, onRenamed: @escaping (String) -> Void) {
        self.currentName = currentName
        self.store = store
        self.onRenamed = onRenamed
        _newName = State(initialValue: currentName)
    }

    /// Likely merge candidates only — exercises in the same muscle region or
    /// with a similar name, most-similar first. We don't list the user's whole
    /// catalog; anything already selected is always kept visible.
    private var mergeCandidates: [String] {
        let regions = store.exerciseRegions()
        let curKey = key(currentName)
        let curRegion = regions[curKey]
        let curTokens = Self.tokens(currentName)

        let others = store.distinctExerciseNames().filter {
            $0.caseInsensitiveCompare(currentName) != .orderedSame
        }

        func score(_ name: String) -> Int {
            let overlap = curTokens.intersection(Self.tokens(name)).count
            let sameRegion = (curRegion != nil && regions[key(name)] == curRegion) ? 1 : 0
            return overlap * 3 + sameRegion
        }

        let ranked = others
            .map { (name: $0, score: score($0)) }
            .sorted { $0.score > $1.score }

        // Keep only the relevant ones (shared word or same region), capped.
        var result = ranked.filter { $0.score > 0 }.prefix(12).map(\.name)
        // Always show what's already ticked, even if it scored 0.
        for sel in mergeSelections where !result.contains(sel) { result.append(sel) }
        return result
    }

    private var trimmedName: String {
        newName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canApply: Bool {
        !trimmedName.isEmpty && !isApplying
            && (trimmedName != currentName || !mergeSelections.isEmpty)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("New name") {
                    TextField("Exercise name", text: $newName)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                }

                if !mergeCandidates.isEmpty {
                    Section {
                        ForEach(mergeCandidates, id: \.self) { name in
                            Button {
                                toggle(name)
                            } label: {
                                HStack {
                                    Text(name)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Image(systemName: mergeSelections.contains(name)
                                          ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(mergeSelections.contains(name) ? .appAccent : .secondary)
                                }
                            }
                        }
                    } header: {
                        Text("Merge with")
                    } footer: {
                        if !mergeSelections.isEmpty {
                            Text("Selected exercises will be combined into “\(trimmedName)”.")
                        } else {
                            Text("Pick similar exercises that are really the same movement to merge them into one.")
                        }
                    }
                }

                if let error {
                    Section { Text(error).font(.footnote).foregroundColor(.red) }
                }
            }
            .navigationTitle("Rename exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isApplying {
                        ProgressView()
                    } else {
                        Button("Apply") { Task { await apply() } }
                            .disabled(!canApply)
                    }
                }
            }
        }
    }

    private func toggle(_ name: String) {
        if mergeSelections.contains(name) { mergeSelections.remove(name) }
        else { mergeSelections.insert(name) }
    }

    private func apply() async {
        isApplying = true
        defer { isApplying = false }
        let to = trimmedName
        let merging = !mergeSelections.isEmpty
        let fromNames = [currentName] + Array(mergeSelections)
        let match = merging ? "exact" : "canonical"
        do {
            let req = RenameExerciseRequest(
                deviceUuid: ProfileStore.shared.activeID,
                fromNames: fromNames,
                toName: to,
                match: match,
                dryRun: false
            )
            let _: RenameExerciseResponse = try await APIClient.shared.post(
                APIEndpoints.exercisesRename, body: req
            )
            store.applyRenameLocally(fromNames: fromNames, toName: to, match: match)
            dismiss()
            onRenamed(to)
        } catch {
            self.error = "Couldn't rename: \(error.localizedDescription)"
        }
    }

    private func key(_ s: String) -> String {
        s.lowercased().trimmingCharacters(in: .whitespaces)
    }

    /// Movement words for similarity matching: drop equipment/filler words and
    /// crudely singularize ("rows" -> "row").
    private static func tokens(_ s: String) -> Set<String> {
        let filler: Set<String> = [
            "the", "a", "with", "and", "of", "on", "machine",
            "barbell", "dumbbell", "cable", "smith", "seated", "standing",
        ]
        let parts = s.lowercased().split { !$0.isLetter }.map(String.init)
            .map { $0.count > 3 && $0.hasSuffix("s") ? String($0.dropLast()) : $0 }
            .filter { !$0.isEmpty && !filler.contains($0) }
        return Set(parts)
    }
}
