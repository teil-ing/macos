import SwiftData
import SwiftUI

struct PopoverRootView: View {
    var onRegionCapture: (() -> Void)?
    var onFullscreenCapture: (() -> Void)?
    var onWindowCapture: (() -> Void)?

    /// Non-nil when a capture error has occurred and needs to be shown inside the popover.
    var captureError: String?

    /// Non-nil when the most recent upload failed after all retries.
    var uploadError: String?

    /// Called when the user taps "Retry Upload". Non-nil when a retry action is available.
    var onRetry: (() -> Void)?

    /// History store injected from AppDelegate — provides upload history to HistorySection.
    @ObservedObject var historyStore: HistoryStore

    /// Tracks whether the popover is currently showing preferences inline.
    @State private var showingPreferences = false

    /// The image ID selected for detail view (non-nil when detail sheet is showing).
    @State private var selectedImageId: String?

    /// Whether the image detail sheet is visible.
    @State private var showingImageDetail = false

    var body: some View {
        Group {
            if showingImageDetail, let imageId = selectedImageId {
                ImageDetailSheet(
                    imageId: imageId,
                    onDismiss: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showingImageDetail = false
                            selectedImageId = nil
                        }
                    },
                    onDeleted: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showingImageDetail = false
                            selectedImageId = nil
                        }
                        // Refresh the list after deletion
                        Task { await historyStore.refreshAll() }
                    }
                )
                .transition(.move(edge: .trailing))
            } else if showingPreferences {
                PreferencesView(onBack: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showingPreferences = false
                    }
                })
                .transition(.move(edge: .trailing))
            } else {
                mainContent
                    .transition(.move(edge: .leading))
            }
        }
        // Popover width widened from 280pt to 320pt — per locked decision for upload history phase
        .frame(width: 320)
    }

    // MARK: - Main Content

    private var mainContent: some View {
        VStack(spacing: 0) {
            if let uploadError = uploadError {
                VStack(spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        Text(uploadError)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .lineLimit(2)
                        Spacer()
                    }
                    if onRetry != nil {
                        Button {
                            onRetry?()
                        } label: {
                            Text("Retry Upload")
                                .font(.caption)
                                .frame(maxWidth: .infinity)
                        }
                        .controlSize(.small)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.red.opacity(0.08))

                Divider()
            }

            if let error = captureError {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .lineLimit(2)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.red.opacity(0.08))

                Divider()
            }

            CaptureSection(
                onRegionCapture: onRegionCapture,
                onFullscreenCapture: onFullscreenCapture,
                onWindowCapture: onWindowCapture
            )
            Divider()
            HistorySection(
                store: historyStore,
                onSelectDetail: { imageId in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedImageId = imageId
                        showingImageDetail = true
                    }
                }
            )
            Divider()

            // Quota bar — shown when quota data is available
            if let quota = historyStore.quota {
                QuotaBarView(quota: quota)
                Divider()
            }

            PopoverFooterView(onOpenPreferences: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showingPreferences = true
                }
            })
        }
    }
}

#Preview {
    let container = try! ModelContainer(
        for: HistoryEntry.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    PopoverRootView(historyStore: HistoryStore(container: container))
}

#Preview("Upload Error") {
    let container = try! ModelContainer(
        for: HistoryEntry.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    PopoverRootView(
        uploadError: "API key is invalid or expired.",
        onRetry: {},
        historyStore: HistoryStore(container: container)
    )
}
