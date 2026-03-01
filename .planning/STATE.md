# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-17)

**Core value:** Capture a screenshot and have a shareable teil.ing URL on the clipboard in seconds — zero friction from capture to share.
**Current focus:** All 9 phases complete — ready for distribution once Developer ID certificate is configured

## Current Position

Phase: 9 of 9 (Polish and Distribution) — COMPLETE
Plan: 3 of 3 in current phase — ALL COMPLETE
Status: Phase 9 Plan 03 complete — all 7 Phase 9 verification items confirmed by user; error paths, build infrastructure, and CI pipeline all approved
Last activity: 2026-03-01 - Completed quick task 2: Move preferences from separate window into popover as inline navigation

Progress: [██████████] 100%

## Performance Metrics

**Velocity:**
- Total plans completed: 13
- Average duration: 6 min
- Total execution time: 0.9 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 01-app-shell | 2/3 | 18 min | 9 min |
| 02-onboarding-and-keychain | 2/2 | 1 min | 1 min |
| 03-capture-engine-region-and-fullscreen | 3/3 | 21 min | 7 min |
| 04-window-capture-and-global-hotkeys | 3/3 | ~12 min | 4 min |
| 05-upload-pipeline | 3/3 | 7 min | 2 min |
| 06-exif-stripping-and-behavior-toggles | 1/1 | 3 min | 3 min |
| 07-upload-history | 3/3 | ~24 min | 8 min |

**Recent Trend:**
- Last 5 plans: 04-01 (5 min), 05-01 (est.), 05-02 (5 min), 05-03 (2 min), 06-01 (3 min)
- Trend: Stable

