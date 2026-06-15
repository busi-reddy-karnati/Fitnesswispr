import SwiftUI

struct ExportView: View {
    @StateObject private var vm = SettingsViewModel()
    @State private var showShareSheet = false
    @State private var exportData: Data?
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
                        exportData = data
                        showShareSheet = true
                    }
                }
            }
            .padding(.horizontal)

            if let error = vm.error {
                ErrorBanner(message: error) { vm.error = nil }
                    .padding(.horizontal)
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let data = exportData {
                ShareSheet(items: [data as NSData])
            }
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
