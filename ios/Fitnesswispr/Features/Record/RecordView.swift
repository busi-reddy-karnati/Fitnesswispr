import SwiftUI

struct RecordView: View {
    @StateObject private var vm: RecordViewModel

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
            .onAppear { vm.onAppear() }
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
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 72))
                .foregroundColor(.green)
            Text("Workout Saved").font(.title2.weight(.semibold))
            PrimaryButton(title: "Record Another") { vm.reset() }
                .padding(.horizontal)
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
