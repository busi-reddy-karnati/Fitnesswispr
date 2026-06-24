import SwiftUI

struct HistoryView: View {
    @StateObject private var vm = HistoryViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading && vm.sessions.isEmpty {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if vm.sessions.isEmpty {
                    EmptyStateView(icon: "clock.arrow.circlepath", title: "No history", message: "Your saved workouts will appear here")
                } else {
                    List {
                        ForEach(vm.groupedSessions, id: \.0) { month, sessions in
                            Section(month) {
                                ForEach(sessions) { session in
                                    NavigationLink {
                                        SessionDetailView(
                                            session: session,
                                            onUpdated: { vm.applyLocally($0) },
                                            onDeleted: { vm.removeLocally(sessionId: $0) }
                                        )
                                    } label: {
                                        SessionRowView(session: session)
                                    }
                                }
                            }
                        }
                        if vm.hasMore {
                            ProgressView()
                                .task { await vm.fetchMore() }
                        }
                    }
                }
            }
            .navigationTitle("History")
            .task { await vm.fetchInitial() }
            .refreshable { await vm.fetchInitial() }
            .overlay {
                if let error = vm.error {
                    VStack { Spacer(); ErrorBanner(message: error) { vm.error = nil }.padding() }
                }
            }
        }
    }
}
