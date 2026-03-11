import AppKit
import Foundation

// MARK: - UpdateService

/// Checks GitHub Releases for newer versions of teil.ing-client, downloads the DMG,
/// mounts it, replaces the running .app bundle, and relaunches the app.
///
/// Runs on the main actor so @Published properties are safe to observe from SwiftUI
/// without additional dispatching.
@MainActor
final class UpdateService: ObservableObject {

    static let shared = UpdateService()

    // MARK: - Public State

    /// True when a newer version has been detected on GitHub.
    @Published private(set) var updateAvailable: Bool = false

    /// The version string from the latest GitHub release (e.g. "1.1.0").
    @Published private(set) var latestVersion: String?

    /// Direct download URL for the DMG asset.
    @Published private(set) var downloadURL: URL?

    /// True while the GitHub API request is in-flight.
    @Published private(set) var isChecking: Bool = false

    /// True while the DMG is being downloaded or installed.
    @Published private(set) var isDownloading: Bool = false

    /// Download/install progress from 0.0 to 1.0.
    @Published private(set) var downloadProgress: Double = 0

    /// Human-readable description of the last error. Cleared at the start of each check.
    @Published private(set) var errorMessage: String?

    // MARK: - Private State

    private var periodicTimer: Timer?

    private init() {}

    // MARK: - GitHub Release Model

    private struct GitHubRelease: Decodable {
        let tagName: String
        let assets: [Asset]

        struct Asset: Decodable {
            let name: String
            let browserDownloadUrl: String
        }
    }

    // MARK: - Check for Updates

    /// Fetches the latest GitHub release and sets `updateAvailable` if it is newer than
    /// the currently running version.
    func checkForUpdates() async {
        isChecking = true
        errorMessage = nil

        defer { isChecking = false }

        let apiURL = URL(string: "https://api.github.com/repos/teil-ing/macos/releases/latest")!
        var request = URLRequest(url: apiURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.timeoutInterval = 15

        let data: Data
        do {
            let (responseData, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                errorMessage = "Could not reach GitHub. Please try again later."
                return
            }
            data = responseData
        } catch {
            errorMessage = "Network error: \(error.localizedDescription)"
            return
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let release: GitHubRelease
        do {
            release = try decoder.decode(GitHubRelease.self, from: data)
        } catch {
            errorMessage = "Could not parse release information."
            return
        }

        // Strip leading "v" — "v1.1.0" -> "1.1.0"
        let remoteVersion = release.tagName.hasPrefix("v")
            ? String(release.tagName.dropFirst())
            : release.tagName

        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"

        guard isNewerVersion(remoteVersion, than: currentVersion) else {
            // Already up-to-date
            updateAvailable = false
            return
        }

        // Find the DMG asset — prefer one matching "teil.ing-client-*.dmg", then any .dmg
        let dmgAsset = release.assets.first { $0.name.hasSuffix(".dmg") && $0.name.contains("teil.ing-client") }
                     ?? release.assets.first { $0.name.hasSuffix(".dmg") }

        guard let asset = dmgAsset, let url = URL(string: asset.browserDownloadUrl) else {
            // New version exists but no DMG asset found — surface version info only
            updateAvailable = true
            latestVersion = remoteVersion
            downloadURL = nil
            return
        }

        updateAvailable = true
        latestVersion = remoteVersion
        downloadURL = url
    }

    // MARK: - Download and Install

    /// Downloads the DMG, mounts it, copies the new .app over the existing one, and relaunches.
    func downloadAndInstall() async {
        guard let url = downloadURL else { return }

        guard !isRunningFromDMG() else {
            errorMessage = "Cannot update while running from a disk image. Copy teil.ing to your Applications folder first."
            return
        }

        isDownloading = true
        downloadProgress = 0

        defer {
            isDownloading = false
        }

        // 1. Download DMG to a temp file
        let tempDir = FileManager.default.temporaryDirectory
        let dmgPath = tempDir.appendingPathComponent("teil-ing-update-\(UUID().uuidString).dmg")

        let downloadData: Data
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                errorMessage = "Download failed. Please try again."
                return
            }
            downloadData = data
        } catch {
            errorMessage = "Download failed: \(error.localizedDescription)"
            return
        }

        do {
            try downloadData.write(to: dmgPath)
        } catch {
            errorMessage = "Could not save update file: \(error.localizedDescription)"
            return
        }

        downloadProgress = 0.5

        // 2. Mount the DMG
        let mountPoint = "/tmp/teil-ing-update"
        let mountResult = runProcess(
            "/usr/bin/hdiutil",
            arguments: ["attach", "-nobrowse", "-readonly", "-noverify",
                        "-mountpoint", mountPoint, dmgPath.path]
        )

        guard mountResult.exitCode == 0 else {
            errorMessage = "Could not mount update image."
            try? FileManager.default.removeItem(at: dmgPath)
            return
        }

        downloadProgress = 0.7

        // 3. Find the .app in the mount point
        let mountURL = URL(fileURLWithPath: mountPoint)
        let mountedAppURL: URL
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: mountURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
            guard let appBundle = contents.first(where: { $0.pathExtension == "app" }) else {
                errorMessage = "No application bundle found in update image."
                _ = runProcess("/usr/bin/hdiutil", arguments: ["detach", mountPoint, "-force"])
                try? FileManager.default.removeItem(at: dmgPath)
                return
            }
            mountedAppURL = appBundle
        } catch {
            errorMessage = "Could not read update image: \(error.localizedDescription)"
            _ = runProcess("/usr/bin/hdiutil", arguments: ["detach", mountPoint, "-force"])
            try? FileManager.default.removeItem(at: dmgPath)
            return
        }

