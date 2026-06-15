import SwiftUI

final class UserPreferences: ObservableObject {
    @AppStorage("unit_preference") var unitPreference: String = "lbs"
}
