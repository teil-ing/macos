import Foundation
import SwiftData
import SwiftUI

// MARK: - HistoryStore

/// @MainActor ObservableObject bridging SwiftData to SwiftUI for upload history.
///
/// Uses a `ModelContainer` stored property to access `mainContext` (always `@MainActor`-bound),
/// which avoids all actor-isolation complexity. All history operations — insert, delete, LRU
/// eviction — are synchronous and fast at the ~50-entry scale used here.
///
/// `@Published private(set) var entries` is the single source of truth for SwiftUI.
/// Manual `fetchEntries()` after every mutation is required because manually-fetched
/// arrays do not observe context changes automatically (unlike `@Query`).
@MainActor
final class HistoryStore: ObservableObject {

    // MARK: - Published State

    @Published private(set) var entries: [HistoryEntry] = []

    // MARK: - Private State

    private let container: ModelContainer
    private var context: ModelContext { container.mainContext }

    // MARK: - Init

    init(container: ModelContainer) {
        self.container = container
        fetchEntries()
    }

    // MARK: - Fetch

    /// Refreshes the @Published `entries` array from SwiftData.
    ///
    /// Must be called after every mutation because manually-fetched arrays do not
    /// automatically observe `ModelContext` changes (Pitfall 2 from research).
    func fetchEntries() {
        let descriptor = FetchDescriptor<HistoryEntry>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        entries = (try? context.fetch(descriptor)) ?? []
    }

    // MARK: - CRUD

    /// Inserts a new history entry, evicts if over the 50-entry cap, then refreshes.
    ///
    /// - Parameters:
    ///   - shareURL: The teil.ing share URL string for this upload.
    ///   - thumbnailPath: Absolute path to the saved thumbnail JPEG file.
    ///   - timestamp: Capture timestamp (defaults to now if not provided).
    func addEntry(shareURL: String, thumbnailPath: String, timestamp: Date = Date()) {
        let entry = HistoryEntry(shareURL: shareURL, thumbnailPath: thumbnailPath, timestamp: timestamp)
        context.insert(entry)
        try? context.save()
        evictOldEntriesIfNeeded()
        fetchEntries()
    }

    /// Deletes a single entry and its associated thumbnail file from disk.
    ///
    /// DB record is deleted before the file — an orphaned file is safer than a DB
    /// record pointing to a missing file (research Pitfall 3).
    func delete(_ entry: HistoryEntry) {
        let path = entry.thumbnailPath
        context.delete(entry)
        try? context.save()
        fetchEntries()
        try? FileManager.default.removeItem(atPath: path)
    }

    /// Deletes all entries and their associated thumbnail files from disk.
    func clearAll() {
        let allPaths = entries.map(\.thumbnailPath)
        try? context.delete(model: HistoryEntry.self)
        try? context.save()
        fetchEntries()
        allPaths.forEach { try? FileManager.default.removeItem(atPath: $0) }
    }

    // MARK: - LRU Eviction

    /// Evicts the oldest entries when the total count exceeds 50.
    ///
    /// Fetches entries sorted oldest-first, then deletes the prefix that pushes
    /// the total over the 50-entry cap. Thumbnail files are deleted after the DB records.
    private func evictOldEntriesIfNeeded() {
        let descriptor = FetchDescriptor<HistoryEntry>(
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )
        guard let all = try? context.fetch(descriptor), all.count > 50 else { return }
        let toEvict = all.prefix(all.count - 50)
        let evictedPaths = toEvict.map(\.thumbnailPath)
        toEvict.forEach { context.delete($0) }
        try? context.save()
        evictedPaths.forEach { try? FileManager.default.removeItem(atPath: $0) }
    }
}
