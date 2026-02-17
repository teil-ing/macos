---
phase: 04-window-capture-and-global-hotkeys
plan: "01"
subsystem: capture
tags: [window-capture, overlay, screenCaptureKit, nsview, coordinate-conversion]
dependency_graph:
  requires:
    - "03-03: CaptureFeedback (flash, sound, icon)"
    - "03-01: CaptureEngine (actor, StreamCaptureBridge, ScreenshotCapture)"
    - "03-02: OverlayCoordinator + SelectionOverlayView (architecture pattern)"
  provides:
    - "CaptureEngine.captureWindow(SCWindow) -> CaptureResult"
    - "WindowSelectionCoordinator.beginWindowSelection() -> WindowSelectionResult?"
    - "WindowSelectionOverlayView: hover-highlight dimming overlay"
    - "AppDelegate.startWindowCapture() wired to menu bar button"
  affects:
    - "04-02: HotkeyMonitor (will call startWindowCapture)"
    - "04-03: Any future integration tests"
tech_stack:
  added: []
  patterns:
    - "SCContentFilter(desktopIndependentWindow:) for shadow-free, alpha-corner window capture"
    - "nonisolated(unsafe) for SCWindow transfer across MainActor -> CaptureEngine actor boundary"
    - "NSCursor push/pop for camera cursor lifecycle"
    - "evenOdd CAShapeLayer fill rule for hover-highlight dimming hole"
    - ".activeAlways NSTrackingArea for mouse events on overlay windows"
    - "SCShareableContent fetched once before overlay (cache for hover loop)"
key_files:
  created:
    - "teil.ing-client/Services/WindowSelectionCoordinator.swift"
    - "teil.ing-client/Views/WindowSelectionOverlayView.swift"
  modified:
    - "teil.ing-client/Services/CaptureEngine.swift"
    - "teil.ing-client/App/AppDelegate.swift"
    - "teil.ing-client/Views/CaptureSection.swift"
    - "teil.ing-client/Views/PopoverRootView.swift"
decisions:
  - "nonisolated(unsafe) used for SCWindow transfer (non-Sendable ObjC type) across actor boundary, matching existing CaptureEngine patterns for SCContentFilter/SCStreamConfiguration"
  - "SCWindow.frame extracted to windowFrame (CGRect, Sendable) before actor hop so it remains accessible on MainActor for CaptureFeedback.showCaptureFlash positioning"
  - "cachedWindows fetched once in beginWindowSelection() before overlay appears, not per-mouseMoved, to avoid async latency in hover loop (research Pitfall 6)"
  - "WindowSelectionOverlayView uses weak coordinator reference to avoid reference cycle (coordinator holds [(NSWindow, view)] pairs)"
  - ".activeAlways tracking area used (not .activeInKeyWindow) since overlay is never key window during hover (research Pitfall 5)"
metrics:
  duration: "5 min"
  completed: "2026-02-17"
  tasks_completed: 2
  files_modified: 6
---

# Phase 04 Plan 01: Window Capture Core — Summary

**One-liner:** SCContentFilter(desktopIndependentWindow:) window capture with hover-dimming overlay using evenOdd CAShapeLayer, camera cursor from HIServices, and full AppDelegate wiring.

## Tasks Completed

| Task | Description | Commit |
|------|-------------|--------|
| 1 | CaptureEngine.captureWindow + WindowSelectionCoordinator + WindowSelectionOverlayView | d4e1c0a |
| 2 | Wire window capture into AppDelegate, CaptureSection, PopoverRootView | 2ad91a2 |

## What Was Built

### CaptureEngine.captureWindow (CaptureEngine.swift)
New method using `SCContentFilter(desktopIndependentWindow:)` that captures a specific SCWindow with:
- `ignoreShadowsSingleWindow = true` — excludes drop shadow (counter-intuitive naming per research Pitfall 3)
- `shouldBeOpaque = false` — preserves alpha channel for transparent rounded corners
- `kCVPixelFormatType_32BGRA` pixel format (has alpha channel)
- Same macOS 14+ / macOS 13 branching as existing capture methods
- New error case `windowCaptureFailedNoImage` added to `CaptureEngineError`

### WindowSelectionCoordinator (new file)
`@MainActor final class` mirroring OverlayCoordinator architecture:
- `beginWindowSelection() async -> WindowSelectionResult?` — fetches SCWindow list once, shows overlay, returns `.window(SCWindow)`, `.desktop`, or `nil` (cancel)
- `findWindow(at cgPoint: CGPoint) -> SCWindow?` — hit-tests cached window list front-to-back
- `appKitPointToCG()` / `cgFrameToAppKit()` — coordinate conversion between AppKit (bottom-left origin) and CG (top-left origin) coordinate spaces
- Camera cursor loaded from HIServices screenshotwindow path with fallback to `.arrow`
- `tearDown()` pops cursor and closes all overlay windows

### WindowSelectionOverlayView (new file)
NSView subclass covering one display:
- evenOdd `CAShapeLayer` dimming (0.35 alpha) with dynamic hole for hovered window
- `.activeAlways` NSTrackingArea for mouse events regardless of key window status
- `mouseMoved` — converts view → screen → CG coords, calls `findWindow(at:)`, updates dimming hole
- `mouseDown` — reports `.window(SCWindow)` or `.desktop` depending on hit result
- `keyDown` — Escape (keyCode 53) reports `nil` to cancel
- `resetCursorRects` intentionally empty — cursor managed by coordinator push/pop

### AppDelegate + UI wiring
- `windowSelectionCoordinator: WindowSelectionCoordinator` stored property added
- `startWindowCapture()` follows same pattern as region/fullscreen: 200ms delay → overlay → 50ms compositor wait → captureWindow or captureFullscreen (desktop click) → feedback
- `nonisolated(unsafe) let windowToCapture = scWindow` transfers SCWindow across actor boundary
- `windowFrame` extracted before await so it's available on MainActor for CaptureFeedback positioning
- `onWindowCapture` closure threaded through PopoverRootView and CaptureSection
- Window button changed from `disabled: true` to `disabled: false` in CaptureSection

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Swift 6 strict concurrency error: SCWindow not Sendable**
- **Found during:** Task 2 build
- **Issue:** `captureEngine.captureWindow(scWindow)` was sending a non-Sendable `SCWindow` across the MainActor → CaptureEngine actor boundary, triggering a "sending risks causing data races" error under Swift 6 strict concurrency
- **Fix:** Applied existing project pattern — extracted `windowFrame = scWindow.frame` (Sendable CGRect) before the await, then wrapped the SCWindow in `nonisolated(unsafe) let windowToCapture = scWindow` before passing to captureEngine
- **Files modified:** `teil.ing-client/App/AppDelegate.swift`
- **Commit:** 2ad91a2

## Self-Check

- [x] `teil.ing-client/Services/WindowSelectionCoordinator.swift` exists
- [x] `teil.ing-client/Views/WindowSelectionOverlayView.swift` exists
- [x] `teil.ing-client/Services/CaptureEngine.swift` contains `captureWindow`
- [x] `teil.ing-client/App/AppDelegate.swift` contains `startWindowCapture`
- [x] Commit d4e1c0a exists
- [x] Commit 2ad91a2 exists
- [x] Build: `** BUILD SUCCEEDED **` with zero errors

## Self-Check: PASSED
