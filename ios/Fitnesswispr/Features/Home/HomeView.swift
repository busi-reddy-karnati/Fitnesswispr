import SwiftUI

struct HomeView: View {
    @StateObject private var vm = HomeViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if vm.isLoading {
                        ProgressView().frame(maxWidth: .infinity)
                    } else if vm.todaySessions.isEmpty {
                        EmptyStateView(
                            icon: "dumbbell",
                            title: "No workout today",
                            message: "Tap Record to log your first workout"
                        )
                    } else {
                        Text("Today").font(.title2.weight(.semibold))
                        ForEach(vm.todaySessions) { session in
                            TodaySummaryCard(session: session)
                        }
                    }

                    if let error = vm.error {
                        ErrorBanner(message: error) { vm.error = nil }
                    }
                }
                .padding()
            }
            .navigationTitle("SpotRep")
            .task { await vm.fetchToday() }
            .refreshable { await vm.fetchToday() }
        }
    }
}
