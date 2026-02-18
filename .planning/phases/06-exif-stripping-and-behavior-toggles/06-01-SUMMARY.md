---
phase: 06-exif-stripping-and-behavior-toggles
plan: 01
subsystem: upload
tags: [swift, appstorage, userdefaults, observableobject, multipart, exif]

# Dependency graph
requires:
  - phase: 05-upload-pipeline
    provides: UploadService actor with enqueue/retry API and multipart upload pipeline
provides:
  - PreferencesStore singleton with three @AppStorage Bool preferences (stripExif, openInBrowser, clipboardCopy)
  - UploadService.enqueue() and retry() with preference Bool parameters
  - Conditional stripExif=true multipart form field injection (omitted when off)
  - Preference-gated clipboard copy and browser open post-upload actions
affects: [08-preferences-ui, any phase that calls UploadService.enqueue or retry]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "@MainActor ObservableObject with @AppStorage for UserDefaults-backed preference store"
    - "Preference values captured at enqueue time as Bool parameters — no actor-crossing during upload"
    - "pref_ key prefix to avoid UserDefaults collision with KeyboardShortcuts library"
    - "Conditional multipart form field: field appended when true, omitted entirely when false"

key-files:
  created:
    - teil.ing-client/Services/PreferencesStore.swift
  modified:
    - teil.ing-client/Services/UploadService.swift
    - teil.ing-client/App/AppDelegate.swift
    - teil.ing-client.xcodeproj/project.pbxproj

key-decisions:
  - "ObservableObject (not @Observable macro) for PreferencesStore — @Observable incompatible with @AppStorage"
  - "Bool preferences passed as enqueue() parameters at capture time — no actor-crossing needed mid-upload"
  - "pref_ prefix on all UserDefaults keys (pref_stripExif, pref_openInBrowser, pref_clipboardCopy) to avoid KeyboardShortcuts collision"
  - "stripExif field omitted entirely when false — never send stripExif=false per API contract"
  - "retry() reads current preference values at retry time (not original capture-time values)"
  - "performUpload() parameter renamed to shouldOpenInBrowser/shouldCopyToClipboard to avoid shadowing private openInBrowser(_:) method"

patterns-established:
  - "Preference wiring pattern: read PreferencesStore.shared at call site, pass as Bool params into actor method"

requirements-completed: [UPLD-05, PREF-03, PREF-04]

# Metrics
duration: 3min
completed: 2026-02-18
---

# Phase 6 Plan 01: EXIF Stripping and Behavior Toggles Summary

**PreferencesStore with three @AppStorage Bool toggles wired into UploadService multipart field injection and post-upload clipboard/browser action gates — all defaults ON, zero new dependencies**

## Performance

- **Duration:** 3 min
- **Started:** 2026-02-18T12:43:56Z
- **Completed:** 2026-02-18T12:46:55Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments
- Created PreferencesStore.swift: @MainActor ObservableObject singleton with three @AppStorage Bool preferences (stripExif, openInBrowser, clipboardCopy), all defaulting to true, using pref_ key prefix
- Updated UploadService.enqueue(), retry(), performUpload(), and buildMultipartRequest() to accept and use the three preference parameters
- Wired all 5 call sites in AppDelegate (4 enqueue + 1 retry) to pass PreferencesStore.shared values
- stripExif=true multipart form field conditionally injected; omitted entirely when off per API contract

## Task Commits

Each task was committed atomically:

1. **Task 1: Create PreferencesStore and update UploadService with preference parameters** - `a17eb48` (feat)
2. **Task 2: Wire AppDelegate call sites and register new file in project.yml** - `7ee2fd2` (feat)

## Files Created/Modified
- `teil.ing-client/Services/PreferencesStore.swift` - New: @MainActor ObservableObject with three @AppStorage Bool preferences
- `teil.ing-client/Services/UploadService.swift` - Updated: enqueue/retry/performUpload/buildMultipartRequest with preference parameters and conditional stripExif field
- `teil.ing-client/App/AppDelegate.swift` - Updated: all 4 enqueue + 1 retry call sites pass PreferencesStore.shared values
- `teil.ing-client.xcodeproj/project.pbxproj` - Updated: xcodegen registered PreferencesStore.swift in Xcode project

## Decisions Made
- Used ObservableObject (not @Observable macro) for PreferencesStore — @Observable converts stored properties to computed, blocking @AppStorage composition (Pitfall 1 from research)
- Bool preference values captured at enqueue time and passed as parameters — avoids actor-crossing into @MainActor-isolated PreferencesStore from inside the UploadService actor
- pref_ prefix on all three UserDefaults keys to avoid collision with KeyboardShortcuts library's UserDefaults namespace
- stripExif field omitted entirely when false (never send `stripExif=false`) — per API.md contract: field presence = strip, field absence = no strip
- retry() passes current preference values at retry time (not original failure-time values) — honours any preference changes between failure and retry

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Renamed performUpload() Bool parameters to avoid method shadowing**
- **Found during:** Task 2 (build verification)
- **Issue:** `openInBrowser: Bool` parameter in `performUpload()` shadowed the private method `openInBrowser(_ urlString: String)`. Calling `await openInBrowser(result.shareUrl)` triggered Swift error: "cannot call value of non-function type 'Bool'"
- **Fix:** Renamed the Bool parameters to `shouldOpenInBrowser` and `shouldCopyToClipboard` inside `performUpload()` and updated the corresponding call site in `enqueue()`'s Task closure
- **Files modified:** `teil.ing-client/Services/UploadService.swift`
- **Verification:** BUILD SUCCEEDED after fix
- **Committed in:** `7ee2fd2` (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 - naming collision bug)
**Impact on plan:** Required fix; Swift 6 strict concurrency catches the ambiguity as a compile error. No scope creep.

## Issues Encountered
- Swift parameter shadowing: `openInBrowser: Bool` parameter name in `performUpload()` collided with private method `func openInBrowser(_ urlString: String)`. Swift 6 compiler reported "cannot call value of non-function type 'Bool'". Fixed by renaming Bool parameters to `shouldOpenInBrowser`/`shouldCopyToClipboard`.

## User Setup Required
None - no external service configuration required. Preferences default to ON on first launch via @AppStorage default values.

## Next Phase Readiness
- PreferencesStore is ready for Phase 8 SwiftUI Preferences window — inject PreferencesStore.shared into environment from AppDelegate
- Three preference defaults (all ON) are active immediately; upload pipeline now conditionally strips EXIF and gates clipboard/browser actions
- Phase 7 (whatever is next) can read PreferencesStore.shared directly if needed

---
*Phase: 06-exif-stripping-and-behavior-toggles*
*Completed: 2026-02-18*
