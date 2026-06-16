import SwiftUI

struct RecordView: View {
    @StateObject private var vm: RecordViewModel
    @ObservedObject private var coordinator = QuickActionCoordinator.shared
    @ObservedObject private var profile = ProfileStore.shared
    @Environment(\.dismiss) private var dismiss

    init() {
        _vm = StateObject(wrappedValue: RecordViewModel(preferences: UserPreferences()))
    }

    var body: some View {
        NavigationStack {
            Group {
                if !profile.active.canWrite {
                    readOnlyView
                } else {
                    VStack(spacing: 0) {
                        if !profile.isViewingSelf {
                            loggingForBanner
                        }
                        content
                    }
                }
            }
            .navigationTitle("Record Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Close")
                }
            }
            .onAppear {
                vm.onAppear()
                maybeAutoStart()
            }
            .onChange(of: coordinator.autoStartRecording) { _, newValue in
                if newValue { maybeAutoStart() }
            }
            .onDisappear { vm.cancelRecording() }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch vm.state {
        case .idle:
            idleView
        case .recording:
            recordingView
        case .parsing:
            LoadingOverlay(message: "Parsing workout...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .confirming(let parsed):
            ParsedWorkoutConfirm(parsed: parsed) { date in
                vm.confirmAndSave(parsed: parsed, workoutDate: date)
            } onRetry: {
                vm.reset()
            }
        case .saved:
            savedView
        case .error(let msg):
            errorView(msg)
        }
    }

    private var loggingForBanner: some View {
        HStack(spacing: 8) {
            AvatarView(imageData: nil, initials: profile.active.initials, size: 22)
            Text("Logging for \(profile.active.name)")
                .font(.caption.weight(.medium))
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.appAccent.opacity(0.12))
    }

    private var readOnlyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "eye.slash")
                .font(.system(size: 56))
                .foregroundColor(.secondary)
            Text("View-only access")
                .font(.title3.weight(.semibold))
            Text("You can view \(profile.active.name)'s training but can't log on their behalf.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            PrimaryButton(title: "Close") { dismiss() }
                .padding(.horizontal)
        }
        .padding()
    }

    /// Starts recording automatically when launched via a quick action / Action Button.
    private func maybeAutoStart() {
        guard coordinator.autoStartRecording else { return }
        coordinator.autoStartRecording = false
        Task {
            let granted = await vm.requestPermissions()
            guard granted else { return }
            switch vm.state {
            case .idle:
                vm.startRecording()
            case .saved, .error:
                vm.reset()
                vm.startRecording()
            default:
                break
            }
        }
    }

    private var idleView: some View {
        VStack(spacing: 32) {
            Spacer()
            Image(systemName: "mic.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.appAccent)
            Text("Tap to Record")
                .font(.title2)
                .foregroundColor(.secondary)
            PrimaryButton(title: "Start Recording") {
                Task {
                    let granted = await vm.requestPermissions()
                    if granted { vm.startRecording() }
                }
            }
            .padding(.horizontal)
            Spacer()
        }
    }

    private var recordingView: some View {
        VStack(spacing: 24) {
            Spacer()
            WaveformView(levels: vm.audioLevels)
                .padding(.horizontal)
            TranscriptPreview(transcript: vm.transcript)
                .padding(.horizontal)
            Button {
                vm.stopRecording()
            } label: {
                Image(systemName: "stop.circle.fill")
                    .font(.system(size: 72))
                    .foregroundColor(.red)
            }
            Text("Tap to stop")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
    }

    private var savedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 72))
                .foregroundColor(.green)
            Text("Workout Saved").font(.title2.weight(.semibold))
            PrimaryButton(title: "Done") { dismiss() }
                .padding(.horizontal)
            Button("Record another") { vm.reset() }
                .font(.subheadline)
        }
    }

    private func errorView(_ msg: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.red)
            Text(msg)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            PrimaryButton(title: "Try Again") { vm.reset() }
                .padding(.horizontal)
        }
        .padding()
    }
}
