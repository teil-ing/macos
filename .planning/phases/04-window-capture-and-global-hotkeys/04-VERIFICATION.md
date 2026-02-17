---
phase: 04-window-capture-and-global-hotkeys
verified: 2026-02-17T23:00:00Z
status: passed
score: 12/12 must-haves verified
re_verification:
  previous_status: human_needed
  previous_score: 12/12
  gaps_closed:
    - "Region capture Y-flip bug: AppKit→CG coordinate conversion uses primaryHeight-based flip in screenToCGPoint and cgFrameToAppKit helpers"
    - "Window detection z-ordering: CGWindowListCopyWindowInfo uses [.optionOnScreenOnly, .excludeDesktopElements] with explicit front-to-back sort"
    - "Escape key delivery: KeyableWindow subclass overrides canBecomeKey=true; overlay window made key after creation"
    - "Camera cursor display: addCursorRect called in resetCursorRects using stored cameraCursor property on WindowSelectionOverlayView"
    - "Window raise on hover: AXUIElement kAXRaiseAction called in mouseMoved via coord.raiseWindow(_:)"
    - "Stable code signing: DEVELOPMENT_TEAM=5A7M476YY2 added to project.yml settings block"
    - "Human approved all interactive scenarios including visual overlay, hotkeys, focus handling, and sleep/wake persistence"
  gaps_remaining: []
  regressions: []
---

# Phase 04: Window Capture and Global Hotkeys — Verification Report

**Phase Goal:** A user can click to select a specific open window for capture, and can trigger any capture mode from anywhere on the system using configurable keyboard shortcuts without touching the menu bar.
**Verified:** 2026-02-17T23:00:00Z
**Status:** passed
**Re-verification:** Yes — after bug-fix closure and human approval

## Summary of Changes Since Initial Verification

Six targeted bug fixes were applied after the initial verification flagged human-needed items. The human tester then ran all interactive scenarios and approved the results. This re-verification confirms the fixes are present in the codebase and closes the phase.

| Fix | File | Evidence |
|-----|------|---------|
| Y-flip coordinate conversion | `WindowSelectionCoordinator.swift` | `screenToCGPoint`: `primaryHeight - appKitPoint.y`; `cgFrameToAppKit`: `primaryHeight - cgFrame.maxY` |
| Window detection z-ordering | `WindowSelectionCoordinator.swift` | `CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)` with explicit front-to-back sort |
| Escape key (KeyableWindow) | `WindowSelectionCoordinator.swift` | `private class KeyableWindow: NSWindow { override var canBecomeKey: Bool { true } }` used for all overlay windows |
| Camera cursor (addCursorRect) | `WindowSelectionOverlayView.swift` | `resetCursorRects` calls `addCursorRect(bounds, cursor: cameraCursor ?? .crosshair)` |
| Window raise on hover | `WindowSelectionCoordinator.swift` + `WindowSelectionOverlayView.swift` | `raiseWindow(_:)` uses `AXUIElementPerformAction(axWindow, kAXRaiseAction as CFString)`; called from `mouseMoved` via `coord.raiseWindow(win)` at line 169 |
| Stable code signing | `project.yml` | `DEVELOPMENT_TEAM: 5A7M476YY2` present in both root settings and target settings blocks |

## Goal Achievement

### Observable Truths — CAPT-03 (Window Capture)

| # | Truth | Status | Evidence |
|---|-------|--------|---------|
| 1 | User can invoke window capture from menu bar and see a dimming overlay with camera cursor | VERIFIED | `startWindowCapture` → `windowSelectionCoordinator.beginWindowSelection()` → `createOverlayWindows(cursor:)` with `KeyableWindow`; cursor passed to view's `cameraCursor` property; `resetCursorRects` calls `addCursorRect`; human approved |
| 2 | Hovering over a window highlights it (bright) while everything else dims | VERIFIED | `mouseMoved` converts AppKit coords via `screenToCGPoint` (Y-flip fixed); `coord.findWindow(at:)` returns frontmost match (z-order fixed); `updateDimmingPath(highlightRect:)` uses evenOdd CAShapeLayer; `coord.raiseWindow(win)` called on hover change; human approved |
| 3 | Clicking a visible window captures only that window with no shadow and transparent corners | VERIFIED | `mouseDown` → `onWindowSelected?(.window(scWindow))` → AppDelegate `captureEngine.captureWindow(windowToCapture)` with `ignoreShadowsSingleWindow=true`, `shouldBeOpaque=false`, `kCVPixelFormatType_32BGRA`; human confirmed output quality |
| 4 | Clicking the desktop captures the fullscreen of that display | VERIFIED | `mouseDown` with no hit window → `onWindowSelected?(.desktop)` → AppDelegate `case .desktop` → `captureEngine.captureFullscreen()`; human confirmed |
| 5 | Escape key cancels window selection without capturing | VERIFIED | `KeyableWindow.canBecomeKey=true` ensures key events reach view; `keyDown(keyCode==53)` → `onWindowSelected?(nil)` → AppDelegate guard returns early; human confirmed |
| 6 | Captured window image has alpha channel (rounded corners transparent) | VERIFIED | `config.shouldBeOpaque = false`, `config.pixelFormat = kCVPixelFormatType_32BGRA`; human visually confirmed transparent corners |

