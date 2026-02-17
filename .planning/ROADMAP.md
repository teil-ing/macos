# Roadmap: teil.ing macOS Client

## Overview

The teil.ing macOS client is built in nine phases following the component dependency graph: the app shell and menu bar infrastructure come first (everything runs inside it), onboarding and Keychain second (auth is a prerequisite for upload), then the capture engine in two phases (region/fullscreen before window/hotkeys), then the upload pipeline, EXIF and behavior preferences, upload history, the full preferences window, and finally hardening and distribution. Each phase delivers a coherent, independently verifiable slice of the product. The critical pitfalls identified in research (NSStatusItem retention, Keychain entitlements, CGEventTap threading, CMSampleBuffer leaks) are front-loaded into the first two phases where they are cheapest to address.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: App Shell** - Menu bar-only application skeleton with adaptive icon, no Dock presence, Xcode project and entitlements configured (completed 2026-02-17)
- [x] **Phase 2: Onboarding and Keychain** - First-launch API key entry flow, secure Keychain storage, Screen Recording permission request (completed 2026-02-17)
- [x] **Phase 3: Capture Engine — Region and Fullscreen** - Region crosshair selection and fullscreen capture using ScreenCaptureKit, multi-monitor aware (completed 2026-02-17)
- [ ] **Phase 4: Window Capture and Global Hotkeys** - Click-to-select window capture mode and configurable global keyboard shortcuts for all three capture modes
- [ ] **Phase 5: Upload Pipeline** - Automatic upload on capture, API key auth, clipboard copy, open-in-browser, upload error surfacing
- [ ] **Phase 6: EXIF Stripping and Behavior Toggles** - EXIF metadata stripping preference and open-in-browser toggle wired into upload
- [ ] **Phase 7: Upload History** - Persistent upload history in menu bar dropdown with thumbnails, timestamps, and copy-URL action
- [ ] **Phase 8: Preferences Window** - Full preferences UI for API key management, keyboard shortcut configuration, EXIF toggle, and browser toggle
- [ ] **Phase 9: Polish and Distribution** - Error path hardening, multi-monitor edge case validation, notarized DMG build and release pipeline

## Phase Details

### Phase 1: App Shell
**Goal**: A working macOS menu bar application skeleton exists — no Dock icon, adaptive menu bar icon, correct entitlements, and no critical architectural pitfalls baked in from the start.
**Depends on**: Nothing (first phase)
**Requirements**: SHELL-01, SHELL-03
**Success Criteria** (what must be TRUE):
  1. App launches and a menu bar icon appears; no Dock icon is visible at any point during app lifetime
  2. Menu bar icon renders correctly in both macOS light mode and dark mode without any tint artifacts
  3. Clicking the menu bar icon opens a popover or menu without causing a Dock icon to flash or appear
  4. App continues to display its menu bar icon after a Release build is archived and run (not just Debug)
  5. Xcode project builds with required entitlements (Screen Recording, Keychain Sharing, Hardened Runtime) without code signing errors
**Plans**: 2 plans

Plans:
- [ ] 01-01-PLAN.md — Xcode project setup + AppDelegate with NSStatusItem, NSPopover, event monitor, and adaptive SF Symbol icon
- [ ] 01-02-PLAN.md — SwiftUI popover content views (Capture, History, Footer sections) and visual verification

### Phase 2: Onboarding and Keychain
**Goal**: A first-launch user can enter their teil.ing API key, have it stored securely in the macOS Keychain, and grant Screen Recording permission with a clear explanation — the app is fully authorized before any capture or upload is attempted.
**Depends on**: Phase 1
**Requirements**: ONBD-01, ONBD-02, ONBD-03, ONBD-04
**Success Criteria** (what must be TRUE):
  1. On first launch the app presents an onboarding prompt asking for the API key before showing any other UI
  2. After entering an API key, the app tests the connection to teil.ing and only saves the key if the test succeeds (invalid key shows an error)
  3. The API key is retrievable from Keychain on subsequent launches (app does not re-prompt on second launch)
  4. The API key is never written to UserDefaults, plist, or any unencrypted storage — confirmed via Keychain viewer
  5. The onboarding flow requests Screen Recording permission with an explanation of why it is needed before any capture attempt
