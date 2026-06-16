import SwiftUI

struct HomeView: View {
    @StateObject private var store = ProgressStore()
    @ObservedObject private var profile = ProfileStore.shared
    @ObservedObject private var coordinator = QuickActionCoordinator.shared
    @State private var showProfile = false
    @State private var selectedDay: IdentifiableString?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 26) {
                    if profile.profiles.count > 1 {
                        profileSwitcher
                    }
                    consistencySection
                    bodySection

                    if let error = store.error {
                        ErrorBanner(message: error) { store.error = nil }
                    }
                }
                .padding()
                .padding(.bottom, 8)
            }
            .safeAreaInset(edge: .bottom) {
                recordSection
                    .padding(.horizontal)
                    .padding(.top, 10)
                    .padding(.bottom, 6)
                    .background(.ultraThinMaterial)
            }
            .navigationTitle("SpotRep")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showProfile = true } label: {
                        AvatarView(imageData: profile.avatarData, initials: profile.me.initials, size: 30)
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
                    appleWorkouts: store.appleWorkouts(on: item.value),
                    onUpdated: { store.applyLocally($0) },
                    onDeleted: { store.removeLocally(sessionId: $0) }
                )
                .presentationDetents([.medium, .large])
            }
            .task { await store.loadIfNeeded() }
            .refreshable { await store.load() }
            .onChange(of: profile.activeID) { _, _ in
                Task { await store.load() }
            }
            .onChange(of: coordinator.showRecorder) { _, isShowing in
                // Refresh once the recorder closes so a just-logged workout appears.
                if !isShowing { Task { await store.load() } }
            }
        }
    }

    // MARK: - Profile switcher

    private var profileSwitcher: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(profile.profiles) { p in
                    Button {
                        profile.setActive(p.id)
                    } label: {
                        VStack(spacing: 5) {
                            AvatarView(
                                imageData: p.id == profile.meID ? profile.avatarData : nil,
                                initials: p.initials,
                                size: 54,
                                ringColor: p.id == profile.activeID ? .appAccent : nil
                            )
                            Text(p.id == profile.meID ? "You" : p.name)
                                .font(.caption2)
                                .fontWeight(p.id == profile.activeID ? .semibold : .regular)
                                .foregroundColor(p.id == profile.activeID ? .primary : .secondary)
                                .lineLimit(1)
                        }
                        .frame(width: 66)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)
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

            Text("CONSISTENCY")
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)

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
            VStack(spacing: 2) {
                Text(profile.isViewingSelf ? "You" : profile.active.name)
                    .font(.headline)
                Text("Tap a muscle to train")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

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

    // MARK: - Bottom: composer bar

    /// A single chat-style bar: attach (+) · tap-to-type · mic.
    private var composerBar: some View {
        HStack(spacing: 10) {
            Button {
                QuickActionCoordinator.shared.openImport()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(width: 34, height: 34)
                    .background(Color.primary.opacity(0.06), in: Circle())
            }
            .accessibilityLabel("Import a spreadsheet or photo")

            Text(profile.isViewingSelf ? "Message SpotRep" : "Log for \(profile.active.name)")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture { QuickActionCoordinator.shared.openChat() }

            Button {
                QuickActionCoordinator.shared.triggerRecordNow()
            } label: {
                Image(systemName: "mic.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(Color.appAccent, in: Circle())
            }
            .accessibilityLabel("Record a workout")
        }
        .padding(.leading, 6)
        .padding(.trailing, 6)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous).fill(Color.cardBackground)
        )
        .overlay(
            Capsule(style: .continuous).stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - Bottom: record

    @ViewBuilder
    private var recordSection: some View {
        if profile.active.canWrite {
            composerBar
        } else {
            Label("View-only access to \(profile.active.name)", systemImage: "eye")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.gray.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }
}