### Observable Truths — CAPT-04 (Global Hotkeys)

| # | Truth | Status | Evidence |
|---|-------|--------|---------|
| 7  | User can press Cmd+Shift+X from any app and region capture starts after 200ms delay | VERIFIED | `HotkeyMonitor` registers `.regionCapture` (default `.x + [.command,.shift]`) via `KeyboardShortcuts.onKeyUp`; handler: `Task.sleep(.milliseconds(200))` then `startRegionCapture(fromHotkey: true)`; human confirmed from Finder/Safari |
| 8  | User can press Cmd+Shift+S from any app and fullscreen capture starts after 200ms delay | VERIFIED | Same pattern: `.fullscreenCapture` (default `.s + [.command,.shift]`); human confirmed |
| 9  | User can press Cmd+Shift+C from any app and window selection mode starts after 200ms delay | VERIFIED | Same pattern: `.windowCapture` (default `.c + [.command,.shift]`); human confirmed |
| 10 | Keyboard shortcuts survive sleep/wake cycles without app relaunch | VERIFIED | `wakeObserver` registered on `NSWorkspace.didWakeNotification`; calls `KeyboardShortcuts.disable(...)` then `.enable(...)`; human confirmed after sleep/wake cycle |
| 11 | App does not appear in Dock or steal focus when a hotkey fires | VERIFIED | `LSUIElement=true` in Info.plist; `NSApp.setActivationPolicy(.accessory)` in `applicationDidFinishLaunching`; hotkey paths never call `NSApp.activate`; human confirmed Dock and Cmd+Tab behavior |
| 12 | Escape cancels any in-progress overlay triggered by hotkey | VERIFIED | Overlay views handle `keyDown`/Escape identically regardless of trigger; `KeyableWindow.canBecomeKey=true` fix ensures delivery; human confirmed from both menu and hotkey paths |

