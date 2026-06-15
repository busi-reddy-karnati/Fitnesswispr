import SwiftUI

struct AddPastWorkoutView: View {
    @StateObject private var vm: AddPastWorkoutViewModel

    init() {
        _vm = StateObject(wrappedValue: AddPastWorkoutViewModel(preferences: UserPreferences()))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                DatePicker("Workout Date", selection: $vm.selectedDate, in: ...Date(), displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .padding()

                RecordView()
            }
            .navigationTitle("Add Past Workout")
        }
    }
}
