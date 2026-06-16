import SwiftUI

struct HomeView: View {
    @StateObject private var store = ProgressStore()
    @State private var showProfile = false
    @State private var selectedDay: IdentifiableString?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 26) {
                    consistencySection
                    bodySection
                    recordSection

                    if let error = store.error {
                        ErrorBanner(message: error) { store.error = nil }
                    }
                }
                .padding()
            }
            .navigationTitle("SpotRep")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showProfile = true } label: {
                        Image(systemName: "person.crop.circle")
                            .font(.title3)
                    }
                    .accessibilityLabel("Profile")
                }
            }
            .navigationDestination(for: MuscleRegion.self) { region in
                MuscleDetailView(region: region, store: store)
            }
            .navigationDestination(for: ExerciseRef.self) { ref in
                ExerciseProgressView(name: ref.name, store: store)
            }
            .sheet(isPresented: $showProfile) {
                ProfileView()
            }
            .sheet(item: $selectedDay) { item in
                DayWorkoutSheet(
                    dateStr: item.value,
                    sessions: store.sessions(on: item.value),
                    appleWorkouts: store.appleWorkouts(on: item.value)
                )
                .presentationDetents([.medium, .large])
            }
            .task { await store.loadIfNeeded() }
            .refreshable { await store.load() }
        }
    }

    // MARK: - Top: consistency

    private var consistencySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Label("\(store.currentStreak())-day streak", systemImage: "flame.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.appAccent)
                    .clipShape(Capsule())
                Spacer()
                Text(store.trainedToday() ? "Logged today" : "No workout yet today")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack {
                Text("CONSISTENCY")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
                Spacer()
                Text("Tap a day for details")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            ConsistencyHeatmapView(intensities: store.dayIntensities()) { day in
                selectedDay = IdentifiableString(value: day.apiDateString)
            }
        }
    }

    // MARK: - Middle: body map

    private var bodySection: some View {
        let summaries = store.allSummaries()
        let due = MuscleRegion.allCases
            .filter { summaries[$0]?.isDue ?? false }
            .map { $0.rawValue }

        return VStack(spacing: 10) {
            Text("TAP A MUSCLE TO TRAIN")
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)

            BodyMapView(summaries: summaries)

            if !due.isEmpty {
                Text("\(due.joined(separator: " & ")) \(due.count > 1 ? "are" : "is") due")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else if store.loaded {
                Text("Warm = trained recently")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Bottom: record

    private var recordSection: some View {
        VStack(spacing: 8) {
            Button {
                QuickActionCoordinator.shared.triggerRecordNow()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "mic.fill")
                    Text("Record a workout").font(.headline)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.appAccent)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            Text("or “Hey Siri, log a workout in SpotRep”")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}
