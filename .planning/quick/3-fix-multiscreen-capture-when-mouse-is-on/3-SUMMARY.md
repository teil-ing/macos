---
phase: quick-3
plan: 01
subsystem: capture
tags: [ScreenCaptureKit, NSScreen, NSMouseInRect, AppKit, multi-screen]

# Dependency graph
requires:
  - phase: 03-capture-engine-region-and-fullscreen
    provides: findCurrentDisplay() and CaptureEngine.swift established
provides:
  - Correct multi-screen fullscreen capture using NSMouseInRect hit-testing
affects: [capture, CaptureEngine]

# Tech tracking
tech-stack:
  added: []
  patterns: [NSMouseInRect for AppKit screen hit-testing instead of CGRect.contains]

key-files:
  created: []
  modified:
    - teil.ing-client/Services/CaptureEngine.swift

key-decisions:
  - "NSMouseInRect(mouse, frame, false) used instead of CGRect.contains — NSMouseInRect is the idiomatic AppKit function that correctly handles coordinate system edge cases and is inclusive at all boundaries; CGRect.contains is exclusive at maxX/maxY and fails when mouse is at screen edge boundaries"
  - "Screen matching moved inside MainActor.run block — only ScreenInfo (Sendable) crosses the actor boundary, not NSScreen objects; returns single matched ScreenInfo rather than all screens + mouse location tuple"
  - "Fallback chain: NSMouseInRect match -> NSScreen.main -> NSScreen.screens.first! — same safety guarantees as before, using correct hit-test function"

patterns-established:
  - "Multi-screen hit-testing: always use NSMouseInRect(point, frame, false) on MainActor, not CGRect.contains"

requirements-completed: [QUICK-3]

# Metrics
duration: 3min
completed: 2026-03-01
---

# Quick Task 3: Fix Multi-Screen Capture Summary

**NSMouseInRect replaces CGRect.contains in findCurrentDisplay() so fullscreen capture targets the screen the mouse is on, not always the primary screen**

## Performance

- **Duration:** ~3 min
- **Started:** 2026-03-01T00:00:00Z
- **Completed:** 2026-03-01T00:03:00Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments
- Fixed `findCurrentDisplay()` to use `NSMouseInRect(mouse, $0.frame, false)` instead of `$0.frame.contains(mouseLocation)` for screen hit-testing
- Screen matching now happens inside the `MainActor.run` block where `NSScreen` is available, returning a single `ScreenInfo` (Sendable) rather than all screens + mouse location
- Fallback chain preserved: NSMouseInRect match -> NSScreen.main -> first screen

## Task Commits

Each task was committed atomically:

1. **Task 1: Fix findCurrentDisplay() to use NSMouseInRect for correct multi-screen hit-testing** - `921b195` (fix)

**Plan metadata:** `[see final commit]` (docs: complete plan)

## Files Created/Modified
- `teil.ing-client/Services/CaptureEngine.swift` - `findCurrentDisplay()` now uses `NSMouseInRect` for correct AppKit coordinate hit-testing

## Decisions Made
- Used `NSMouseInRect(mouse, $0.frame, false)` — the `false` parameter indicates AppKit's non-flipped (Y-up) coordinate system. This is the idiomatic AppKit function for testing if a point is within a screen frame. `CGRect.contains()` is exclusive on maxX/maxY boundaries and fails when the cursor is at the exact edge of a secondary screen.
- Moved screen matching inside `MainActor.run` — instead of collecting all screens and returning them for off-actor matching, we perform the match where `NSScreen` is actually available and only return the resolved `ScreenInfo` (a `Sendable` struct). This is both more correct and simpler.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Multi-screen fullscreen capture now correctly targets whichever screen the mouse cursor is on
- No regressions in primary screen capture behavior (fallback chain unchanged)

---
*Phase: quick-3*
*Completed: 2026-03-01*

## Self-Check: PASSED

- FOUND: `teil.ing-client/Services/CaptureEngine.swift`
- FOUND: commit `921b195`
- FOUND: `NSMouseInRect` in CaptureEngine.swift (lines 308, 312)
