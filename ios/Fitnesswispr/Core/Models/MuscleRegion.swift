import Foundation

enum MuscleRegion: String, CaseIterable, Identifiable, Hashable {
    case shoulders = "Shoulders"
    case chest = "Chest"
    case back = "Back"
    case arms = "Arms"
    case core = "Core"
    case legs = "Legs"

    var id: String { rawValue }

    static let dueAfterDays = 5

    /// Best-effort mapping from the parser's free-form `muscle_group` (and the
    /// exercise name as a fallback) onto one of the body-map regions.
    static func classify(muscleGroup: String?, exerciseName: String) -> MuscleRegion? {
        let mg = (muscleGroup ?? "").lowercased()
        let name = exerciseName.lowercased()

        func has(_ haystack: String, _ keys: [String]) -> Bool {
            keys.contains { haystack.contains($0) }
        }

        if !mg.isEmpty {
            if has(mg, ["chest", "pec"]) { return .chest }
            if has(mg, ["shoulder", "delt"]) { return .shoulders }
            if has(mg, ["quad", "ham", "glute", "calf", "calves", "adductor", "abductor", "leg"]) { return .legs }
            if has(mg, ["back", "lat", "trap", "rhom", "erector", "spine"]) { return .back }
            if has(mg, ["bicep", "tricep", "forearm", "arm"]) { return .arms }
            if has(mg, ["core", "ab", "oblique"]) { return .core }
        }

        // Name-based fallback (order matters: legs before arms for "leg extension")
        if has(name, ["squat", "lunge", "deadlift", "rdl", "calf", "hip thrust", "leg press", "leg curl", "leg extension", "leg "]) { return .legs }
        if has(name, ["bench", "chest", "fly", "push up", "push-up", "pushup", "dip"]) { return .chest }
        if has(name, ["overhead", "ohp", "shoulder", "lateral raise", "arnold", "upright row"]) { return .shoulders }
        if has(name, ["row", "pulldown", "pull up", "pull-up", "pullup", "chin", "lat ", "face pull", "shrug"]) { return .back }
        if has(name, ["curl", "tricep", "pushdown", "skull", "extension"]) { return .arms }
        if has(name, ["crunch", "plank", "sit up", "sit-up", "situp", "leg raise", "ab "]) { return .core }
        return nil
    }
}

/// Navigation value for pushing a single exercise's progress screen.
struct ExerciseRef: Hashable {
    let name: String
}
