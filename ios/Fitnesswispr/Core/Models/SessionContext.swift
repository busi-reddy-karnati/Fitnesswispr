import Foundation

struct SessionContext {
    var bodyWeightLbs: Double?

    mutating func merge(from session: ParsedSession) {
        if let bw = session.bodyWeightLbs { bodyWeightLbs = bw }
    }
}
