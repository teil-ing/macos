# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-17)

**Core value:** Capture a screenshot and have a shareable teil.ing URL on the clipboard in seconds — zero friction from capture to share.
**Current focus:** Phase 4 — Window Capture and Global Hotkeys (in progress — Plan 01 complete)

## Current Position

Phase: 4 of 9 (Window Capture and Global Hotkeys) — IN PROGRESS
Plan: 1 of 3 in current phase — COMPLETE (Plans 02 and 03 remaining)
Status: Phase 4 Plan 01 complete — window capture overlay and menu bar wiring done
Last activity: 2026-02-17 — Phase 4 Plan 01 (Window Capture Core) complete — CaptureEngine.captureWindow, WindowSelectionCoordinator, WindowSelectionOverlayView, AppDelegate wiring compiled and built successfully

Progress: [████░░░░░░] 36%

## Performance Metrics

**Velocity:**
- Total plans completed: 9
- Average duration: 7 min
- Total execution time: 0.7 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 01-app-shell | 2/3 | 18 min | 9 min |
| 02-onboarding-and-keychain | 2/2 | 1 min | 1 min |
| 03-capture-engine-region-and-fullscreen | 3/3 | 21 min | 7 min |
| 04-window-capture-and-global-hotkeys | 1/3 | 5 min | 5 min |

**Recent Trend:**
- Last 5 plans: 03-01 (6 min), 03-02 (est. 5 min), 03-03 (~15 min incl. human verify), 04-01 (5 min)
- Trend: Stable

*Updated after each plan completion*

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- Project setup: Menu bar-only (LSUIElement = YES), AppKit/SwiftUI hybrid, notarized DMG (not App Store)
- Architecture: NSStatusItem retained on AppDelegate property — never in SwiftUI State or local variable
- Persistence: SwiftData (macOS 14+) with Codable+JSON fallback for macOS 13 Ventura
- Capture: ScreenCaptureKit only (no screencapture CLI); two code paths — SCScreenshotManager (14+) and SCStream (13)
- 01-01: Used xcodegen (project.yml) for Xcode project generation — avoids manual pbxproj editing
- 01-01: App Sandbox disabled (ENABLE_APP_SANDBOX=NO) — conflicts with ScreenCaptureKit in Phase 3
- 01-01: NSStatusItem as AppDelegate stored property confirmed — never local variable or SwiftUI State
- 01-01: makeKey() required after popover show for transient dismiss to work on first open
- 01-01: Task { @MainActor } wrapper in global event monitor for Swift 6 strict concurrency compliance
- 01-02: PopoverRootView fixed at 280pt width — content-adaptive height, no manual contentSize on NSPopover
- 01-02: CaptureSection buttons disabled at shell stage — enabled in Phase 3/4 when ScreenCaptureKit is wired
- 01-02: NSApp.terminate(nil) called directly from SwiftUI action — no AppDelegate bridge needed at this stage
- 01-02: Footer uses .background(.bar) material for visual separation without heaviness
- [Phase 02-onboarding-and-keychain]: KeychainService is nonisolated struct (not actor) — Security framework calls are synchronous C functions, nonisolated is simplest for Swift 6 strict concurrency
- [Phase 02-onboarding-and-keychain]: API key validation uses X-API-Key header (not Bearer) per teil.ing API contract
- [Phase 02-onboarding-and-keychain]: SCShareableContent timeout via withTaskGroup racing two tasks: real call vs 8-second sleep
- [Phase 02-onboarding-and-keychain]: Onboarding/ source group added in Plan 01 to avoid second xcodegen run in Plan 02
- [Phase 03]: SelectionOverlayView uses window.nextEvent(matching:) synchronous tracking loop — matches AppKit screenshot tool pattern
- [Phase 03]: OverlayCoordinator: withCheckedContinuation bridges onSelectionComplete callback to async/await; first-view-to-respond wins pattern
- [Phase 03]: Overlay NSWindows: .screenSaver level + .canJoinAllSpaces + .fullScreenAuxiliary + sharingType = .none
- [Phase 03-01]: @preconcurrency import ScreenCaptureKit silences Sendable warnings on ObjC types in Swift 6 strict concurrency
- [Phase 03-01]: NSScreen data extracted as Sendable ScreenInfo struct on MainActor — only CGRect/CGFloat cross actor boundaries
- [Phase 03-01]: StreamCaptureBridge stops stream via self.stopStream() async (self is @unchecked Sendable) to avoid SCStream Sendable issue in Task closure
- [Phase 03-01]: SCContentFilter always uses excludingApplications:exceptingWindows: form (never excludingWindows: with empty array — known hang bug)
- [Phase 03-03]: CaptureFeedback is a caseless @MainActor enum (namespace pattern) — all methods MainActor-safe without per-call dispatching
- [Phase 03-03]: NSSound(named: "Glass") used for capture sound — more reliable cross-version than AudioServicesPlaySystemSound(1108)
- [Phase 03-03]: Flash window uses withCheckedContinuation wrapping NSAnimationContext completion — awaitable by callers
- [Phase 03-03]: Success icon revert Task stored as Task<Void, Never>? and cancelled before each new success — prevents stale revert on rapid captures
- [Phase 03-03]: Capture trigger pattern: closePopover -> Task { @MainActor } -> sleep(200ms) -> action -> feedback
- [Phase 03-03]: AppDelegate.lastCaptureResult: CaptureResult? stores last capture — ready for Phase 5 UploadService
- [Phase 04-01]: nonisolated(unsafe) used for SCWindow transfer (non-Sendable ObjC type) across MainActor → CaptureEngine actor boundary
- [Phase 04-01]: SCWindow.frame extracted to Sendable CGRect before actor hop so it remains available on MainActor for CaptureFeedback positioning
- [Phase 04-01]: cachedWindows fetched once in beginWindowSelection() before overlay appears — avoids async latency in hover loop (research Pitfall 6)
- [Phase 04-01]: WindowSelectionOverlayView uses weak coordinator reference to avoid reference cycle
- [Phase 04-01]: .activeAlways tracking area used (not .activeInKeyWindow) since overlay is never key window during hover

### Pending Todos

None.

### Blockers/Concerns

- **Phase 4**: CGEventTap and Accessibility permission prompting behavior changed in macOS 14/15 — validate before implementing HotkeyMonitor
- **Phase 5**: teil.ing REST API contract (exact multipart field names, rate limit headers, response schema) must be confirmed with project owner before implementing UploadService
- **Phase 9**: Apple Developer ID certificate and notarization workflow availability must be confirmed before Phase 9 starts

## Session Continuity

Last session: 2026-02-17
Stopped at: Completed 04-01-PLAN.md (Window Capture Core — CaptureEngine.captureWindow, WindowSelectionCoordinator, WindowSelectionOverlayView, AppDelegate wiring — built successfully with zero errors)
Resume file: None
