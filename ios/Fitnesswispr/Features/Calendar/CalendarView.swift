import SwiftUI

struct CalendarView: View {
    @StateObject private var vm = CalendarViewModel()
    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)
    private let dayLabels = ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]

    var body: some View {
        VStack(spacing: 0) {
            monthHeader
            weekdayRow
            calendarGrid
            Spacer()
        }
        .navigationTitle("Calendar")
        .navigationBarTitleDisplayMode(.inline)
        .task { await vm.fetchCalendar() }
        .sheet(item: Binding(
            get: { vm.selectedDate.map { IdentifiableString(value: $0) } },
            set: { _ in vm.selectedDate = nil }
        )) { item in
            DayWorkoutSheet(
                dateStr: item.value,
                sessions: vm.selectedSessions,
                onChanged: { Task { await vm.fetchCalendar() } }
            )
            .presentationDetents([.medium, .large])
        }
    }

    private var monthHeader: some View {
        HStack {
            Button(action: {
                vm.prevMonth()
                Task { await vm.fetchCalendar() }
            }) {
                Image(systemName: "chevron.left")
            }
            Spacer()
            Text(monthTitle).font(.headline)
            Spacer()
            Button(action: {
                vm.nextMonth()
                Task { await vm.fetchCalendar() }
            }) {
                Image(systemName: "chevron.right")
            }
        }
        .padding()
    }

    private var monthTitle: String {
        let components = DateComponents(year: vm.currentYear, month: vm.currentMonth)
        guard let date = calendar.date(from: components) else {
            return "\(vm.currentYear)-\(vm.currentMonth)"
        }
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: date)
    }

    private var weekdayRow: some View {
        HStack {
            ForEach(dayLabels, id: \.self) { label in
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal)
    }

    private var calendarGrid: some View {
        let days = daysInMonth()
        return LazyVGrid(columns: columns, spacing: 4) {
            ForEach(0..<days.count, id: \.self) { i in
                if let day = days[i] {
                    let dateStr = dateString(day: day)
                    let entry = vm.workoutDays[dateStr]   // String??
                    let hasWorkout = entry != nil
                    let workoutType: String? = entry ?? nil  // flatten String?? -> String?
                    CalendarDayCell(
                        day: day,
                        workoutType: workoutType,
                        hasWorkout: hasWorkout,
                        isToday: dateStr == Date().apiDateString,
                        isSelected: vm.selectedDate == dateStr
                    )
                    .onTapGesture {
                        if hasWorkout {
                            Task { await vm.selectDate(dateStr) }
                        }
                    }
                } else {
                    Color.clear.frame(height: 44)
                }
            }
        }
        .padding(.horizontal)
    }

    private func daysInMonth() -> [Int?] {
        let components = DateComponents(year: vm.currentYear, month: vm.currentMonth, day: 1)
        guard let firstDay = calendar.date(from: components) else { return [] }
        let weekday = calendar.component(.weekday, from: firstDay) - 1
        guard let range = calendar.range(of: .day, in: .month, for: firstDay),
              range.count > 0 else { return [] }

        var result: [Int?] = Array(repeating: nil, count: weekday)
        result += (1...range.count).map { Optional($0) }
        return result
    }

    private func dateString(day: Int) -> String {
        String(format: "%04d-%02d-%02d", vm.currentYear, vm.currentMonth, day)
    }
}

struct IdentifiableString: Identifiable {
    var id: String { value }   // stable id so the sheet doesn't re-present on re-render
    let value: String
}
