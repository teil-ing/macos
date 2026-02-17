# Requirements: teil.ing macOS Client

**Defined:** 2026-02-17
**Core Value:** Capture a screenshot and have a shareable teil.ing URL on the clipboard in seconds — zero friction from capture to share.

## v1 Requirements

Requirements for initial release. Each maps to roadmap phases.

### Capture

- [ ] **CAPT-01**: User can capture a selected region of the screen using a crosshair overlay (drag to select)
- [ ] **CAPT-02**: User can capture the entire screen (fullscreen mode)
- [ ] **CAPT-03**: User can capture a specific window by clicking on it
- [ ] **CAPT-04**: User can trigger each capture mode via configurable global keyboard shortcuts
- [ ] **CAPT-05**: Capture works across multiple monitors (region and fullscreen)

### Upload

- [ ] **UPLD-01**: Captured image is automatically uploaded to teil.ing via POST /api/v1/upload
- [ ] **UPLD-02**: Upload authenticates using X-API-Key header with user's stored API key
- [ ] **UPLD-03**: Share URL is copied to clipboard automatically after successful upload
- [ ] **UPLD-04**: Share URL is opened in default browser after successful upload
- [ ] **UPLD-05**: User can toggle EXIF metadata stripping in preferences (sends stripExif=true)
- [ ] **UPLD-06**: Upload errors are surfaced to the user (notification or menu bar indicator)

### App Shell

- [ ] **SHELL-01**: App runs as a menu bar-only application (no Dock icon, LSUIElement)
- [ ] **SHELL-02**: Menu bar dropdown shows upload history with thumbnails, timestamps, and copy-URL action
- [ ] **SHELL-03**: Menu bar icon adapts to system appearance (dark/light mode)
- [ ] **SHELL-04**: Upload history persists across app launches

### Onboarding

- [ ] **ONBD-01**: First launch prompts user to enter their teil.ing API key
- [ ] **ONBD-02**: API key is stored securely in macOS Keychain (never UserDefaults)
- [ ] **ONBD-03**: App requests Screen Recording permission with clear explanation
- [ ] **ONBD-04**: App validates API key before saving (test connection)

### Preferences

- [ ] **PREF-01**: User can view and update their API key in preferences
- [ ] **PREF-02**: User can configure keyboard shortcuts for each capture mode
- [ ] **PREF-03**: User can toggle EXIF stripping on/off
- [ ] **PREF-04**: User can toggle open-in-browser behavior on/off

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Notifications

- **NOTF-01**: User receives macOS notification on upload success with share URL
- **NOTF-02**: User receives macOS notification on upload failure with error details

### Capture Enhancements

- **CENH-01**: User can set a delay timer (3s/5s) before capture triggers
- **CENH-02**: User sees a thumbnail preview after capture (3s dismissible corner widget)
- **CENH-03**: User can capture without uploading (copy to clipboard only, offline mode)

### History Enhancements

- **HENH-01**: User can delete an upload from teil.ing directly from history
- **HENH-02**: User can search upload history by filename or date

### Upload Enhancements

- **UENH-01**: Upload progress indicator visible in menu bar during upload

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Image annotation/markup before upload | High complexity (3-6 months scope), CleanShot X does this better |
| Video/screen recording | Completely different capture pipeline, teil.ing is an image service |
| GIF recording | High complexity, large file sizes, tangential to image upload |
| Scrolling/long-page capture | Complex stitching logic, not core to the sharing workflow |
| iOS/iPadOS companion | macOS only for v1, cross-platform scope multiplication |
| Drag-and-drop file upload | Capture-only workflow per project vision |
| Auto-update mechanism | Manual updates for v1 |
| Image management from client (delete, settings) | Use the web dashboard at teil.ing |
| Mac App Store distribution | App Sandbox conflicts with ScreenCaptureKit usage patterns |
| OCR/text extraction | Not part of the core sharing workflow |
| Multi-account support | Single API key per installation for v1 |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| CAPT-01 | Phase 3 | Pending |
| CAPT-02 | Phase 3 | Pending |
| CAPT-03 | Phase 4 | Pending |
| CAPT-04 | Phase 4 | Pending |
| CAPT-05 | Phase 3 | Pending |
| UPLD-01 | Phase 5 | Pending |
| UPLD-02 | Phase 5 | Pending |
| UPLD-03 | Phase 5 | Pending |
| UPLD-04 | Phase 5 | Pending |
| UPLD-05 | Phase 6 | Pending |
| UPLD-06 | Phase 5 | Pending |
| SHELL-01 | Phase 1 | Pending |
| SHELL-02 | Phase 7 | Pending |
| SHELL-03 | Phase 1 | Pending |
| SHELL-04 | Phase 7 | Pending |
| ONBD-01 | Phase 2 | Pending |
| ONBD-02 | Phase 2 | Pending |
| ONBD-03 | Phase 2 | Pending |
| ONBD-04 | Phase 2 | Pending |
| PREF-01 | Phase 8 | Pending |
| PREF-02 | Phase 8 | Pending |
| PREF-03 | Phase 6 | Pending |
| PREF-04 | Phase 6 | Pending |

**Coverage:**
- v1 requirements: 23 total
- Mapped to phases: 23
- Unmapped: 0 ✓

---
*Requirements defined: 2026-02-17*
*Last updated: 2026-02-17 after roadmap creation*
