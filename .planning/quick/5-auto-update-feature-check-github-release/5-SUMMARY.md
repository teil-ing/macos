---
phase: quick-5
plan: 01
subsystem: update
tags: [auto-update, github-releases, dmg-install, preferences, swiftui]
dependency_graph:
  requires: []
  provides: [auto-update-service, update-preferences-ui, update-badge]
  affects: [AppDelegate, PreferencesStore, PreferencesView, PopoverFooterView]
tech_stack:
  added: [URLSession GitHub API, hdiutil process, FileManager app-replace]
  patterns: [@MainActor ObservableObject singleton, Timer periodic check, Process for system tools]
key_files:
  created:
    - teil.ing-client/Services/UpdateService.swift
  modified:
    - teil.ing-client/Services/PreferencesStore.swift
    - teil.ing-client/App/AppDelegate.swift
    - teil.ing-client/Preferences/PreferencesView.swift
    - teil.ing-client/Views/PopoverFooterView.swift
    - teil.ing-client.xcodeproj/project.pbxproj
decisions:
  - "@MainActor final class (not actor) for UpdateService — needs @Published for SwiftUI bindings; follows PreferencesStore pattern"
  - "xcodegen regenerated after creating UpdateService.swift — new file not in pbxproj until regenerated"
  - "hdiutil -readonly -nobrowse -noverify flags for clean silent mount without Finder interaction"
  - "Rename-then-copy pattern for app replacement — .app.old backup ensures rollback on copy failure"
  - "isRunningFromDMG() checks both /Volumes/ prefix and parent directory write permission"
metrics:
  duration_seconds: 141
  completed_date: "2026-03-11"
  tasks_completed: 2
  files_changed: 6
---

# Quick Task 5: Auto-Update Feature — Check GitHub Releases Summary

**One-liner:** GitHub release check, DMG download/mount/replace/relaunch flow with 4-hour periodic timer and update badge in popover footer.

## Tasks Completed

| # | Task | Commit | Key Files |
|---|------|--------|-----------|
| 1 | Create UpdateService with GitHub release check, download, and install | aa78971 | teil.ing-client/Services/UpdateService.swift (new, 334 lines) |
| 2 | Wire UpdateService into AppDelegate, preferences UI, and popover footer | d6d9bbf | PreferencesStore, AppDelegate, PreferencesView, PopoverFooterView |

## What Was Built

### UpdateService (new file)

`@MainActor final class UpdateService: ObservableObject` with a shared singleton.

Published properties:
- `updateAvailable: Bool` — true when a newer version exists on GitHub
- `latestVersion: String?` — e.g. "1.1.0" stripped of leading "v"
- `downloadURL: URL?` — the DMG asset browser download URL
- `isChecking: Bool` — true during GitHub API request
- `isDownloading: Bool` — true during DMG download and install
- `downloadProgress: Double` — 0.0 to 1.0
- `errorMessage: String?` — last error, cleared on next check

Key methods:
- `checkForUpdates()` — GETs `https://api.github.com/repos/teil-ing/macos/releases/latest` with `Accept: application/vnd.github+json` header and 15s timeout; uses `convertFromSnakeCase` JSONDecoder; strips "v" prefix from tagName; compares semantic versions component-by-component; finds DMG asset by name pattern
- `downloadAndInstall()` — downloads DMG, `hdiutil attach -nobrowse -readonly -noverify -mountpoint /tmp/teil-ing-update`, finds .app in mount, renames current bundle to .app.old, copies new .app into place, removes backup, detaches DMG, relaunches with `open -n` after 1s delay
- `isRunningFromDMG()` — returns true if bundle path starts with `/Volumes/` or parent directory is not writable
- `startPeriodicCheck(interval:)` — 4-hour repeating Timer
- `stopPeriodicCheck()` — invalidates and nils the timer

### PreferencesStore

Added `@AppStorage("pref_autoCheckForUpdates") var autoCheckForUpdates: Bool = true` following the existing `pref_` prefix convention.

### AppDelegate

Added `private let updateService = UpdateService.shared` stored property. In `completeLaunch()`, after `setupHotkeyMonitor()`, starts periodic check and fires initial `checkForUpdates()` when `autoCheckForUpdates` is enabled.

### GeneralSection (PreferencesView)

Added `@ObservedObject private var updateService = UpdateService.shared`. New UI elements:
- Auto-Check for Updates toggle bound to `$prefs.autoCheckForUpdates` with onChange that calls `startPeriodicCheck()` / `stopPeriodicCheck()`
- Check for Updates button (disabled while checking/downloading)
- Inline ProgressView spinner when `isChecking`
- Green "Version X.Y.Z available" text when update detected
- "Update Now" button that calls `downloadAndInstall()` (hidden while downloading)
- ProgressView + "Installing update..." text during download
- Red error caption when `errorMessage` is set
- "Current: vX.Y.Z" secondary caption from Bundle info

### PopoverFooterView

Added `@ObservedObject private var updateService = UpdateService.shared`. When `updateAvailable` is true, shows a plain-style button with `arrow.down.circle.fill` icon and "Update" text in green, positioned between the gear icon and spacer. Tapping it calls `onOpenPreferences?()` to navigate to preferences where the update UI lives.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] xcodegen project regeneration required**
- **Found during:** Task 2 build attempt
- **Issue:** UpdateService.swift was created after the last `xcodegen generate` run, so it was not included in `project.pbxproj` Sources build phase. The Swift compiler reported "cannot find 'UpdateService' in scope" in PopoverFooterView.swift.
- **Fix:** Ran `xcodegen generate` to regenerate the project and include the new file
- **Files modified:** teil.ing-client.xcodeproj/project.pbxproj
- **Commit:** d6d9bbf (included in Task 2 commit)

## Self-Check: PASSED

| Item | Status |
|------|--------|
| teil.ing-client/Services/UpdateService.swift | FOUND |
| teil.ing-client/Services/PreferencesStore.swift | FOUND |
| teil.ing-client/App/AppDelegate.swift | FOUND |
| teil.ing-client/Preferences/PreferencesView.swift | FOUND |
| teil.ing-client/Views/PopoverFooterView.swift | FOUND |
| commit aa78971 (Task 1) | FOUND |
| commit d6d9bbf (Task 2) | FOUND |
| Final build | SUCCEEDED |
