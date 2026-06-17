import Foundation

/// Canonicalizes exercise names so trivial variations are treated as the same
/// movement and merged in summaries/graphs:
/// - case + surrounding/duplicate whitespace + punctuation
/// - singular/plural ("Leg Extension" == "Leg Extensions")
/// - a curated set of synonyms ("Seated Leg Press" == "Leg Press")
enum ExerciseName {
    /// Stable key used to group/merge exercises that are really the same thing.
    static func canonicalKey(_ raw: String) -> String {
        let normalized = normalize(raw)
        return aliases[normalized] ?? normalized
    }

    /// Whether two free-form names refer to the same movement.
    static func sameExercise(_ a: String, _ b: String) -> Bool {
        canonicalKey(a) == canonicalKey(b)
    }

    /// Lowercased, de-punctuated, whitespace-collapsed, singularized form.
    static func normalize(_ raw: String) -> String {
        let scalars = raw.lowercased().unicodeScalars.map { scalar -> Character in
            CharacterSet.alphanumerics.contains(scalar) ? Character(scalar) : " "
        }
        return String(scalars)
            .split(separator: " ")
            .map(singularize)
            .joined(separator: " ")
    }

    /// Best-effort English singularization tuned for gym vocabulary. Keeps words
    /// that genuinely end in "ss" (press), maps "-ies"→"y" (flies→fly) and
    /// "-ves"→"f" (calves→calf), and strips a trailing plural "s" otherwise.
    private static func singularize(_ word: Substring) -> String {
        let w = String(word)
        guard w.count > 3 else { return w }            // abs, leg, row, dip...
        if w.hasSuffix("ss") { return w }              // press, cross
        if w.hasSuffix("ies") { return String(w.dropLast(3)) + "y" }
        if w.hasSuffix("ves") { return String(w.dropLast(3)) + "f" }
        for suffix in ["ches", "shes", "xes", "zes", "ses"] where w.hasSuffix(suffix) {
            return String(w.dropLast(2))               // crunches→crunch, presses→press
        }
        if w.hasSuffix("s") { return String(w.dropLast()) }
        return w
    }

    /// Groups of names that mean the same movement. The first entry is canonical.
    /// Every entry is matched in its `normalize`d form, so list natural spellings.
    private static let synonymGroups: [[String]] = [
        ["Leg Press", "Seated Leg Press", "Horizontal Leg Press", "Machine Leg Press"],
        ["Lat Pulldown", "Lat Pull Down"],
        ["Chest Press", "Machine Chest Press", "Seated Chest Press"],
        ["Shoulder Press", "Seated Shoulder Press", "Overhead Press", "OHP"],
        ["Romanian Deadlift", "RDL"],
    ]

    private static let aliases: [String: String] = {
        var map: [String: String] = [:]
        for group in synonymGroups {
            guard let canonical = group.first.map(normalize) else { continue }
            for variant in group { map[normalize(variant)] = canonical }
        }
        return map
    }()
}
