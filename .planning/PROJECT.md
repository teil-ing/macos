# teil.ing Client

## What This Is

A native macOS menu bar application for the teil.ing image sharing service. It lets users capture screenshots (full screen, window, or region selection using the native macOS screen capture experience), upload them to teil.ing, and instantly get a shareable URL. The app lives entirely in the menu bar with no dock icon — lightweight and always accessible.

## Core Value

Capture a screenshot and have a shareable teil.ing URL on the clipboard in seconds — zero friction from capture to share.

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] Menu bar-only app (no dock icon, lives in system menu bar)
- [ ] Global configurable keyboard shortcuts for each capture mode
- [ ] Region selection capture (native macOS screencapture-style crosshair overlay)
- [ ] Full screen capture
- [ ] Window capture (click to select a window)
- [ ] Upload captured image to teil.ing via `POST /api/v1/upload`
- [ ] Authenticate with API key via `X-API-Key` header
- [ ] First-launch setup flow prompting for API key, stored in macOS Keychain
- [ ] After upload: copy `shareUrl` to clipboard automatically
- [ ] After upload: open `shareUrl` in default browser
- [ ] Upload history in menu bar dropdown with thumbnails
- [ ] EXIF stripping toggle in preferences (sends `stripExif=true` when enabled)
- [ ] Preferences window for API key, hotkeys, and EXIF toggle
- [ ] macOS notification for upload success/failure

### Out of Scope

- Image editing/annotation before upload — not v1, keep it simple
- Image management (delete, update settings) from the client — use the web dashboard
- Video/screen recording capture — image-only
- iOS/iPadOS companion — macOS only
- Drag-and-drop file upload — capture-only workflow
- Auto-update mechanism — manual updates for v1

## Context

- **teil.ing API**: REST API at `https://teil.ing/api/v1/` with API key auth (`X-API-Key` header)
- **Upload endpoint**: `POST /api/v1/upload` with multipart form data, returns `shareUrl`, `imageUrl`, `thumbnailUrl`
- **Image listing**: `GET /api/v1/images` for upload history with pagination
- **API key format**: `teil_` prefix + 48 random chars, created in web dashboard
- **Rate limits**: 120 requests/60s general, 60 uploads/hour
- **Supported formats**: JPEG, PNG, GIF, WebP, SVG, BMP, TIFF, AVIF, HEIC, HEIF
- **macOS screencapture**: Can leverage `screencapture` CLI tool or `ScreenCaptureKit` framework for native capture behavior

## Constraints

- **Platform**: macOS only, Swift/SwiftUI, target macOS 13+ (Ventura) for ScreenCaptureKit support
- **Architecture**: Menu bar app using `NSStatusItem`, `LSUIElement` set to hide dock icon
- **Security**: API key stored in macOS Keychain, never in plain text/UserDefaults
- **Privacy**: Requires Screen Recording permission from macOS (System Settings > Privacy & Security)

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Menu bar-only app | Lightweight, always accessible, no dock clutter | — Pending |
| macOS Keychain for API key | Secure credential storage, standard macOS practice | — Pending |
| Native screencapture behavior | Users expect the familiar macOS capture UX | — Pending |
| SwiftUI for UI, AppKit for system integration | SwiftUI for modern UI, AppKit where needed (NSStatusItem, global hotkeys) | — Pending |

---
*Last updated: 2026-02-17 after initialization*