*Updated after each plan completion*
| Phase 05-upload-pipeline P03 | 2 | 1 tasks | 1 files |
| Phase 06-exif-stripping-and-behavior-toggles P01 | 3 | 2 tasks | 4 files |
| Phase 07-upload-history P01 | 21 | 2 tasks | 5 files |
| Phase 07-upload-history P02 | 2 | 2 tasks | 4 files |
| Phase 07-upload-history P03 | <1 | 1 task (verify) | 1 file |
| Phase 08-preferences-window P01 | 1 | 1 task | 4 files |
| Phase 08-preferences-window P02 | 11 | 2 tasks | 3 files |
| Phase 09 P02 | 2 | 2 tasks | 5 files |
| Phase 09-polish-and-distribution P01 | 3 | 2 tasks | 4 files |
| Phase 09-polish-and-distribution P03 | <1 | 1 task (human verify) | 0 files |

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
- ~~[Phase 03-03]: AppDelegate.lastCaptureResult: CaptureResult? stores last capture — ready for Phase 5 UploadService~~ (removed in Phase 05-03 — UploadService.failedCapture handles retention internally)
- [Phase 04-01]: nonisolated(unsafe) used for SCWindow transfer (non-Sendable ObjC type) across MainActor → CaptureEngine actor boundary
- [Phase 04-01]: SCWindow.frame extracted to Sendable CGRect before actor hop so it remains available on MainActor for CaptureFeedback positioning
- [Phase 04-01]: cachedWindows fetched once in beginWindowSelection() before overlay appears — avoids async latency in hover loop (research Pitfall 6)
- [Phase 04-01]: WindowSelectionOverlayView uses weak coordinator reference to avoid reference cycle
- [Phase 04-01]: .activeAlways tracking area used (not .activeInKeyWindow) since overlay is never key window during hover
- [Phase 04-02]: KeyboardShortcuts.Name extensions defined at file scope (not nested in type) — Swift 6 strict concurrency compliance
- [Phase 04-02]: onKeyUp used (not onKeyDown) — fires after user lifts key, preventing overlay from consuming the key-up event
- [Phase 04-02]: Sleep/wake re-registration via disable/enable only — re-calling onKeyUp would accumulate duplicate handlers silently (research Pitfall 2)
- [Phase 04-02]: fromHotkey: Bool = false parameter on capture methods — DRY single code path; hotkey path skips closePopover() and the 200ms popover-dismiss delay
- [Phase 04-02]: Shortcut conflict handling is silent — KeyboardShortcuts handles gracefully if another app holds the shortcut
- [Phase 04-03]: Keyboard shortcut hints (Cmd+Shift+X/S/C) added to CaptureSection buttons — discovered during human verification as a discoverability improvement
- [Phase 05-01]: UploadService is a Swift actor (not @MainActor) — runs on its own executor; all NSPasteboard and NSWorkspace calls wrapped in MainActor.run
- [Phase 05-01]: Serial FIFO queue via chained Task pattern: uploadTask = Task { await previousTask?.value; ... } — idiomatic Swift concurrency, no OperationQueue or locks
- [Phase 05-01]: pendingCount snapshot before async gap determines last-wins clipboard/browser semantics (capturedPendingCount == pendingCount after upload identifies last)
- [Phase 05-01]: 401 Unauthorized rethrows immediately in performWithRetry — never consumes a retry attempt
- [Phase 05-01]: Retry-After header parsed from 429 response; falls back to pow(2, attempt) if absent
- [Phase 05-01]: failedCapture and lastError are private(set) actor properties — Plan 02 reads them for Retry button and error banner
- [Phase 05-02]: showUploadSpinner uses CABasicAnimation(keyPath: transform.rotation.z) with repeatCount .infinity — smooth native animation without polling
- [Phase 05-02]: showErrorIcon does NOT auto-revert — error icon persists until AppDelegate explicitly clears it via restoreNormalIcon
- [Phase 05-02]: restoreNormalIcon changed from private to internal — Plan 03 AppDelegate integration requires direct call access
- [Phase 05-02]: wantsLayer=true on NSStatusItem.button required before adding CABasicAnimation — AppKit views have no backing layer by default
- [Phase 05-upload-pipeline]: rebuildPopoverContent() called every showPopover() — ensures popover always reflects current error state
- [Phase 05-upload-pipeline]: playCaptureSound() removed from capture paths — sound deferred to uploadSucceeded event only
- [Phase 05-upload-pipeline]: lastCaptureResult property removed — UploadService.failedCapture handles Retry retention internally
- [Phase 05-upload-pipeline]: Upload error icon acknowledged on popover open — restoreNormalIcon called when uploadError != nil
- [Phase 06-exif-stripping-and-behavior-toggles]: PreferencesStore uses ObservableObject (not @Observable macro) — @Observable incompatible with @AppStorage (converts stored properties to computed, blocking property wrapper composition)
- [Phase 06-exif-stripping-and-behavior-toggles]: Bool preference values passed as enqueue() parameters at capture time — no actor-crossing needed; PreferencesStore is @MainActor, UploadService is actor
- [Phase 06-exif-stripping-and-behavior-toggles]: pref_ prefix on all UserDefaults keys (pref_stripExif, pref_openInBrowser, pref_clipboardCopy) to avoid collision with KeyboardShortcuts library namespace
- [Phase 06-exif-stripping-and-behavior-toggles]: stripExif form field omitted entirely when false — API contract specifies only "true" value; absence = no stripping
- [Phase 06-exif-stripping-and-behavior-toggles]: retry() passes current preference values at retry time (not original capture-time values) — honours preference changes made between failure and retry
- [Phase 06-exif-stripping-and-behavior-toggles]: performUpload() Bool parameters renamed to shouldOpenInBrowser/shouldCopyToClipboard to avoid shadowing private openInBrowser(_:) method
- [Phase 07-upload-history]: HistoryEntry stores thumbnailPath as String (not URL) to avoid SwiftData URL encoding quirks
- [Phase 07-upload-history]: HistoryStore is ObservableObject (not @Observable) matching Phase 6 PreferencesStore pattern
- [Phase 07-upload-history]: CaptureResult threaded through UploadFeedbackEvent.uploadSucceeded to avoid AppDelegate stored-state race with concurrent queued uploads
- [Phase 07-upload-history]: DB record deleted before thumbnail file — orphaned file safer than dangling DB record (Pitfall 3)
- [Phase 07-upload-history]: Popover width widened from 280pt to 320pt to accommodate history list with thumbnails and action buttons
- [Phase 07-upload-history]: HistorySection List capped at 330pt maxHeight to prevent popover height explosion with many entries
- [Phase 07-upload-history]: RelativeDateTimeFormatter stored as struct property — expensive to init, not created inside body
- [Phase 07-upload-history]: TimelineView(.everyMinute) used in HistoryRowView for automatic relative timestamp refresh without polling
- [Phase 07-upload-history]: List replaced with ScrollView+LazyVStack in HistorySection — NSTableView (backing List) collapses to zero height when nested in VStack inside NSPopover; LazyVStack renders correctly
- [Phase 08-preferences-window]: PreferencesWindowController mirrors OnboardingWindowController pattern — NSWindow + activation policy .regular on open, .accessory on windowWillClose; isReleasedWhenClosed=false prevents deallocation; open() reuses existing window if isVisible
- [Phase 08-preferences-window]: KeyboardShortcuts.reset(.regionCapture, .fullscreenCapture, .windowCapture) for Reset to Defaults — resetAll() sets to nil, reset() restores to default: value on Name
- [Phase 08-preferences-window]: Duplicate shortcut detection only compares against others array (not self) in onChange — avoids false positive self-comparison; uses setShortcut(nil, for: name) to refuse conflict
- [Phase 08-preferences-window]: onOpenPreferences closure injection pattern follows existing capture closure pattern — consistent architecture across all popover actions
- [Phase 09]: Entitlements minimal (hardened-runtime only) with inline documentation of App Sandbox, TCC, and Keychain decisions
- [Phase 09]: ditto -c -k --keepParent for notarization zip (not zip -qr) and xcodebuild -exportArchive for signing (not codesign --deep)
- [Phase 09]: Temporary CI build.keychain with if:always() cleanup; notarize .app before wrapping in DMG (Apple-recommended order)
- [Phase 09-polish-and-distribution]: GENERATE_INFOPLIST_FILE=YES required in xcodegen bundle.unit-test target settings for code signing to succeed
- [Phase 09-polish-and-distribution]: Permission gate pattern: checkScreenRecordingPermission() check before capture in all three AppDelegate capture methods, with presentScreenRecordingDeniedAlert() modal on denial
- [Phase 09-polish-and-distribution P03]: All 7 Phase 9 verification items confirmed by user — error paths work, build infrastructure reviewed; full pipeline execution deferred until Developer ID certificate is configured

