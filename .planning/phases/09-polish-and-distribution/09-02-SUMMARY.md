---
phase: 09-polish-and-distribution
plan: 02
subsystem: distribution-pipeline
tags: [build, distribution, notarization, github-actions, dmg, entitlements]
dependency_graph:
  requires: []
  provides:
    - ExportOptions.plist for xcodebuild -exportArchive Developer ID distribution
    - build-dmg.sh single-command build pipeline
    - Resources/dmg-background.png branded DMG installer background
    - .github/workflows/release.yml automated CI release on v* tag push
    - Audited entitlements file documenting all decisions
  affects:
    - distribution workflow
    - CI/CD pipeline
tech_stack:
  added:
    - create-dmg (brew) for branded DMG creation
    - xcrun notarytool for Apple notarization
    - gh CLI for GitHub Release creation
    - GitHub Actions (macos-15 runner)
  patterns:
    - Archive → exportArchive → notarize (not codesign --deep)
    - ditto for notarization zip (not zip -qr)
    - Temporary CI keychain pattern with always() cleanup
    - notarytool store-credentials for credential management
key_files:
  created:
    - ExportOptions.plist
    - build-dmg.sh
    - Resources/dmg-background.png
    - .github/workflows/release.yml
  modified:
    - teil.ing-client/App/teil_ing_client.entitlements
decisions:
  - Entitlements kept minimal (hardened-runtime only) — App Sandbox disabled in project.yml, Screen Recording is TCC not entitlement, Keychain works without keychain-access-groups for non-sandboxed apps
  - signingStyle=automatic in ExportOptions.plist — lets Xcode resolve Developer ID certificate without hardcoding identity
  - ditto -c -k --keepParent for notarization zip — preserves symlinks and metadata; zip -qr is known anti-pattern
  - xcodebuild -exportArchive for signing — handles nested bundle signing correctly; codesign --deep is for verification only
  - Notarize .app then staple before wrapping in DMG — correct order per Apple documentation
  - Temporary build.keychain in CI with if:always() cleanup — prevents certificate leakage between runs
metrics:
  duration_minutes: 2
  completed_date: "2026-02-18"
  tasks_completed: 2
  files_changed: 5
---

# Phase 9 Plan 02: Distribution Pipeline Summary

One-liner: Signed notarized DMG distribution pipeline with 8-step build-dmg.sh, GitHub Actions CI on v* tags, branded 540x380 background, and audited Hardened Runtime entitlements.

## What Was Built

Complete macOS distribution pipeline enabling:
- `./build-dmg.sh 1.0.0` for local one-command builds
- Automated CI releases triggered by pushing a `v*` tag to GitHub

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Entitlements audit, ExportOptions.plist, DMG background | fff6b5d | teil.ing-client/App/teil_ing_client.entitlements, ExportOptions.plist, Resources/dmg-background.png |
| 2 | build-dmg.sh and GitHub Actions release.yml | 02f3185 | build-dmg.sh, .github/workflows/release.yml |

## Key Files

**`ExportOptions.plist`** — Configures `xcodebuild -exportArchive` for Developer ID distribution with automatic signing using teamID 5A7M476YY2.

**`build-dmg.sh`** — 8-step pipeline:
1. Archive with xcodebuild
2. Export signed .app with xcodebuild -exportArchive
3. Verify code signature (codesign --verify --deep --strict)
4. Notarize with xcrun notarytool submit --wait (using ditto zip)
5. Staple notarization ticket
6. Verify Gatekeeper acceptance (spctl -a -vvv)
7. Create branded DMG with create-dmg
8. Create GitHub Release with gh CLI

**`Resources/dmg-background.png`** — 540x380px dark (#1a1a2e) branded background with "teil.ing" title, installation arrow, and instruction text.

**`.github/workflows/release.yml`** — GitHub Actions workflow: imports Developer ID certificate into temporary keychain, stores notarytool credentials, runs `./build-dmg.sh`, cleans up keychain in `if: always()` step. Requires 6 GitHub Secrets.

## Required GitHub Secrets

| Secret | Source |
|--------|--------|
| `DEVELOPER_ID_CERTIFICATE_BASE64` | Base64-encoded Developer ID Application .p12 from Keychain Access export |
| `DEVELOPER_ID_CERTIFICATE_PASSWORD` | Password used when exporting the .p12 |
| `CI_KEYCHAIN_PASSWORD` | Any strong random password (CI keychain only) |
| `NOTARIZATION_APPLE_ID` | Apple ID email for developer account |
| `NOTARIZATION_TEAM_ID` | 10-character Team ID (Apple Developer portal) |
| `NOTARIZATION_APP_PASSWORD` | App-specific password from appleid.apple.com |

## Decisions Made

- **Entitlements minimal**: Only `com.apple.security.hardened-runtime: true` retained. App Sandbox is disabled in project.yml. Screen Recording is a TCC runtime permission (not an entitlement). Keychain access works without `keychain-access-groups` for non-sandboxed apps. Added inline XML comments documenting each decision including contingency for `errSecMissingEntitlement (-34018)`.
- **signingStyle=automatic**: Lets Xcode resolve Developer ID certificate automatically; avoids hardcoding certificate identity string.
- **ditto not zip**: `ditto -c -k --keepParent` preserves symlinks and extended attributes; `zip -qr` is a known anti-pattern that can cause notarization failures.
- **exportArchive not codesign --deep**: `xcodebuild -exportArchive` handles nested bundle signing (frameworks, helpers) correctly. `codesign --deep` is used only for post-export verification.
- **Notarize .app before DMG**: Staple the notarization ticket to the .app first, then wrap in DMG. This is the correct Apple-recommended order.
- **Temporary CI keychain with always() cleanup**: Creates `build.keychain` at job start, uses it throughout, deletes it in `if: always()` step to prevent credential leakage between runs.

## Deviations from Plan

None - plan executed exactly as written.

## Self-Check: PASSED

All files exist at expected paths. Both task commits verified in git history.
