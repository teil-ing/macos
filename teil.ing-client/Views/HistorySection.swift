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
                // ScrollView + LazyVStack instead of List — List/NSTableView collapses
                // to zero height inside NSPopover VStack (no intrinsic content size).
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(store.entries) { entry in
                            HistoryRowView(entry: entry, onDelete: { store.delete(entry) })
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)

                            if entry.id != store.entries.last?.id {
                                Divider()
                                    .padding(.leading, 8)
                            }
                        }
                    }
                }
                .frame(maxHeight: 330)
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
