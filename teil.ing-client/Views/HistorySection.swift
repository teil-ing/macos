import SwiftUI

struct HistorySection: View {
    @ObservedObject var store: HistoryStore
    var onSelectDetail: ((String) -> Void)? = nil

    @State private var showClearConfirmation = false

    /// Merged display list: remote images take priority; fall back to local entries when no API key.
    private var displayItems: [HistoryDisplayItem] {
        if !store.remoteImages.isEmpty {
            return store.remoteImages.map { HistoryDisplayItem(imageResponse: $0) }
        }
        return store.entries.map { HistoryDisplayItem(entry: $0) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header
            HStack {
                Text("Images")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if store.isLoadingRemote {
                    ProgressView()
                        .scaleEffect(0.6)
                }

                Spacer()

                // Refresh button
                Button {
                    Task { await store.refreshAll() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .font(.caption)
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

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

            // Remote fetch error (graceful degradation)
            if let remoteError = store.remoteError {
                Text(remoteError)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 4)
            }

            if displayItems.isEmpty && !store.isLoadingRemote {
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
                        ForEach(displayItems) { item in
                            HistoryRowView(
                                item: item,
                                onDelete: {
                                    if let imageId = item.imageId {
                                        Task {
                                            try? await store.deleteRemoteImage(id: imageId)
                                        }
                                    } else {
                                        // Local-only entry: find and delete from SwiftData
                                        if let entry = store.entries.first(where: { $0.id.uuidString == item.id }) {
                                            store.delete(entry)
                                        }
                                    }
                                },
                                onSelectDetail: onSelectDetail
                            )
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)

                            if item.id != displayItems.last?.id {
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
