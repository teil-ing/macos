---
phase: 07-upload-history
plan: 01
subsystem: data-layer
tags: [swiftdata, thumbnail, history, upload-feedback]
dependency_graph:
  requires: []
  provides:
    - HistoryEntry SwiftData @Model
    - ThumbnailService JPEG thumbnail generation
    - HistoryStore ObservableObject with CRUD and LRU eviction
    - UploadFeedbackEvent.uploadSucceeded carrying CaptureResult
  affects:
    - teil.ing-client/App/AppDelegate.swift (handleUploadFeedback case updated)
    - teil.ing-client/Services/UploadService.swift (enum case extended)
tech_stack:
  added:
    - SwiftData (@Model, ModelContainer, ModelContext, FetchDescriptor)
  patterns:
    - Caseless enum namespace (ThumbnailService, matching CaptureFeedback convention)
    - ObservableObject with manual fetch-after-mutation (matching PreferencesStore)
    - CaptureResult threaded through UploadFeedbackEvent to avoid AppDelegate stored-state race
key_files:
  created:
    - teil.ing-client/Models/HistoryEntry.swift
    - teil.ing-client/Services/ThumbnailService.swift
    - teil.ing-client/Services/HistoryStore.swift
  modified:
    - teil.ing-client/Services/UploadService.swift
    - teil.ing-client/App/AppDelegate.swift
decisions:
  - HistoryEntry stores thumbnailPath as String (not URL) to avoid SwiftData URL encoding quirks
  - ThumbnailService uses 64x64px JPEG at 0.75 compression (32pt @2x, ~3-8 KB per file)
  - HistoryStore is ObservableObject (not @Observable) matching Phase 6 PreferencesStore pattern
  - CaptureResult carried in UploadFeedbackEvent.uploadSucceeded to avoid race with concurrent uploads
  - DB record deleted before thumbnail file (orphaned file safer than dangling DB record)
metrics:
  duration: "21 min"
  completed: "2026-02-18"
  tasks_completed: 2
  files_created: 3
  files_modified: 2
---

# Phase 7 Plan 01: Upload History Data Layer Summary

**One-liner:** SwiftData HistoryEntry model + CGImage-to-JPEG ThumbnailService + @MainActor HistoryStore with 50-entry LRU eviction; UploadFeedbackEvent extended to carry CaptureResult eliminating AppDelegate stored-state race.

## What Was Built

Created the complete persistence and data management foundation for upload history:

1. **HistoryEntry.swift** — SwiftData `@Model` class with `@Attribute(.unique) var id: UUID`, `var shareURL: String`, `var thumbnailPath: String`, and `var timestamp: Date`. Stores thumbnail path as `String` to avoid URL encoding quirks in SwiftData.

2. **ThumbnailService.swift** — Caseless namespace enum following the `CaptureFeedback` convention. `saveThumbnail(from:id:)` resizes any `CGImage` to 64x64px JPEG (aspect-fill center-crop) using Core Graphics `CGContext`, encodes via `NSBitmapImageRep`, and writes to `~/Library/Application Support/teilingClient/thumbnails/{id}.jpg`. Returns the absolute path string.

3. **HistoryStore.swift** — `@MainActor final class HistoryStore: ObservableObject` with `@Published private(set) var entries: [HistoryEntry]`. Implements `addEntry`, `delete`, `clearAll`, and private `evictOldEntriesIfNeeded` (50-entry LRU). Manual `fetchEntries()` called after every mutation (required because manually-fetched arrays don't auto-observe context changes).

4. **UploadService.swift (modified)** — `UploadFeedbackEvent.uploadSucceeded` extended from `case uploadSucceeded(shareUrl: String)` to `case uploadSucceeded(shareUrl: String, capture: CaptureResult)`. `performUpload` updated to pass `capture` through. This threads the `CaptureResult` through the event rather than storing it in AppDelegate, eliminating the timing race with concurrent queued uploads.

5. **AppDelegate.swift (modified)** — `handleUploadFeedback` case pattern updated from `case .uploadSucceeded(let shareUrl):` to `case .uploadSucceeded(let shareUrl, _):`. The underscore is intentional — Plan 02 will use the capture payload to call `ThumbnailService` and `historyStore.addEntry`.

## Deviations from Plan

None — plan executed exactly as written.

## Decisions Made

| Decision | Rationale |
|----------|-----------|
| `thumbnailPath` as `String` not `URL` | Avoids SwiftData URL encoding quirks; consistent with research recommendation |
| 64px JPEG at 0.75 quality | 32pt @2x display scale; ~3-8 KB per file; good quality-to-size ratio |
| `ObservableObject` not `@Observable` | `@Observable` macro incompatible with `@AppStorage` (established Phase 6 PreferencesStore pattern) |
| CaptureResult in UploadFeedbackEvent | Avoids timing race where `lastSuccessfulCapture` could be overwritten by concurrent upload |
| DB-before-file deletion order | Orphaned file is safer than a dangling DB record (research Pitfall 3) |

## Self-Check: PASSED

All created files exist and all task commits are verified.
