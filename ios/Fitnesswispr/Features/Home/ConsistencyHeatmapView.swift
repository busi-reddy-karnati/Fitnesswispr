import SwiftUI

struct ConsistencyHeatmapView: View {
    let intensities: [String: Int]
    var weeks: Int = 26
    var onSelectDay: ((Date) -> Void)? = nil

    private let cell: CGFloat = 22
    private let gap: CGFloat = 4
    private let labelWidth: CGFloat = 26
    private let monthRowHeight: CGFloat = 14

    @State private var selected: Date = Calendar.current.startOfDay(for: Date())

    private let weekdayLabels = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    private let monthAbbrev = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

    var body: some View {
        let grid = buildGrid()

        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: gap) {
                weekdayColumn
                weeksScroller(grid)
            }
            readout
            legend
        }
    }

    // MARK: - Pinned weekday labels

    private var weekdayColumn: some View {
        VStack(spacing: gap) {
            Color.clear.frame(width: labelWidth, height: monthRowHeight)
            ForEach(0..<7, id: \.self) { row in
                Text(weekdayLabels[row])
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                    .frame(width: labelWidth, height: cell, alignment: .leading)
            }
        }
    }

    // MARK: - Scrollable weeks (starts at the most recent week)

    private func weeksScroller(_ grid: [[Date?]]) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                VStack(alignment: .leading, spacing: gap) {
                    HStack(spacing: gap) {
                        ForEach(0..<grid.count, id: \.self) { col in
                            Text(monthLabel(grid, col: col))
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                                .frame(width: cell, height: monthRowHeight, alignment: .leading)
                        }
                    }

                    HStack(alignment: .top, spacing: gap) {
                        ForEach(0..<grid.count, id: \.self) { col in
                            VStack(spacing: gap) {
                                ForEach(0..<7, id: \.self) { row in
                                    cellView(grid[col][row])
                                }
                            }
                            .id(col)
                        }
                    }
                }
                .padding(.trailing, 2)
            }
            .onAppear { proxy.scrollTo(grid.count - 1, anchor: .trailing) }
        }
    }

    private func cellView(_ date: Date?) -> some View {
        let isSelected = date != nil && Calendar.current.isDate(date!, inSameDayAs: selected)
        let isToday = date != nil && Calendar.current.isDateInToday(date!)
        return RoundedRectangle(cornerRadius: 4)
            .fill(color(for: date))
            .frame(width: cell, height: cell)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(
                        isSelected ? Color.primary : (isToday ? Color.secondary : Color.clear),
                        lineWidth: isSelected ? 2 : 1.5
                    )
            )
            .contentShape(Rectangle())
            .onTapGesture {
                if let date {
                    selected = date
                    onSelectDay?(date)
                }
            }
    }

    // MARK: - Readout

    private var readout: some View {
        let key = selected.apiDateString
        let sets = intensities[key] ?? 0
        let weekday = weekdayLabels[Calendar.current.component(.weekday, from: selected) - 1]
        let month = monthAbbrev[Calendar.current.component(.month, from: selected) - 1]
        let day = Calendar.current.component(.day, from: selected)
        let setsText = sets == 0 ? "no workout" : "\(sets) \(sets == 1 ? "set" : "sets")"

        return HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color(forSets: sets))
                .frame(width: 10, height: 10)
            Text("\(weekday) · \(month) \(day)")
                .font(.caption.weight(.semibold))
            Text("· \(setsText)")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text("tap a day to open")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    private var legend: some View {
        HStack(spacing: 6) {
            Text("Less").font(.caption2).foregroundColor(.secondary)
            ForEach(0..<5, id: \.self) { level in
                RoundedRectangle(cornerRadius: 2)
                    .fill(colorForLevel(level))
                    .frame(width: 11, height: 11)
            }
            Text("More").font(.caption2).foregroundColor(.secondary)
        }
    }

    // MARK: - Grid construction

    /// Columns of 7 days (row 0 = Sunday). Future days are nil.
    private func buildGrid() -> [[Date?]] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let weekdayIdx = cal.component(.weekday, from: today) - 1 // 0 = Sunday
        guard let startSunday = cal.date(byAdding: .day, value: -((weeks - 1) * 7 + weekdayIdx), to: today) else {
            return []
        }
        var grid: [[Date?]] = []
        for col in 0..<weeks {
            var column: [Date?] = []
            for row in 0..<7 {
                let date = cal.date(byAdding: .day, value: col * 7 + row, to: startSunday)
                if let date, date <= today {
                    column.append(date)
                } else {
                    column.append(nil)
                }
            }
            grid.append(column)
        }
        return grid
    }

    /// Month abbreviation shown above a column when its month differs from the
    /// previous column (or it's the first column).
    private func monthLabel(_ grid: [[Date?]], col: Int) -> String {
        let cal = Calendar.current
        guard let top = grid[col].first ?? nil else { return "" }
        let month = cal.component(.month, from: top)
        if col == 0 { return monthAbbrev[month - 1] }
        if let prevTop = grid[col - 1].first ?? nil {
            let prevMonth = cal.component(.month, from: prevTop)
            if prevMonth != month { return monthAbbrev[month - 1] }
        }
        return ""
    }

    // MARK: - Colors

    private func color(for date: Date?) -> Color {
        guard let date else { return .clear }
        return color(forSets: intensities[date.apiDateString] ?? 0)
    }

    private func color(forSets sets: Int) -> Color {
        let level: Int
        switch sets {
        case 0: level = 0
        case 1...4: level = 1
        case 5...9: level = 2
        case 10...14: level = 3
        default: level = 4
        }
        return colorForLevel(level)
    }

    private func colorForLevel(_ level: Int) -> Color {
        switch level {
        case 0: return Color.gray.opacity(0.16)
        case 1: return Color.appAccent.opacity(0.35)
        case 2: return Color.appAccent.opacity(0.55)
        case 3: return Color.appAccent.opacity(0.78)
        default: return Color.appAccent
        }
    }
}
