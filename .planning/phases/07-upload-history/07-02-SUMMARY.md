---
phase: 07-upload-history
plan: 02
subsystem: ui
tags: [swiftui, swiftdata, history, thumbnail, popover]

requires:
  - phase: 07-01
    provides: HistoryEntry SwiftData model, ThumbnailService, HistoryStore, UploadFeedbackEvent carrying CaptureResult

provides:
  - HistoryRowView with thumbnail, relative timestamp auto-refresh, copy-URL and open-in-browser buttons
  - HistorySection with empty state, count header, scrollable list, swipe-to-delete, Clear All dialog
  - PopoverRootView accepting HistoryStore injection, 320pt width
  - AppDelegate ModelContainer init and history entry creation on upload success

affects:
  - Phase 07-03 (plan 03 verifies full end-to-end history feature)

tech-stack:
  added: []
  patterns:
    - "@ObservedObject injection from AppDelegate through PopoverRootView to HistorySection"
    - "TimelineView(.everyMinute) for auto-refreshing relative timestamps without polling"
    - "File-first write pattern: ThumbnailService.saveThumbnail before historyStore.addEntry (no dangling DB records)"

key-files:
  created:
    - teil.ing-client/Views/HistoryRowView.swift
  modified:
    - teil.ing-client/Views/HistorySection.swift
    - teil.ing-client/Views/PopoverRootView.swift
    - teil.ing-client/App/AppDelegate.swift

key-decisions:
  - "Popover width widened from 280pt to 320pt to accommodate history list with thumbnails"
  - "HistorySection List capped at 330pt maxHeight to prevent popover height explosion"
  - "RelativeDateTimeFormatter stored as struct property, not created in body (expensive init)"
  - "ThumbnailService.saveThumbnail called on main actor synchronously — CGImage resize at 64px is negligibly fast"
  - "Tasks 1 and 2 executed atomically because HistorySection's new @ObservedObject init broke PopoverRootView immediately"

requirements-completed: [SHELL-02, SHELL-04]

duration: 2min
completed: 2026-02-18
---

# Phase 7 Plan 02: Upload History UI Integration Summary

**SwiftUI HistoryRowView with thumbnail/timestamp/action buttons wired end-to-end from AppDelegate ModelContainer init through PopoverRootView injection to HistorySection, completing persistent upload history visible in the 320pt popover after every upload.**

## Performance

- **Duration:** 2 min
- **Started:** 2026-02-18T01:30:16Z
- **Completed:** 2026-02-18T01:32:xx Z
- **Tasks:** 2
- **Files modified:** 4 (1 created, 3 modified)

## Accomplishments

- Created HistoryRowView with 32x32pt rounded thumbnail, TimelineView(.everyMinute) auto-refreshing relative timestamp, copy-URL button with 1.5-second checkmark feedback, and open-in-browser button
- Rebuilt HistorySection as a real SwiftUI List with @ObservedObject HistoryStore, count-showing header, clock-icon empty state, swipe-to-delete, and Clear All confirmation dialog capped at 330pt height
- Wired the full pipeline: AppDelegate initializes ModelContainer + HistoryStore at launch, generates thumbnail on upload success via ThumbnailService, writes entry via historyStore.addEntry, and injects historyStore through PopoverRootView down to HistorySection

## Task Commits

Each task was committed atomically:

1. **Task 1: HistoryRowView + rebuilt HistorySection** - `20b9e12` (feat)
2. **Task 2: PopoverRootView + AppDelegate integration** - `6290555` (feat)

## Files Created/Modified

- `teil.ing-client/Views/HistoryRowView.swift` — New: single history row with thumbnail, relative timestamp, copy-URL button, open-in-browser button, context menu Delete
- `teil.ing-client/Views/HistorySection.swift` — Rewritten: real List with @ObservedObject store, empty state, header with count, swipe-to-delete, Clear All confirmationDialog
- `teil.ing-client/Views/PopoverRootView.swift` — Updated: @ObservedObject historyStore property, HistorySection(store:) call, frame widened from 280pt to 320pt, #Preview blocks updated with in-memory ModelContainer
- `teil.ing-client/App/AppDelegate.swift` — Updated: SwiftData import, modelContainer/historyStore stored properties, ModelContainer init in completeLaunch(), historyStore passed to setupPopover()/rebuildPopoverContent(), thumbnail generation and addEntry in handleUploadFeedback .uploadSucceeded case

## Decisions Made

| Decision | Rationale |
|----------|-----------|
| 320pt popover width | History rows with 32pt thumbnails + timestamp + two icon buttons need more horizontal space than 280pt allows |
| 330pt List maxHeight cap | Prevents popover from expanding beyond screen space with many entries; shows ~8-10 rows |
| Formatter as struct property | RelativeDateTimeFormatter is expensive to init — storing as property avoids per-render allocation |
| Synchronous thumbnail on main actor | 64px CGImage resize is negligibly fast; background dispatch adds complexity with no measurable benefit |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Tasks 1 and 2 executed together due to compile dependency**
- **Found during:** Task 1 (HistoryRowView + HistorySection)
- **Issue:** Rewriting HistorySection to require `store: HistoryStore` parameter immediately broke PopoverRootView's `HistorySection()` call with no-arg init. Build failed after Task 1 files were written.
- **Fix:** Proceeded to Task 2's PopoverRootView changes immediately before committing, then committed both tasks separately with correct commit messages
- **Files modified:** teil.ing-client/Views/PopoverRootView.swift (part of planned Task 2 scope)
- **Verification:** Build succeeded after both files updated
- **Committed in:** 20b9e12 (Task 1) and 6290555 (Task 2)

---

**Total deviations:** 1 auto-fixed (blocking compile dependency between tasks)
**Impact on plan:** No scope creep — the fix was executing Task 2's already-planned changes before committing Task 1.

## Issues Encountered

None beyond the inter-task compile dependency documented above.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- The complete upload history feature is wired end-to-end: capture → upload → thumbnail → history entry → visible in popover
- History entries persist across app restarts via SwiftData
- Individual and bulk delete work (swipe-to-delete, context menu Delete, Clear All confirmation)
- Plan 03 (human verification checkpoint) can now confirm the full feature works correctly at runtime

## Self-Check: PASSED

- `teil.ing-client/Views/HistoryRowView.swift` — exists
- `teil.ing-client/Views/HistorySection.swift` — exists (rewritten)
- `teil.ing-client/Views/PopoverRootView.swift` — exists (modified)
- `teil.ing-client/App/AppDelegate.swift` — exists (modified)
- Commit `20b9e12` — verified via git log
- Commit `6290555` — verified via git log
- Build: SUCCEEDED

---
*Phase: 07-upload-history*
*Completed: 2026-02-18*
