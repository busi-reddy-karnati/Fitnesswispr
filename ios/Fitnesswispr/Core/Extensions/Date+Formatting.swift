import Foundation

extension Date {
    var apiDateString: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: self)
    }

    var displayString: String {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f.string(from: self)
    }

    static func from(apiString: String) -> Date? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: apiString)
    }
}
