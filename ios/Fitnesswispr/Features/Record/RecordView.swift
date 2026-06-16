import SwiftUI

struct RecordView: View {
    @StateObject private var vm: RecordViewModel
    @ObservedObject private var coordinator = QuickActionCoordinator.shared
    @Environment(\.dismiss) private var dismiss

    init() {
        _vm = StateObject(wrappedValue: RecordViewModel(preferences: UserPreferences()))
    }

    var body: some View {
        NavigationStack {
            Group {
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