**Plans**: 2 plans

Plans:
- [ ] 02-01-PLAN.md — KeychainService, APIValidationService, and PermissionService (foundation services)
- [ ] 02-02-PLAN.md — Onboarding window UI, ViewModel, and AppDelegate integration with human verification

### Phase 3: Capture Engine — Region and Fullscreen
**Goal**: A user can trigger region selection capture (crosshair overlay drag-to-select) and fullscreen capture from the menu bar, and receive a correct CGImage in memory — on both macOS 13 and macOS 14+, across all connected monitors.
**Depends on**: Phase 2
**Requirements**: CAPT-01, CAPT-02, CAPT-05
**Success Criteria** (what must be TRUE):
  1. User can invoke region capture and drag a selection on any connected display; a CGImage matching the selected area is produced
  2. User can invoke fullscreen capture and a CGImage of the entire display content is produced (all active monitors supported)
  3. Capture works correctly on macOS 13 (Ventura) using the SCStream fallback path and on macOS 14+ using SCScreenshotManager
  4. The region selection overlay covers each monitor at the correct screen coordinates with no gaps or overlaps between displays
  5. No memory leak occurs during or after capture — CMSampleBuffer is released inside the delegate callback before any async Task is spawned
**Plans**: 3 plans

Plans:
- [ ] 03-01-PLAN.md — CaptureEngine actor + SCScreenshotManager (macOS 14+) + StreamCaptureBridge (macOS 13) + CrossMonitorStitcher
- [ ] 03-02-PLAN.md — Interactive selection overlay (dimming, crosshair guidelines, marching ants, dimension label, multi-monitor)
- [ ] 03-03-PLAN.md — Menu bar wiring, capture feedback (flash, sound, icon), and human verification

### Phase 4: Window Capture and Global Hotkeys
**Goal**: A user can click to select a specific open window for capture, and can trigger any capture mode from anywhere on the system using configurable keyboard shortcuts without touching the menu bar.
**Depends on**: Phase 3
**Requirements**: CAPT-03, CAPT-04
**Success Criteria** (what must be TRUE):
  1. User can invoke window capture from the menu bar; the cursor changes to indicate selection mode and clicking a visible window captures only that window
  2. After capture the overlay dismisses immediately without focus artifacts or visible window flash
  3. User can assign keyboard shortcuts to region, fullscreen, and window capture modes in preferences; the shortcuts trigger the correct capture mode from any application
  4. Keyboard shortcuts are registered on the main thread and survive sleep/wake cycles without needing an app relaunch
  5. The app does not appear in the Dock or steal focus when a hotkey fires
**Plans**: 3 plans

Plans:
- [ ] 04-01-PLAN.md — Window capture mode: CaptureEngine.captureWindow, WindowSelectionCoordinator, WindowSelectionOverlayView with dimming overlay and camera cursor, wired into menu bar UI
- [ ] 04-02-PLAN.md — HotkeyMonitor: KeyboardShortcuts library integration with Name extensions (Cmd+Shift+X/S/C defaults), onKeyUp registration, sleep/wake re-registration, wired into AppDelegate.completeLaunch
- [ ] 04-03-PLAN.md — Human verification of complete window capture and global hotkeys end-to-end

### Phase 5: Upload Pipeline
**Goal**: A captured image is automatically uploaded to teil.ing, the share URL is copied to the clipboard, the browser opens to the share URL, and any upload error is surfaced to the user — all without manual intervention.
**Depends on**: Phase 4
**Requirements**: UPLD-01, UPLD-02, UPLD-03, UPLD-04, UPLD-06
**Success Criteria** (what must be TRUE):
  1. After any successful capture the image is automatically uploaded to teil.ing with no additional user action required
  2. The X-API-Key header is sent with every upload request using the key stored in Keychain; the upload is rejected (not silently dropped) if no key is stored
  3. After a successful upload the share URL is on the clipboard within one second of the upload response arriving
  4. After a successful upload the share URL opens in the default browser (subject to user preference, wired in Phase 6)
  5. If upload fails (network error, rate limit, API error) the user sees a visible error — menu bar indicator or notification — not a silent failure
