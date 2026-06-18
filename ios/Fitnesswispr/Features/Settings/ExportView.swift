import SwiftUI

struct ExportView: View {
    @StateObject private var vm = SettingsViewModel()
    @State private var exportURL: IdentifiableURL?
    @State private var format = "csv"

    var body: some View {
        VStack(spacing: 20) {
            Picker("Format", selection: $format) {
                Text("CSV").tag("csv")
                Text("Excel (.xlsx)").tag("xlsx")
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            PrimaryButton(title: "Export Workouts", isLoading: vm.isExporting) {
                Task {
                    if let data = await vm.exportWorkouts(format: format) {
                        if let url = Self.writeTempFile(data, format: format) {
                            exportURL = IdentifiableURL(url: url)
                        } else {
                            vm.error = "Couldn't prepare the export file."
                        }
                    }
                }
            }
            .padding(.horizontal)

            if let error = vm.error {
                ErrorBanner(message: error) { vm.error = nil }
                    .padding(.horizontal)
            }
        }
        // Sharing a real file (with extension) lets the share sheet offer Save to
        // Files, Mail, etc. — sharing raw Data shows no useful options.
        .sheet(item: $exportURL) { item in
            ShareSheet(items: [item.url])
        }
    }

    /// Persist the export bytes to a temp file with the right extension so it can
    /// be shared/saved as a proper CSV/XLSX.
    private static func writeTempFile(_ data: Data, format: String) -> URL? {
        let stamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let name = "SpotRep_workouts_\(stamp).\(format)"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}

struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
