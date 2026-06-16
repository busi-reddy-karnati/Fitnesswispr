import SwiftUI

struct ConsistencyHeatmapView: View {
    let intensities: [String: Int]
    var weeks: Int = 18
    var onSelectDay: ((Date) -> Void)? = nil

    private let gap: CGFloat = 3
    @State private var width: CGFloat = 0

    var body: some View {
        let cell = width > 0 ? max((width - gap * CGFloat(weeks - 1)) / CGFloat(weeks), 1) : 0
        let grid = buildGrid()

        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: gap) {
                ForEach(0..<grid.count, id: \.self) { col in
                    VStack(spacing: gap) {
                        ForEach(0..<7, id: \.self) { row in
                            let day = grid[col][row]
                            RoundedRectangle(cornerRadius: 2)
                                .fill(color(for: day))
                                .frame(width: cell, height: cell)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if let day { onSelectDay?(day) }
                                }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: cell * 7 + gap * 6)
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onAppear { width = geo.size.width }
                        .onChange(of: geo.size.width) { _, newValue in width = newValue }
                }
            )

            HStack(spacing: 6) {
                Text("Less").font(.caption2).foregroundColor(.secondary)
                ForEach(0..<5, id: \.self) { level in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(colorForLevel(level))
                        .frame(width: 10, height: 10)
                }
                Text("More").font(.caption2).foregroundColor(.secondary)
            }
        }
    }

    // Each cell is a Date (or nil for future days).
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

    private func color(for date: Date?) -> Color {
        guard let date else { return .clear }
        let sets = intensities[date.apiDateString] ?? 0
        if sets == 0 { return Color.gray.opacity(0.16) }
        let level: Int
        switch sets {
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
