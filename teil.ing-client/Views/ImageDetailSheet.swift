import SwiftUI

// MARK: - ImageDetailSheet

/// Detail and edit view for a single image, shown when tapping a history row with a remote image.
/// Loads full image metadata via APIService and allows editing privacy, password, maxViews, and expiry.
struct ImageDetailSheet: View {

    let imageId: String
    var onDismiss: () -> Void
    var onDeleted: () -> Void

    // MARK: - Fetch State

    @State private var image: ImageResponse?
    @State private var isLoading = true
    @State private var error: String?

    // MARK: - Editable Fields

    @State private var isPrivate: Bool = false
    @State private var passwordText: String = ""
    @State private var removePassword: Bool = false
    @State private var maxViewsText: String = ""
    @State private var validForDaysText: String = ""

    // MARK: - Action State

    @State private var isSaving: Bool = false
    @State private var isDeleting: Bool = false
    @State private var saveError: String?
    @State private var showDeleteConfirm = false

    // MARK: - Formatters

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header with back button
                HStack {
                    Button {
                        onDismiss()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)

                    Spacer()

                    Text("Image Details")
                        .font(.headline)

                    Spacer()

                    // Balance the back button for centered title
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .hidden()
                }
                .padding(.bottom, 12)

                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                            .padding(.vertical, 40)
                        Spacer()
                    }
                } else if let error = error {
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.title2)
                            .foregroundStyle(.red)
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                } else if let img = image {
                    imageDetailContent(img)
                }
            }
            .padding(16)
        }
        .frame(width: 320)
        .onAppear {
            Task { await loadImage() }
        }
    }

    // MARK: - Detail Content

    @ViewBuilder
    private func imageDetailContent(_ img: ImageResponse) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Thumbnail + metadata
            HStack(alignment: .top, spacing: 12) {
                thumbnailView(url: img.thumbnailUrl)
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                VStack(alignment: .leading, spacing: 4) {
                    Text(img.originalFilename)
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(2)

                    Text(formatBytes(img.fileSize))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(img.mimeType)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 16) {
                Label("\(img.viewCount) views", systemImage: "eye")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let createdDate = parseDate(img.createdAt) {
                    Label(dateFormatter.string(from: createdDate), systemImage: "calendar")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            // Settings section
            Text("Settings")
                .font(.subheadline)
                .fontWeight(.semibold)
                .padding(.top, 4)

            // Private toggle
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Private")
                        .font(.body)
                    Text("Only you can view this image")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("", isOn: $isPrivate)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }

            // Password section
            if img.hasPassword {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Password")
                            .font(.body)
                        Text("This image has a password set")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Remove") {
                        removePassword = true
                        passwordText = ""
                    }
                    .controlSize(.small)
                    .foregroundStyle(removePassword ? .red : .secondary)
                    .disabled(removePassword)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(img.hasPassword ? "Change Password" : "Set Password")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                SecureField("New password (optional)", text: $passwordText)
                    .textFieldStyle(.roundedBorder)
            }

            // Max views
            VStack(alignment: .leading, spacing: 4) {
                Text("Max Views")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Unlimited", text: $maxViewsText)
                    .textFieldStyle(.roundedBorder)
            }

            // Expiry
            VStack(alignment: .leading, spacing: 4) {
                Text("Expires in (days)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Never", text: $validForDaysText)
                    .textFieldStyle(.roundedBorder)
            }

            if let saveError = saveError {
                Text(saveError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            // Save button
            Button {
                Task { await saveChanges(original: img) }
            } label: {
                if isSaving {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Save Changes")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isSaving || isDeleting)
            .controlSize(.regular)

            Divider()
                .padding(.vertical, 4)

            // Delete button
            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                if isDeleting {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Delete Image")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.bordered)
            .disabled(isSaving || isDeleting)
            .confirmationDialog(
                "Delete this image?",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    Task { await performDelete() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete the image from the server and cannot be undone.")
            }
        }
    }

    // MARK: - Thumbnail

    @ViewBuilder
    private func thumbnailView(url: String?) -> some View {
        if let urlString = url, let imageURL = URL(string: urlString) {
            AsyncImage(url: imageURL) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().aspectRatio(contentMode: .fill)
                case .failure:
                    placeholderThumbnail
                case .empty:
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.secondary.opacity(0.1))
                @unknown default:
                    placeholderThumbnail
                }
            }
        } else {
            placeholderThumbnail
        }
    }

    private var placeholderThumbnail: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(Color.secondary.opacity(0.2))
            .overlay {
                Image(systemName: "photo")
                    .foregroundStyle(.secondary)
            }
    }

    // MARK: - Actions

    private func loadImage() async {
        isLoading = true
        error = nil
        do {
            let loaded = try await APIService.shared.getImageDetails(id: imageId)
            image = loaded
            // Pre-populate editable fields from loaded image
            isPrivate = loaded.isPrivate
            maxViewsText = loaded.maxViews.map { String($0) } ?? ""
        } catch {
            self.error = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
        isLoading = false
    }

    private func saveChanges(original: ImageResponse) async {
        isSaving = true
        saveError = nil

        var update = ImageUpdateRequest()

        // Only include changed fields
        if isPrivate != original.isPrivate {
            update.private = isPrivate
        }
        if !passwordText.isEmpty {
            update.password = passwordText
        }
        if removePassword {
            update.removePassword = true
        }
        let maxViewsValue = Int(maxViewsText)
        if maxViewsText.isEmpty && original.maxViews != nil {
            // User cleared maxViews — set to nil by omitting (API doesn't support null patch currently)
        } else if let mv = maxViewsValue, mv != original.maxViews {
            update.maxViews = mv
        }
        if let days = Int(validForDaysText) {
            update.validForDays = days
        }

        do {
            try await APIService.shared.updateImage(id: imageId, update: update)
            // Reload to reflect server state
            await loadImage()
        } catch {
            saveError = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }

        isSaving = false
    }

    private func performDelete() async {
        isDeleting = true
        do {
            try await APIService.shared.deleteImage(id: imageId)
            onDeleted()
        } catch {
            saveError = (error as? APIError)?.errorDescription ?? error.localizedDescription
            isDeleting = false
        }
    }

    // MARK: - Helpers

    private func formatBytes(_ bytes: Int) -> String {
        let mb = Double(bytes) / 1_048_576
        if mb >= 1.0 {
            return String(format: "%.1f MB", mb)
        }
        let kb = Double(bytes) / 1024
        return String(format: "%.0f KB", kb)
    }

    private func parseDate(_ iso8601: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: iso8601) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: iso8601)
    }
}