### Pending Todos

None.

### Quick Tasks Completed

| # | Description | Date | Commit | Directory |
|---|-------------|------|--------|-----------|
| 1 | Add config option: copy URL or copy image to clipboard (URL default) | 2026-03-01 | 0c0ae6b | [1-add-config-option-copy-url-or-copy-image](./quick/1-add-config-option-copy-url-or-copy-image/) |
| 2 | Move preferences from separate window into popover as inline navigation | 2026-03-01 | a2ac5cd | [2-move-preferences-from-separate-window-in](./quick/2-move-preferences-from-separate-window-in/) |

### Blockers/Concerns

- ~~**Phase 4**: CGEventTap and Accessibility permission prompting behavior changed in macOS 14/15 — validate before implementing HotkeyMonitor~~ (resolved — KeyboardShortcuts library handles Carbon event registration without CGEventTap)
- **Phase 5**: teil.ing REST API contract (exact multipart field names, rate limit headers, response schema) must be confirmed with project owner before implementing UploadService
- **Phase 9**: Apple Developer ID certificate and notarization workflow availability must be confirmed before Phase 9 starts

## Session Continuity

Last session: 2026-03-01
Stopped at: Completed quick task 2 — preferences moved inline into popover; PreferencesWindowController deleted
Resume file: None
