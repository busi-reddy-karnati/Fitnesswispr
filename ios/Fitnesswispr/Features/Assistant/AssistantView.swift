import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct AssistantView: View {
    @StateObject private var vm: AssistantViewModel
    @ObservedObject private var coordinator = QuickActionCoordinator.shared
    @ObservedObject private var profile = ProfileStore.shared
    @ObservedObject private var speech: SpeechRecognizer
    @Environment(\.dismiss) private var dismiss
    @FocusState private var composerFocused: Bool

    @State private var showAttachMenu = false
    @State private var showFileImporter = false
    @State private var showPhotoPicker = false
    @State private var photoItem: PhotosPickerItem?

    init() {
        let model = AssistantViewModel(preferences: UserPreferences())
        _vm = StateObject(wrappedValue: model)
        _speech = ObservedObject(wrappedValue: model.speech)
    }

    var body: some View {
        NavigationStack {
            Group {
                if !profile.active.canWrite {
                    readOnlyView
                } else {
                    chat
                }
            }
            .navigationTitle("SpotRep")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                        .accessibilityLabel("Close")
                }
            }
            .onAppear {
                vm.onAppear()
                if coordinator.autoStartRecording {
                    maybeAutoStart()
                } else if coordinator.pendingAttach {
                    coordinator.pendingAttach = false
                    showAttachMenu = true
                } else {
                    composerFocused = true
                }
            }
            .onChange(of: coordinator.autoStartRecording) { _, newValue in
                if newValue { maybeAutoStart() }
            }
            .onDisappear {
                if speech.isRecording { _ = speech.stop() }
            }
            .confirmationDialog("Add to SpotRep", isPresented: $showAttachMenu, titleVisibility: .visible) {
                Button("Import a spreadsheet") { showFileImporter = true }
                Button("Import from a photo") { showPhotoPicker = true }
                Button("Cancel", role: .cancel) {}
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: spreadsheetTypes,
                allowsMultipleSelection: false
            ) { result in handleFile(result) }
            .photosPicker(isPresented: $showPhotoPicker, selection: $photoItem, matching: .images)
            .onChange(of: photoItem) { _, item in handlePhoto(item) }
            .sheet(item: $vm.importPreview) { preview in
                ImportPreviewView(preview: preview) { items in
                    vm.commitImport(items: items)
                }
            }
        }
    }

    // MARK: - Chat

    private var chat: some View {
        VStack(spacing: 0) {
            if !profile.isViewingSelf {
                loggingForBanner
            }
            messagesList
            composerBar
        }
    }

    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(vm.messages) { message in
                        MessageRow(
                            message: message,
                            onSave: { parsed, date in vm.saveDraft(parsed, date: date, draftID: message.id) },
                            onDiscard: { vm.discardDraft(message.id) },
                            onChoose: { option, clarification in vm.chooseClarification(option, clarification) },
                            onConfirmRename: { preview in vm.confirmRename(preview) },
                            onCancelRename: { vm.cancelRename(message.id) }
                        )
                        .id(message.id)
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: vm.messages.count) { _, _ in
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
        }
    }

    // MARK: - Composer

    private var composerBar: some View {
        VStack(spacing: 8) {
            if speech.isRecording {
                listeningStrip
            }
            HStack(alignment: .bottom, spacing: 10) {
                Button { showAttachMenu = true } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 34, height: 34)
                        .background(Color.primary.opacity(0.06), in: Circle())
                }
                .accessibilityLabel("Import a spreadsheet or photo")

                TextField("Message SpotRep", text: $vm.composer)
                    .focused($composerFocused)
                    .submitLabel(.send)
                    .onSubmit { vm.sendComposer() }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(Color.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                trailingButton
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(.ultraThinMaterial)
    }

    @ViewBuilder
    private var trailingButton: some View {
        if speech.isRecording {
            Button { vm.stopVoiceAndSend() } label: {
                Image(systemName: "stop.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.red)
            }
        } else if vm.composer.trimmingCharacters(in: .whitespaces).isEmpty {
            Button { vm.startVoice() } label: {
                Image(systemName: "mic.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.appAccent)
            }
        } else {
            Button { vm.sendComposer() } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.appAccent)
            }
            .disabled(vm.isBusy)
        }
    }

    private var listeningStrip: some View {
        HStack(spacing: 10) {
            WaveformView(levels: speech.levels)
                .frame(height: 28)
            Text(speech.transcript.isEmpty ? "Listening…" : speech.transcript)
                .font(.subheadline)
                .foregroundColor(speech.transcript.isEmpty ? .secondary : .primary)
                .lineLimit(1)
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private var loggingForBanner: some View {
        HStack(spacing: 8) {
            RemoteAvatarView(uuid: profile.active.id, initials: profile.active.initials, size: 22)
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

    private func maybeAutoStart() {
        guard coordinator.autoStartRecording else { return }
        coordinator.autoStartRecording = false
        vm.startVoice()
    }

    // MARK: - Attach handling

    private var spreadsheetTypes: [UTType] {
        var types: [UTType] = [.spreadsheet, .commaSeparatedText]
        if let xlsx = UTType(filenameExtension: "xlsx") { types.insert(xlsx, at: 0) }
        return types
    }

    private func handleFile(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let url = urls.first else { return }
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { return }
        let ext = url.pathExtension.lowercased()
        let mime = ext == "csv" ? "text/csv"
            : "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        vm.startImport(kind: "spreadsheet", data: data, filename: url.lastPathComponent, mime: mime)
    }

    private func handlePhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            defer { photoItem = nil }
            guard let data = try? await item.loadTransferable(type: Data.self) else { return }
            // Normalise to JPEG so the backend always gets a known mime type.
            let jpeg = UIImage(data: data)?.jpegData(compressionQuality: 0.85) ?? data
            vm.startImport(kind: "photo", data: jpeg, filename: "photo.jpg", mime: "image/jpeg")
        }
    }
}

// MARK: - Message row

private struct MessageRow: View {
    let message: ChatMessage
    let onSave: (ParsedSession, Date) -> Void
    let onDiscard: () -> Void
    let onChoose: (String, Clarification) -> Void
    let onConfirmRename: (RenamePreview) -> Void
    let onCancelRename: () -> Void

    var body: some View {
        switch message.body {
        case .text(let text):
            bubble(text: text, isUser: message.author == .user)
        case .saved(let text):
            HStack {
                Spacer(minLength: 40)
                Label(text, systemImage: "checkmark.seal.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.green)
                Spacer(minLength: 40)
            }
        case .thinking:
            HStack {
                TypingDots()
                Spacer()
            }
        case .workoutDraft(let parsed):
            WorkoutDraftCard(parsed: parsed, onSave: onSave, onDiscard: onDiscard)
        case .clarify(let clarification):
            ClarifyCard(clarification: clarification) { onChoose($0, clarification) }
        case .renamePreview(let preview):
            RenamePreviewCard(preview: preview, onConfirm: onConfirmRename, onCancel: onCancelRename)
        }
    }

    private func bubble(text: String, isUser: Bool) -> some View {
        HStack {
            if isUser { Spacer(minLength: 40) }
            Text(text)
                .font(.body)
                .foregroundColor(isUser ? .white : .primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(isUser ? Color.appAccent : Color.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            if !isUser { Spacer(minLength: 40) }
        }
    }
}

// MARK: - Workout draft confirmation card

private struct WorkoutDraftCard: View {
    let parsed: ParsedSession
    let onSave: (ParsedSession, Date) -> Void
    let onDiscard: () -> Void

    @State private var date: Date
    @State private var saved = false

    init(parsed: ParsedSession, onSave: @escaping (ParsedSession, Date) -> Void, onDiscard: @escaping () -> Void) {
        self.parsed = parsed
        self.onSave = onSave
        self.onDiscard = onDiscard
        _date = State(initialValue: parsed.resolvedDate)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(parsed.workoutType ?? "Workout")
                    .font(.headline)
                Spacer()
                DatePicker("", selection: $date, displayedComponents: .date)
                    .labelsHidden()
                    .disabled(saved)
            }

            ForEach(parsed.exercises) { ex in
                VStack(alignment: .leading, spacing: 2) {
                    Text(ex.name)
                        .font(.subheadline.weight(.semibold))
                    Text(setsSummary(ex))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if let cardio = parsed.cardioSummaryLine {
                Label(cardio, systemImage: CardioSummary.symbol)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.appAccent)
            }

            if !saved {
                HStack(spacing: 10) {
                    Button(role: .destructive) { onDiscard() } label: {
                        Text("Discard").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button { saved = true; onSave(parsed, date) } label: {
                        Text("Save").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.top, 4)
            }
        }
        .padding(14)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.appAccent.opacity(0.25), lineWidth: 1)
        )
    }

    private func setsSummary(_ ex: Exercise) -> String {
        let unit = ex.sets.first?.weightUnit ?? "lbs"
        // Group identical sets: "3 x 10 @ 135 lbs"
        if let first = ex.sets.first,
           ex.sets.allSatisfy({ $0.reps == first.reps && $0.weight == first.weight }) {
            let reps = first.reps.map { "\($0)" } ?? "-"
            if let w = first.weight {
                return "\(ex.sets.count) × \(reps) @ \(format(w)) \(unit)"
            }
            if let secs = first.durationSeconds {
                return "\(ex.sets.count) × \(secs)s"
            }
            return "\(ex.sets.count) × \(reps)"
        }
        return ex.sets.map { s in
            let reps = s.reps.map { "\($0)" } ?? "-"
            if let w = s.weight { return "\(reps)@\(format(w))" }
            return reps
        }.joined(separator: ", ")
    }

    private func format(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(value)
    }
}

// MARK: - Rename preview card

private struct RenamePreviewCard: View {
    let preview: RenamePreview
    let onConfirm: (RenamePreview) -> Void
    let onCancel: () -> Void

    @State private var done = false

    private var shown: [RenameOccurrence] { Array(preview.occurrences.prefix(8)) }
    private var overflow: Int { max(0, preview.matchedCount - shown.count) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Rename \(preview.matchedCount) entr\(preview.matchedCount == 1 ? "y" : "ies") to “\(preview.toName)”?")
                .font(.subheadline.weight(.semibold))

            VStack(alignment: .leading, spacing: 6) {
                ForEach(shown) { occ in
                    HStack(spacing: 8) {
                        Text(displayDate(occ.workoutDate))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .frame(width: 64, alignment: .leading)
                        Text(occ.oldName)
                            .font(.caption)
                            .strikethrough(color: .secondary)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                        Image(systemName: "arrow.right")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(preview.toName)
                            .font(.caption.weight(.medium))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                    }
                }
                if overflow > 0 {
                    Text("+ \(overflow) more")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            if !done {
                HStack(spacing: 10) {
                    Button(role: .cancel) { done = true; onCancel() } label: {
                        Text("Cancel").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button { done = true; onConfirm(preview) } label: {
                        Text("Rename").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.top, 2)
            }
        }
        .padding(14)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.appAccent.opacity(0.25), lineWidth: 1)
        )
    }

    private func displayDate(_ apiString: String) -> String {
        Date.from(apiString: apiString)?.formatted(.dateTime.month(.abbreviated).day()) ?? apiString
    }
}

// MARK: - Clarification card

private struct ClarifyCard: View {
    let clarification: Clarification
    let onChoose: (String) -> Void

    @State private var custom: String = ""
    @FocusState private var customFocused: Bool

    private var isNumeric: Bool {
        switch clarification.kind {
        case .weight, .reps, .sets: return true
        case .exercise, .variant: return false
        }
    }

    private var customKeyboard: UIKeyboardType {
        switch clarification.kind {
        case .weight: return .decimalPad
        case .reps, .sets: return .numberPad
        case .exercise, .variant: return .default
        }
    }

    private var customPlaceholder: String {
        switch clarification.kind {
        case .weight: return "Select one above or enter custom here"
        case .reps, .sets: return "Select one above or enter custom here"
        case .exercise, .variant: return "Type it"
        }
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 10) {
                Text(clarification.prompt)
                    .font(.body)
                    .foregroundColor(.primary)

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 104), spacing: 8)],
                    alignment: .leading,
                    spacing: 8
                ) {
                    ForEach(clarification.options, id: \.self) { option in
                        Button { onChoose(option) } label: {
                            Text(option)
                                .font(.subheadline.weight(.medium))
                                .lineLimit(1)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity)
                                .background(Color.appAccent.opacity(0.12))
                                .foregroundColor(.appAccent)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Inline custom entry so the user never has to leave the card to
                // type an exact value.
                HStack(spacing: 8) {
                    TextField(customPlaceholder, text: $custom)
                        .keyboardType(customKeyboard)
                        .textInputAutocapitalization(isNumeric ? .never : .words)
                        .autocorrectionDisabled(isNumeric)
                        .focused($customFocused)
                        .submitLabel(.done)
                        .onSubmit(submitCustom)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.primary.opacity(0.06))
                        .clipShape(Capsule())

                    Button(action: submitCustom) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 26))
                            .foregroundColor(.appAccent)
                    }
                    .disabled(custom.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding(14)
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.appAccent.opacity(0.25), lineWidth: 1)
            )
            Spacer(minLength: 20)
        }
    }

    private func submitCustom() {
        let value = custom.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        customFocused = false
        custom = ""
        onChoose(value)
    }
}

private struct TypingDots: View {
    @State private var animating = false
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(Color.secondary)
                    .frame(width: 7, height: 7)
                    .opacity(animating ? 1 : 0.3)
                    .animation(
                        .easeInOut(duration: 0.6).repeatForever().delay(Double(i) * 0.2),
                        value: animating
                    )
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onAppear { animating = true }
    }
}
