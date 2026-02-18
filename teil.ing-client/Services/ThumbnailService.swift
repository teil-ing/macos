import AppKit
import CoreGraphics
import Foundation

// MARK: - ThumbnailService

/// Caseless namespace for thumbnail generation and disk storage.
///
/// Generates 64x64px (32pt @2x) JPEG thumbnails from CGImage instances
/// and saves them to ~/Library/Application Support/teilingClient/thumbnails/.
/// Aspect-fill center-crop ensures the square thumbnail is always filled.
enum ThumbnailService {

    /// Pixel dimensions for saved thumbnails: 64px = 32pt at @2x display scale.
    static let thumbnailSize = CGSize(width: 64, height: 64)

    /// JPEG compression factor. 0.75 provides good quality at ~3-8 KB per thumbnail.
    static let jpegQuality: CGFloat = 0.75

    // MARK: - Directory

    /// Returns the thumbnails directory URL, creating intermediate directories if needed.
    ///
    /// Path: ~/Library/Application Support/teilingClient/thumbnails/
    static func thumbnailsDirectory() throws -> URL {
        let appSupport = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dir = appSupport.appendingPathComponent("teilingClient/thumbnails", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    // MARK: - Thumbnail Generation

    /// Resizes a CGImage to a 64x64px JPEG thumbnail (aspect-fill, center-crop) and saves to disk.
    ///
    /// - Parameters:
    ///   - cgImage: The source image from a `CaptureResult`.
    ///   - id: UUID used as the filename (`{id}.jpg`).
    /// - Returns: Absolute path string of the saved JPEG file.
    /// - Throws: `ThumbnailError.resizeFailed` or `ThumbnailError.encodingFailed` on failure.
    static func saveThumbnail(from cgImage: CGImage, id: UUID) throws -> String {
        let dir = try thumbnailsDirectory()
        let fileURL = dir.appendingPathComponent("\(id.uuidString).jpg")

        // Step 1: Create CGContext at target dimensions.
        let context = CGContext(
            data: nil,
            width: Int(thumbnailSize.width),
            height: Int(thumbnailSize.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        context?.interpolationQuality = .medium

        // Step 2: Compute center-crop source rect (aspect-fill).
        let srcRatio = CGFloat(cgImage.width) / CGFloat(cgImage.height)
        let destRatio = thumbnailSize.width / thumbnailSize.height

        let srcRect: CGRect
        if srcRatio > destRatio {
            // Source is wider than square — crop left and right sides.
            let cropW = CGFloat(cgImage.height) * destRatio
            let cropX = (CGFloat(cgImage.width) - cropW) / 2
            srcRect = CGRect(x: cropX, y: 0, width: cropW, height: CGFloat(cgImage.height))
        } else {
            // Source is taller than square — crop top and bottom.
            let cropH = CGFloat(cgImage.width) / destRatio
            let cropY = (CGFloat(cgImage.height) - cropH) / 2
            srcRect = CGRect(x: 0, y: cropY, width: CGFloat(cgImage.width), height: cropH)
        }

        // Step 3: Draw cropped image into context.
        if let cropped = cgImage.cropping(to: srcRect) {
            context?.draw(cropped, in: CGRect(origin: .zero, size: thumbnailSize))
        } else {
            // Fallback: draw full image scaled (no cropping possible).
            context?.draw(cgImage, in: CGRect(origin: .zero, size: thumbnailSize))
        }

        // Step 4: Extract resized image.
        guard let resized = context?.makeImage() else {
            throw ThumbnailError.resizeFailed
        }

        // Step 5: Encode as JPEG via NSBitmapImageRep.
        let rep = NSBitmapImageRep(cgImage: resized)
        guard let jpegData = rep.representation(using: .jpeg, properties: [.compressionFactor: jpegQuality]) else {
            throw ThumbnailError.encodingFailed
        }

        // Step 6: Write to disk.
        try jpegData.write(to: fileURL)
        return fileURL.path
    }

    // MARK: - Errors

    enum ThumbnailError: Error {
        case resizeFailed
        case encodingFailed
    }
}
