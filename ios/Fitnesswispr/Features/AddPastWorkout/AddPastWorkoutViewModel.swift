import Foundation

@MainActor
final class AddPastWorkoutViewModel: ObservableObject {
    @Published var selectedDate = Date()

    let recordViewModel: RecordViewModel

    init(preferences: UserPreferences) {
        self.recordViewModel = RecordViewModel(preferences: preferences)
    }

    func saveWithDate(parsed: ParsedSession) {
        recordViewModel.confirmAndSave(parsed: parsed, workoutDate: selectedDate)
    }
}
