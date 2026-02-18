import SwiftUI

struct HistorySection: View {
    @ObservedObject var store: HistoryStore

    @State private var showClearConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header
            HStack {
                Text("Recent Uploads (\(store.entries.count))")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                if !store.entries.isEmpty {
                    Button("Clear") {
                        showClearConfirmation = true
                    }
                    .font(.caption)
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 4)

            if store.entries.isEmpty {
                // Empty state
                VStack(spacing: 6) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.title2)
                        .foregroundStyle(.tertiary)

                    Text("No uploads yet")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                // Scrollable list — capped at 330pt height to prevent popover height explosion (Pitfall 5)
                List {
                    ForEach(store.entries) { entry in
                        HistoryRowView(entry: entry, onDelete: { store.delete(entry) })
                            .listRowInsets(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
                    }
                    // .onDelete must be on ForEach, NOT on List (Pitfall 4)
                    .onDelete { indexSet in
                        for index in indexSet {
                            store.delete(store.entries[index])
                        }
                    }
                }
                .listStyle(.plain)
                .frame(maxHeight: 330)
                // Remove default List background for seamless popover integration
                .scrollContentBackground(.hidden)
            }
        }
        .padding(.bottom, 4)
        .confirmationDialog(
            "Clear all upload history?",
            isPresented: $showClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clear All", role: .destructive) {
                store.clearAll()
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}