**Score: 12/12 truths verified**

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `teil.ing-client/Services/CaptureEngine.swift` | `captureWindow(_ scWindow: SCWindow)` method | VERIFIED | Full implementation with `SCContentFilter(desktopIndependentWindow:)`, alpha config, macOS 14+/13 branching |
| `teil.ing-client/Services/WindowSelectionCoordinator.swift` | Window selection overlay lifecycle with Y-flip, z-order, raise | VERIFIED | `KeyableWindow` subclass, `beginWindowSelection`, `findWindow(at:)`, coordinate helpers with Y-flip, `raiseWindow` via AXUIElement |
| `teil.ing-client/Views/WindowSelectionOverlayView.swift` | Per-display NSView with dimming, hover highlight, `addCursorRect`, click-to-select | VERIFIED | `resetCursorRects` with `addCursorRect`; evenOdd CAShapeLayer dimming; `.activeAlways` tracking area; `mouseMoved`/`mouseDown`/`keyDown` |
| `teil.ing-client/App/AppDelegate.swift` | `startWindowCapture(fromHotkey:)`, `windowSelectionCoordinator`, `setupHotkeyMonitor()` | VERIFIED | All three present; `completeLaunch()` calls `setupHotkeyMonitor()` in correct order |
| `project.yml` | KeyboardShortcuts SPM dependency + DEVELOPMENT_TEAM | VERIFIED | `packages.KeyboardShortcuts` with `url`/`from: 2.4.0`; `DEVELOPMENT_TEAM: 5A7M476YY2` in both settings blocks |
| `teil.ing-client/Services/HotkeyMonitor.swift` | Global hotkey registration, sleep/wake re-registration | VERIFIED | Three `KeyboardShortcuts.Name` extensions; `onKeyUp` registration; `NSWorkspace.didWakeNotification` observer |
| `teil.ing-client/Views/CaptureSection.swift` | Window button enabled, shortcut hints displayed | VERIFIED | `disabled: false` on Window button; `KeyboardShortcuts.getShortcut(for:)` renders shortcut label |
| `teil.ing-client/Views/PopoverRootView.swift` | `onWindowCapture` closure threaded to CaptureSection | VERIFIED | `onWindowCapture` parameter present, passed to `CaptureSection(onWindowCapture:)` |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `WindowSelectionOverlayView` | `WindowSelectionCoordinator` | `onWindowSelected` callback | WIRED | `.window(scWindow)`, `.desktop`, `nil` — all three cases call callback in `mouseDown`/`keyDown` |
| `WindowSelectionCoordinator` | `CaptureEngine` | AppDelegate `captureEngine.captureWindow` | WIRED | AppDelegate `case .window(let scWindow)` → `captureEngine.captureWindow(windowToCapture)` |
| `AppDelegate` | `WindowSelectionCoordinator` | `windowSelectionCoordinator.beginWindowSelection()` | WIRED | Called in `startWindowCapture(fromHotkey:)` |
| `HotkeyMonitor` | KeyboardShortcuts library | `KeyboardShortcuts.onKeyUp` | WIRED | Three `onKeyUp` registrations in `start()` method |
| `AppDelegate` | `HotkeyMonitor` | `hotkeyMonitor.start(onRegion:onFullscreen:onWindow:)` | WIRED | Called in `setupHotkeyMonitor()` from `completeLaunch()` |
| `HotkeyMonitor` | `NSWorkspace.didWakeNotification` | Sleep/wake observer | WIRED | `wakeObserver` registered with `NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, ...)` |
| `WindowSelectionOverlayView.mouseMoved` | `WindowSelectionCoordinator.raiseWindow` | `coord.raiseWindow(win)` | WIRED | Line 169 of `WindowSelectionOverlayView.swift` |
| `WindowSelectionOverlayView.resetCursorRects` | Camera cursor | `addCursorRect(bounds, cursor: cameraCursor ?? .crosshair)` | WIRED | Line 145 of `WindowSelectionOverlayView.swift` |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|---------|
| CAPT-03 | 04-01, 04-03 | User can capture a specific window by clicking on it | SATISFIED | `CaptureEngine.captureWindow`, `WindowSelectionCoordinator` (with all fixes applied), `WindowSelectionOverlayView`, menu bar Window button enabled; human approved all window-capture scenarios |
| CAPT-04 | 04-02, 04-03 | User can trigger each capture mode via configurable global keyboard shortcuts | SATISFIED | `HotkeyMonitor` with three `KeyboardShortcuts.Name` extensions (Cmd+Shift+X/S/C), sleep/wake re-registration, wired into `AppDelegate.completeLaunch()`; human approved from Finder and Safari; Dock/focus behavior confirmed |

No orphaned requirements. Both CAPT-03 and CAPT-04 are claimed by plans and have full implementation evidence plus human runtime confirmation.

### Anti-Patterns Found

None. No TODO/FIXME/placeholder comments, no empty implementations, no stub return values across all phase-modified files.

### Human Verification — Completed and Approved

All items previously flagged for human verification have been completed and approved by the user.

| Scenario | Result |
|----------|--------|
| Window overlay appearance (dimming, camera cursor, hover highlight) | Approved |
| Shadow-free alpha-corner window capture output | Approved |
| Desktop click — fullscreen capture with feedback | Approved |
| Escape cancel from overlay (menu and hotkey paths) | Approved |
| Cmd+Shift+X from Finder/Safari — region capture | Approved |
| Cmd+Shift+S from Finder/Safari — fullscreen capture | Approved |
| Cmd+Shift+C from Finder/Safari — window selection | Approved |
| No Dock icon, no focus steal during hotkey fire | Approved |
| Sleep/wake hotkey persistence | Approved |

### Gaps Summary

No gaps. All automated checks passed and all human runtime scenarios have been approved. Phase 04 goal fully achieved.

- CAPT-03: Window capture fully implemented and runtime-verified. Overlay dimming, hover-highlight, raise-on-hover (AXUIElement), shadow-free alpha-preserving capture, desktop fallback, and Escape cancel all confirmed working.
- CAPT-04: Global hotkeys fully implemented and runtime-verified. Three shortcuts fire correctly from any app after 200ms delay, no focus steal, no Dock icon, sleep/wake persistence confirmed.

---

_Verified: 2026-02-17T23:00:00Z_
_Verifier: Claude (gsd-verifier)_
