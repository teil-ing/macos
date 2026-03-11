---
phase: quick-4
plan: "01"
subsystem: api-integration
tags: [swift, macos, api, history, quota, privacy, swiftui]
dependency_graph:
  requires: []
  provides: [APIService, APIModels, QuotaBarView, ImageDetailSheet, HistoryDisplayItem]
  affects: [HistoryStore, HistorySection, HistoryRowView, PopoverRootView, UploadService, PreferencesStore, AppDelegate]
tech_stack:
  added: [APIService actor, AsyncImage, ISO8601DateFormatter]
  patterns: [swift-actor-api, historyDisplayItem-adapter, three-state-navigation]
key_files:
  created:
    - teil.ing-client/Models/APIModels.swift
    - teil.ing-client/Services/APIService.swift
    - teil.ing-client/Views/ImageDetailSheet.swift
    - teil.ing-client/Views/QuotaBarView.swift
  modified:
    - teil.ing-client/Models/UploadResponse.swift
    - teil.ing-client/Models/HistoryEntry.swift
    - teil.ing-client/Services/UploadService.swift
    - teil.ing-client/Services/HistoryStore.swift
    - teil.ing-client/Services/PreferencesStore.swift
    - teil.ing-client/Views/HistoryRowView.swift
    - teil.ing-client/Views/HistorySection.swift
    - teil.ing-client/Views/PopoverRootView.swift
    - teil.ing-client/Preferences/PreferencesView.swift
    - teil.ing-client/App/AppDelegate.swift
decisions:
  - "APIService uses convertFromSnakeCase JSONDecoder — API returns camelCase JSON matching Swift naming, no custom CodingKeys needed"
  - "HistoryDisplayItem adapter struct unifies local HistoryEntry and remote ImageResponse into a single display model — no protocol required"
  - "UploadFeedbackEvent.uploadSucceeded now carries imageId alongside shareUrl to enable linking local SwiftData entries to remote API images"
  - "HistorySection shows remoteImages when non-empty (preferred), falls back to local entries — graceful degradation when no API key or offline"
  - "Context menu delete on remote images calls APIService.deleteImage + removes local SwiftData entry if one exists (by imageId)"
  - "refreshAll() uses withTaskGroup for concurrent fetchRemoteImages + fetchQuota — minimal latency on popover open"
metrics:
  duration: "7 min"
  completed: "2026-03-11"
  tasks_completed: 2
  files_changed: 10
---

# Quick Task 4: Implement New API Features in the Client — Summary

**One-liner:** Full teil.ing API v1 integration with private uploads, API-backed image listing via APIService actor, image detail/edit sheet, server-side deletion, and storage quota bar.

## What Was Built

### Task 1: API models, APIService actor, private upload support, and quota

- **`APIModels.swift`** — Codable+Sendable structs: `ImageResponse`, `ImageListResponse`, `QuotaResponse`, `ImageUpdateRequest`, `SuccessResponse`
- **`APIService.swift`** — Swift actor with `listImages`, `getImageDetails`, `updateImage`, `deleteImage`, `getQuota` methods. Uses `X-API-Key` header, maps HTTP status codes to typed `APIError` enum, uses `convertFromSnakeCase` decoding
- **`UploadResponse.swift`** — `imageUrl` and `thumbnailUrl` made optional (null when private), added `isPrivate: Bool` field and `quotaExceeded` error case with 413 handling
- **`UploadService.swift`** — Added `privateUpload: Bool` parameter to `enqueue()`, `retry()`, and `buildMultipartRequest()`. Private images append `private=true` form field. 413 response decodes quota error body
- **`PreferencesStore.swift`** — Added `@AppStorage("pref_privateUpload") var privateUpload: Bool = false`
- **`AppDelegate.swift`** — All 4 `enqueue()` and 1 `retry()` call sites pass `privateUpload`. `UploadFeedbackEvent.uploadSucceeded` now includes `imageId`
- **`HistoryEntry.swift`** — Added optional `imageId: String?` field to link local entries to remote API images
- **`HistoryStore.swift`** — Added `remoteImages`, `isLoadingRemote`, `remoteError`, `quota` published properties plus `fetchRemoteImages()`, `fetchQuota()`, `deleteRemoteImage()`, `refreshAll()` async methods

### Task 2: API-backed history, image detail/edit sheet, quota bar, delete, and preferences toggle

- **`HistoryRowView.swift`** — Rewritten to use `HistoryDisplayItem` adapter struct. Supports both local file thumbnails (NSImage) and remote URL thumbnails (AsyncImage). Shows lock/key badges for private/password-protected images, view count, tap-to-detail, and context menu
- **`HistorySection.swift`** — Shows remote API images when available with refresh button (arrow.clockwise). Falls back to local SwiftData entries. Shows loading indicator and remote error inline. Triggers `refreshAll()` on first appear
- **`ImageDetailSheet.swift`** — Full detail/edit sheet: loads image metadata via `APIService.getImageDetails`, displays thumbnail (AsyncImage), filename, file size, MIME type, view count, creation date. Editable: private toggle, password set/change/remove, max views, expiry days. Save calls `APIService.updateImage`. Delete with confirmation calls `APIService.deleteImage` then fires `onDeleted` callback
- **`QuotaBarView.swift`** — Compact quota display with `ProgressView(value:total:)` color-coded by usage (green/orange/red), "X MB / Y MB" caption, tier badge. Shows "Unlimited" for admin users
- **`PopoverRootView.swift`** — Three-state navigation: main content, preferences, image detail sheet. QuotaBarView inserted above footer when `historyStore.quota` is non-nil. Passes `onSelectDetail` callback down through `HistorySection`
- **`PreferencesView.swift`** — Added "Private Upload" `ToggleRow` after "Strip EXIF" in `UploadSettingsSection`

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Functionality] Added imageId to UploadFeedbackEvent**
- **Found during:** Task 1 — AppDelegate calls `historyStore.addEntry` on upload success but only had `shareUrl` from the feedback event, not the API-assigned image UUID
- **Fix:** Added `imageId: String` to `UploadFeedbackEvent.uploadSucceeded` case; UploadService passes `result.id` in the event; AppDelegate passes it through to `historyStore.addEntry(imageId:)`
- **Files modified:** `UploadService.swift`, `AppDelegate.swift`
- **Commit:** a8ae161

**2. [Rule 3 - Blocking Issue] xcodegen regeneration required for new files**
- **Found during:** First build after Task 1 — new `APIModels.swift` and `APIService.swift` were not in the `.xcodeproj` index
- **Fix:** Ran `xcodegen generate` twice (after Task 1 and Task 2) to include new Swift files from the existing `Models/` and `Services/` source paths in project.yml
- **Files modified:** `teil.ing-client.xcodeproj/project.pbxproj`

## Commits

| Task | Commit | Description |
|------|--------|-------------|
| Task 1 | a8ae161 | feat(quick-4-01): add APIService actor, API models, private upload support, and quota |
| Task 2 | 6ef4bab | feat(quick-4-02): API-backed history, image detail sheet, quota bar, and private upload toggle |

## Self-Check: PASSED

All created files exist on disk. Both task commits (a8ae161, 6ef4bab) are present in git history. Final `xcodebuild` returned `BUILD SUCCEEDED` with no errors.
