import AppKit
import KeyboardShortcuts
import SwiftUI

// MARK: - PreferencesView

/// Single-pane preferences view with three sections: Account, Shortcuts, Upload Settings.
/// Hosted inline inside the popover when the user taps the gear icon.
struct PreferencesView: View {

    @ObservedObject private var prefs = PreferencesStore.shared

    /// Called when the user taps the back button. Optional so the view can be previewed standalone.
    var onBack: (() -> Void)?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // MARK: Header with back navigation
                HStack {
                    Button {
                        onBack?()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)

                    Spacer()

                    Text("Preferences")
                        .font(.headline)

                    Spacer()

                    // Invisible spacer to balance the back button and keep title centered
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .hidden()
                }
                .padding(.bottom, 12)

                AccountSection()
                Divider().padding(.vertical, 8)
                GeneralSection(prefs: prefs)
                Divider().padding(.vertical, 8)
                ShortcutsSection()
                Divider().padding(.vertical, 8)
                UploadSettingsSection(prefs: prefs)
            }
            .padding(16)
        }
        .frame(width: 320)
    }
}

// MARK: - SectionHeader

/// Reusable section header with headline typography.
private struct SectionHeader: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.headline)
            .padding(.bottom, 6)
    }
}

// MARK: - GeneralSection

/// General app settings including launch-at-login toggle.
private struct GeneralSection: View {

    @ObservedObject var prefs: PreferencesStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("General")

            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Launch at Login")
                        .font(.body)
                    Text("Automatically start teil.ing when you log in to your Mac")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("", isOn: $prefs.launchAtLogin)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .onChange(of: prefs.launchAtLogin) { _, newValue in
                        LaunchAtLoginService.shared.setEnabled(newValue)
                    }
            }
        }
    }
}

// MARK: - AccountSection

/// Displays the stored API key masked (last 8 chars visible), with inline replace
/// and delete-with-confirmation flows.
private struct AccountSection: View {

    @State private var currentKey: String?
    @State private var isEditing: Bool = false
    @State private var newKeyInput: String = ""
    @State private var isValidating: Bool = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Account")

            if let key = currentKey, !isEditing {
                // Display mode: show masked key with Change and Delete buttons
                HStack(spacing: 12) {
                    Text(maskedKey(key))
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.primary)

                    Button("Change") {
                        newKeyInput = ""
                        errorMessage = nil
                        isEditing = true
                    }

                    Button("Delete") {
                        confirmDeleteAPIKey()
                    }
                }
            } else if isEditing || currentKey == nil {
                // Edit mode: text field for new key entry
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        TextField("Enter API key", text: $newKeyInput)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: .infinity)

                        if isValidating {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Button("Save") {
                                Task { await saveKey() }
                            }
                            .disabled(newKeyInput.trimmingCharacters(in: .whitespaces).isEmpty)
                        }

                        if isEditing, currentKey != nil {
                            Button("Cancel") {
                                newKeyInput = ""
                                errorMessage = nil
                                isEditing = false
                            }
                        }
                    }

                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
        }
        .onAppear {
            currentKey = KeychainService.shared.apiKey
        }
    }

    // MARK: - Private Helpers

    private func maskedKey(_ key: String) -> String {
        let visibleCount = 8
        guard key.count > visibleCount else {
            return String(repeating: "\u{2022}", count: key.count)
        }
        let bulletCount = key.count - visibleCount
        return String(repeating: "\u{2022}", count: bulletCount) + key.suffix(visibleCount)
    }

    @MainActor
    private func saveKey() async {
        let trimmed = newKeyInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        isValidating = true
        errorMessage = nil

        let result = await APIValidationService.validate(apiKey: trimmed)

        isValidating = false

        switch result {
        case .valid:
            do {
                try KeychainService.shared.save(trimmed)
                currentKey = trimmed
                newKeyInput = ""
                errorMessage = nil
                isEditing = false
            } catch {
                errorMessage = "Failed to save API key. Please try again."
            }
        case .invalidKey:
            errorMessage = "Invalid API key. Please check and try again."
        case .networkError(let message):
            errorMessage = message
        case .serverError(let code):
            errorMessage = "Server error (\(code)). Please try again later."
        }
    }

    @MainActor
    private func confirmDeleteAPIKey() {
        let alert = NSAlert()
        alert.messageText = "Delete API Key?"
        alert.informativeText = "You will need to enter a new API key to use teil.ing."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")

        guard alert.runModal() == .alertFirstButtonReturn else { return }

        KeychainService.shared.delete()
        // Stay in preferences with empty key field — per locked decision
        currentKey = nil
        newKeyInput = ""
        errorMessage = nil
        isEditing = true
    }
}