**Plans**: TBD

Plans:
- [ ] 05-01: UploadService — protocol-backed; URLSession multipart/form-data POST to /api/v1/upload; X-API-Key header from KeychainClient; response decoding (shareUrl, imageUrl, thumbnailUrl)
- [ ] 05-02: Multipart body construction — correct Content-Type boundary header; file field name and filename; MIME type detection from CGImage format
- [ ] 05-03: Error handling and retry — HTTP error codes mapped to user-visible messages; 429 rate limit detection with Retry-After header; exponential backoff (max 3 attempts)
- [ ] 05-04: ResultDispatcher — clipboard write (NSPasteboard) after confirmed upload success (not before); open-in-browser via NSWorkspace.open (controlled by preference flag, Phase 6)
- [ ] 05-05: Upload error surfacing — menu bar icon state change during upload and on failure; error message accessible from menu; UNUserNotification for failure (notification permission requested during onboarding)

### Phase 6: EXIF Stripping and Behavior Toggles
**Goal**: A user can enable EXIF stripping so uploaded images have metadata removed, and can control whether the browser opens after upload — both preferences are applied to every subsequent upload automatically.
**Depends on**: Phase 5
**Requirements**: UPLD-05, PREF-03, PREF-04
**Success Criteria** (what must be TRUE):
  1. When EXIF stripping is enabled in preferences, the stripExif=true form field is included in the upload request; when disabled the field is omitted
  2. A user can toggle EXIF stripping on or off; the change takes effect on the next capture without restarting the app
  3. When the open-in-browser preference is off, uploading does not open any browser window; when on, the browser opens automatically
  4. Both preference values persist across app relaunches
**Plans**: TBD

Plans:
- [ ] 06-01: PreferencesStore — @AppStorage-backed (or UserDefaults) store for EXIF toggle and open-in-browser toggle; observed by UploadService and ResultDispatcher
- [ ] 06-02: EXIF stripping via ImageIO — CGImageDestinationCopyImageSource with kCGImageDestinationMetadata exclusion or CoreImage approach; applied to CGImage before upload when toggle is enabled
- [ ] 06-03: Wire toggles into pipeline — UploadService reads stripExif from PreferencesStore at call time; ResultDispatcher reads openInBrowser flag before NSWorkspace.open call

### Phase 7: Upload History
**Goal**: A user can open the menu bar dropdown and see their recent uploads with thumbnails, timestamps, and a one-click copy-URL action — and this history is still there after restarting the app.
**Depends on**: Phase 6
**Requirements**: SHELL-02, SHELL-04
**Success Criteria** (what must be TRUE):
  1. After each successful upload a new entry appears at the top of the menu bar dropdown containing a thumbnail, the upload timestamp, and a copy-URL button
  2. Clicking the copy-URL action for a history entry copies that entry's share URL to the clipboard
  3. The history list persists across app restarts — entries from a previous session are visible after relaunching the app
  4. History thumbnails are stored as files in Application Support (not in UserDefaults); the history list is capped at 50 entries with oldest entries evicted
**Plans**: TBD

Plans:
- [ ] 07-01: HistoryStore — @Published list of UploadRecord (id, shareUrl, thumbnailUrl, imageUrl, timestamp); macOS 14+ SwiftData backend; macOS 13 Codable+JSON fallback; thumbnail files in ~/Library/Application Support/teilingClient/thumbnails/
- [ ] 07-02: Thumbnail generation — CGImage → resized thumbnail using ImageIO; saved to disk at upload time; loaded lazily for display
- [ ] 07-03: HistoryView — SwiftUI List with thumbnail Image, relative timestamp (DateComponentsFormatter), copy-URL Button; integrated into menu bar popover
- [ ] 07-04: LRU eviction — HistoryStore enforces 50-item max; oldest entry file removed from disk when limit exceeded