        // 4. Unregister login item before replacing the bundle so macOS doesn't
        //    see a duplicate after relaunch. The new instance will re-register
        //    in completeLaunch() if the preference is still enabled.
        if PreferencesStore.shared.launchAtLogin {
            LaunchAtLoginService.shared.setEnabled(false)
        }

        // 5. Replace the running .app
        let currentAppPath = Bundle.main.bundlePath
        let currentAppURL = URL(fileURLWithPath: currentAppPath)
        let backupURL = URL(fileURLWithPath: currentAppPath + ".old")

        do {
            // Remove stale backup if one exists
            if FileManager.default.fileExists(atPath: backupURL.path) {
                try FileManager.default.removeItem(at: backupURL)
            }

            // Rename current app to backup
            try FileManager.default.moveItem(at: currentAppURL, to: backupURL)

            // Copy new app into place
            try FileManager.default.copyItem(at: mountedAppURL, to: currentAppURL)

            // Remove backup on success
            try? FileManager.default.removeItem(at: backupURL)
        } catch {
            // Restore from backup on failure
            if FileManager.default.fileExists(atPath: backupURL.path) {
                try? FileManager.default.moveItem(at: backupURL, to: currentAppURL)
            }
            // Re-register login item since we didn't replace
            if PreferencesStore.shared.launchAtLogin {
                LaunchAtLoginService.shared.setEnabled(true)
            }
            errorMessage = "Could not install update: \(error.localizedDescription)"
            _ = runProcess("/usr/bin/hdiutil", arguments: ["detach", mountPoint, "-force"])
            try? FileManager.default.removeItem(at: dmgPath)
            return
        }

        // 6. Unmount and clean up
        _ = runProcess("/usr/bin/hdiutil", arguments: ["detach", mountPoint, "-force"])
        try? FileManager.default.removeItem(at: dmgPath)

        downloadProgress = 1.0

        // 7. Relaunch the new version via a shell script that waits for this
        //    process to exit first, then opens the app normally (no -n flag).
        //    Using -n would create a "new instance" that macOS registers as a
        //    separate login item.
        let pid = ProcessInfo.processInfo.processIdentifier
        let script = """
            while kill -0 \(pid) 2>/dev/null; do sleep 0.2; done
            open "\(currentAppURL.path)"
            """
        let shellProcess = Process()
        shellProcess.executableURL = URL(fileURLWithPath: "/bin/sh")
        shellProcess.arguments = ["-c", script]
        try? shellProcess.run()

        NSApp.terminate(nil)
    }

    // MARK: - Periodic Check

    /// Starts a repeating timer that calls `checkForUpdates()` on the given interval.
    /// Cancels any existing timer first.
    func startPeriodicCheck(interval: TimeInterval = 4 * 60 * 60) {
        stopPeriodicCheck()
        periodicTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                await self?.checkForUpdates()
            }
        }
    }

    /// Stops and removes the periodic update check timer.
    func stopPeriodicCheck() {
        periodicTimer?.invalidate()
        periodicTimer = nil
    }

    // MARK: - Private Helpers

    /// Returns true if the app is currently running from a read-only DMG volume.
    ///
    /// Checks whether the parent directory of the app bundle is writable. If not,
    /// we are on a read-only volume (e.g., a mounted DMG) and cannot perform an in-place update.
    func isRunningFromDMG() -> Bool {
        let bundlePath = Bundle.main.bundlePath
        if bundlePath.hasPrefix("/Volumes/") {
            return true
        }
        let parentPath = (bundlePath as NSString).deletingLastPathComponent
        return !FileManager.default.isWritableFile(atPath: parentPath)
    }

    /// Returns true if `remote` is a strictly newer semantic version than `current`.
    private func isNewerVersion(_ remote: String, than current: String) -> Bool {
        let remoteComponents = remote.split(separator: ".").compactMap { Int($0) }
        let currentComponents = current.split(separator: ".").compactMap { Int($0) }

        let length = max(remoteComponents.count, currentComponents.count)

        for index in 0..<length {
            let remoteComponent = index < remoteComponents.count ? remoteComponents[index] : 0
            let currentComponent = index < currentComponents.count ? currentComponents[index] : 0

            if remoteComponent > currentComponent { return true }
            if remoteComponent < currentComponent { return false }
        }

        return false
    }

    /// Synchronously runs a process and returns its exit code and combined output.
    @discardableResult
    private func runProcess(_ executable: String, arguments: [String]) -> (exitCode: Int32, output: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return (-1, error.localizedDescription)
        }

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8) ?? ""
        return (process.terminationStatus, output)
    }
}