// MARK: - ShortcutsSection

/// Three keyboard shortcut recorders with duplicate detection and reset-to-defaults button.
private struct ShortcutsSection: View {

    @State private var duplicateWarning: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Shortcuts")

            ShortcutRow(
                label: "Region Capture",
                name: .regionCapture,
                defaultHint: "Default: Cmd+Shift+X",
                others: [.fullscreenCapture, .windowCapture],
                duplicateWarning: $duplicateWarning
            )
            ShortcutRow(
                label: "Fullscreen Capture",
                name: .fullscreenCapture,
                defaultHint: "Default: Cmd+Shift+S",
                others: [.regionCapture, .windowCapture],
                duplicateWarning: $duplicateWarning
            )
            ShortcutRow(
                label: "Window Capture",
                name: .windowCapture,
                defaultHint: "Default: Cmd+Shift+C",
                others: [.regionCapture, .fullscreenCapture],
                duplicateWarning: $duplicateWarning
            )

            if let warning = duplicateWarning {
                Text(warning)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Button("Reset to Defaults") {
                // reset() restores to the `default:` value set on KeyboardShortcuts.Name
                // NOT resetAll() which sets to nil
                KeyboardShortcuts.reset(.regionCapture, .fullscreenCapture, .windowCapture)
                duplicateWarning = nil
            }
            .controlSize(.small)
        }
    }
}

// MARK: - ShortcutRow

/// A single row with a label, KeyboardShortcuts.Recorder, and a default hint subtitle.
private struct ShortcutRow: View {
    let label: String
    let name: KeyboardShortcuts.Name
    let defaultHint: String
    let others: [KeyboardShortcuts.Name]
    @Binding var duplicateWarning: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label)
                    // Narrowed from 150 to 110 so label + recorder fit within 320pt popover width
                    .frame(width: 110, alignment: .leading)
                KeyboardShortcuts.Recorder(for: name) { newShortcut in
                    guard let newShortcut else {
                        // Shortcut was cleared — no conflict possible
                        duplicateWarning = nil
                        return
                    }
                    // Check if any OTHER name already holds this shortcut
                    for other in others {
                        if KeyboardShortcuts.getShortcut(for: other) == newShortcut {
                            // Conflict — clear the newly set shortcut and warn
                            KeyboardShortcuts.setShortcut(nil, for: name)
                            duplicateWarning = "\(label) shortcut conflicts with another capture mode."
                            return
                        }
                    }
                    duplicateWarning = nil
                }
            }
            Text(defaultHint)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - UploadSettingsSection

/// Three toggles bound to PreferencesStore for upload behavior preferences.
struct UploadSettingsSection: View {

    @ObservedObject var prefs: PreferencesStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Upload Settings")

            ToggleRow(
                label: "Strip EXIF Metadata",
                description: "Remove location and camera info from uploaded images.",
                isOn: $prefs.stripExif
            )
            ToggleRow(
                label: "Open in Browser",
                description: "Automatically open the share URL after each upload.",
                isOn: $prefs.openInBrowser
            )
            ToggleRow(
                label: "Copy to Clipboard",
                description: "Copy the share URL to the clipboard after each upload.",
                isOn: $prefs.clipboardCopy
            )

            if prefs.clipboardCopy {
                VStack(alignment: .leading, spacing: 4) {
                    Picker("Clipboard Content", selection: $prefs.clipboardMode) {
                        ForEach(ClipboardMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()

                    Text("Choose whether to copy the share URL or the captured image.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.leading, 16)
            }
        }
    }
}

// MARK: - ToggleRow

/// A single toggle row with a label and descriptive subtitle.
private struct ToggleRow: View {
    let label: String
    let description: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.body)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
        }
    }
}
