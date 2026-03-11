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
/// `@Published private(set) var entries` is the single source of truth for local SwiftData.
/// `@Published private(set) var remoteImages` is populated by fetching from the API.
/// Manual `fetchEntries()` after every mutation is required because manually-fetched
/// arrays do not observe context changes automatically (unlike `@Query`).
@MainActor
final class HistoryStore: ObservableObject {

    // MARK: - Published State (Local SwiftData)

    @Published private(set) var entries: [HistoryEntry] = []

    // MARK: - Published State (Remote API)

    /// Remote images fetched from the API. Separate from local SwiftData entries.
    @Published private(set) var remoteImages: [ImageResponse] = []

    /// True while an API fetch is in progress.
    @Published private(set) var isLoadingRemote: Bool = false

    /// Non-nil when the most recent remote fetch failed.
    @Published private(set) var remoteError: String?

    /// Storage quota for the authenticated user.
    @Published private(set) var quota: QuotaResponse?

    // MARK: - Private State

    private let container: ModelContainer
    private var context: ModelContext { container.mainContext }

    // MARK: - Init

    init(container: ModelContainer) {
        self.container = container
        fetchEntries()
    }

    // MARK: - Fetch (Local)

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

    // MARK: - CRUD (Local)

    /// Inserts a new history entry, evicts if over the 50-entry cap, then refreshes.
    ///
    /// - Parameters:
    ///   - imageId: The teil.ing image UUID from the upload API response.
    ///   - shareURL: The teil.ing share URL string for this upload.
    ///   - thumbnailPath: Absolute path to the saved thumbnail JPEG file.
    ///   - timestamp: Capture timestamp (defaults to now if not provided).
    func addEntry(imageId: String? = nil, shareURL: String, thumbnailPath: String, timestamp: Date = Date()) {
        let entry = HistoryEntry(imageId: imageId, shareURL: shareURL, thumbnailPath: thumbnailPath, timestamp: timestamp)
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

    // MARK: - Remote API Operations

    /// Fetches the list of remote images from the API and updates `remoteImages`.
    ///
    /// Fetches up to 50 images to match local history cap.
    func fetchRemoteImages() async {
        isLoadingRemote = true
        remoteError = nil
        do {
            let response = try await APIService.shared.listImages(limit: 5, offset: 0)
            remoteImages = response.images
        } catch {
            remoteError = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
        isLoadingRemote = false
    }

    /// Fetches the authenticated user's storage quota.
    func fetchQuota() async {
        do {
            quota = try await APIService.shared.getQuota()
        } catch {
            // Quota fetch failure is non-critical — silently ignore.
        }
    }

    /// Deletes a remote image by its API UUID and refreshes the remote list.
    func deleteRemoteImage(id: String) async throws {
        try await APIService.shared.deleteImage(id: id)
        remoteImages.removeAll { $0.id == id }
        // Also remove matching local entry if one exists.
        if let localEntry = entries.first(where: { $0.imageId == id }) {
            delete(localEntry)
        }
        // Refresh quota after deletion.
        await fetchQuota()
    }

    /// Fetches both remote images and storage quota concurrently.
    func refreshAll() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.fetchRemoteImages() }
            group.addTask { await self.fetchQuota() }
        }
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