### Phase 8: Preferences Window
**Goal**: A user can open a preferences window from the menu bar and manage their API key, reconfigure keyboard shortcuts, and toggle EXIF stripping and open-in-browser behavior — without the Dock icon appearing.
**Depends on**: Phase 7
**Requirements**: PREF-01, PREF-02, PREF-03, PREF-04
**Success Criteria** (what must be TRUE):
  1. User can open a preferences window from the menu bar item; the Dock icon does not appear when the preferences window is open or closed
  2. User can view their current API key (masked) in preferences and replace it with a new key; the new key is validated before saving to Keychain
  3. User can see the current keyboard shortcut for each capture mode and record a new shortcut using the KeyboardShortcuts.Recorder UI
  4. EXIF stripping toggle and open-in-browser toggle are present in preferences and reflect the current preference state
  5. Changes to keyboard shortcuts take effect immediately without restarting the app
**Plans**: TBD

Plans:
- [ ] 08-01: Preferences window scaffold — NSPanel (not SwiftUI Settings scene) to avoid Dock icon reappearance; .accessory activation policy restoration on close; opened from menu bar action
- [ ] 08-02: API key settings section — masked text field showing last 8 chars; replace-key flow reuses onboarding validation; delete-key option with confirmation
- [ ] 08-03: Keyboard shortcuts section — KeyboardShortcuts.Recorder for each of the three capture modes; bound to HotkeyMonitor registered shortcuts
- [ ] 08-04: EXIF and browser toggle section — Toggle views bound to PreferencesStore @AppStorage values; persisted automatically

### Phase 9: Polish and Distribution
**Goal**: All error paths are surfaced gracefully, multi-monitor edge cases are verified, the app is code-signed, notarized, and packaged as a DMG ready for direct download distribution.
**Depends on**: Phase 8
**Requirements**: (none — hardening and distribution work; all v1 requirements already covered)
**Success Criteria** (what must be TRUE):
  1. Every error path (denied Screen Recording permission, missing API key, network failure, rate limit) shows the user a specific, actionable message rather than a silent failure
  2. Region capture and fullscreen capture behave correctly when two or more external monitors are connected with different resolutions or arrangements
  3. The app passes macOS notarization (no staple errors, no Gatekeeper quarantine warning on first open)
  4. A user on a clean macOS 13 Ventura machine and a clean macOS 14 Sonoma machine can install from the DMG and reach a working capture-and-upload flow
**Plans**: TBD

Plans:
- [ ] 09-01: Error path audit — walk every error state (permission denied, Keychain failure, upload failure, rate limit, missing key on launch); ensure each has visible UI feedback
- [ ] 09-02: Multi-monitor validation — test region capture spanning two displays; test fullscreen capture on secondary display; verify overlay window per-monitor placement
- [ ] 09-03: Release build validation — Archive build test on macOS 13 VM and macOS 14 device; Keychain behavior, NSStatusItem retention, hotkey registration all confirmed in Release configuration
- [ ] 09-04: Code signing and entitlements — Developer ID Application certificate; Hardened Runtime with required exceptions; entitlements file audit (Screen Recording, Keychain Sharing, no unnecessary sandbox)
- [ ] 09-05: Notarization and DMG packaging — codesign --deep; notarytool submit; staple; create DMG with background and Applications symlink; verify Gatekeeper acceptance

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4 → 5 → 6 → 7 → 8 → 9

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. App Shell | 2/2 | Complete    | 2026-02-17 |
| 2. Onboarding and Keychain | 0/2 | Complete    | 2026-02-17 |
| 3. Capture Engine — Region and Fullscreen | 0/3 | Complete    | 2026-02-17 |
| 4. Window Capture and Global Hotkeys | 0/3 | Not started | - |
| 5. Upload Pipeline | 0/5 | Not started | - |
| 6. EXIF Stripping and Behavior Toggles | 0/3 | Not started | - |
| 7. Upload History | 0/4 | Not started | - |
| 8. Preferences Window | 0/4 | Not started | - |
| 9. Polish and Distribution | 0/5 | Not started | - |
