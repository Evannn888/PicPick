import UIKit
import ImageIO

/// Loads images from file URLs with progressive resolution.
///
/// Strategy:
/// 1. Check NSCache (instant hit).
/// 2. Load a thumbnail via CGImageSource (subsample, fast header-only read).
/// 3. Load the full image via UIImage(contentsOfFile:) asynchronously.
/// 4. Cache both resolutions.
@MainActor
final class ImageLoadingService: Sendable {

    // MARK: - Dependencies

    private let cacheService: ImageCacheService

    // MARK: - Types

    enum LoadingStage: @unchecked Sendable {
        case cached(UIImage)
        case thumbnail(UIImage)
        case fullQuality(UIImage)
    }

    // MARK: - Init

    init(cacheService: ImageCacheService = .shared) {
        self.cacheService = cacheService
    }

    // MARK: - Public API

    /// Load an image for the given file, delivering stages as they become available.
    func loadImage(
        for file: ImageFile,
        targetSize: CGSize,
        onStage: @escaping @Sendable (LoadingStage) -> Void
    ) {
        let identifier = file.id

        // Stage 1: Check in-memory cache
        if let full = cacheService.image(for: fullQualityKey(for: identifier)) {
            onStage(.cached(full))
            return
        }

        if let thumb = cacheService.image(for: thumbnailKey(for: identifier)) {
            onStage(.cached(thumb))
        }

        // Stage 2: Load thumbnail via CGImageSource (fast)
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }

            let thumbImage = Self.loadThumbnail(from: file.url, targetSize: targetSize)

            await MainActor.run { [weak self] in
                guard let self, let thumbImage else { return }
                self.cacheService.setImage(thumbImage, for: self.thumbnailKey(for: identifier))
                onStage(.thumbnail(thumbImage))
            }

            // Stage 3: Load full-quality image
            let fullImage = await Self.loadFullImage(from: file.url, targetSize: targetSize)

            await MainActor.run { [weak self] in
                guard let self, let fullImage else { return }
                self.cacheService.setImage(fullImage, for: self.fullQualityKey(for: identifier))
                onStage(.fullQuality(fullImage))
            }
        }
    }

    /// Prefetch images into the in-memory cache.
    func startPrefetching(files: [ImageFile], targetSize: CGSize) {
        Task.detached(priority: .utility) { [weak self] in
            guard let self else { return }
            for file in files {
                let thumb = Self.loadThumbnail(from: file.url, targetSize: targetSize)
                guard let thumb else { continue }
                await MainActor.run { [weak self] in
                    self?.cacheService.setImage(thumb, for: "\(file.id)_thumb")
                }
            }
        }
    }

    func stopPrefetching(files: [ImageFile], targetSize: CGSize) {
        // Prefetching is fire-and-forget; no-op for cancellation.
        // Individual tasks can be cancelled via Task handle if needed.
    }

    // MARK: - Static Helpers (nonisolated, pure file I/O)

    /// Load a downsized thumbnail using CGImageSource, with UIImage fallback.
    nonisolated static func loadThumbnail(from url: URL, targetSize: CGSize) -> UIImage? {
        // Try CGImageSource fast path first
        if let source = CGImageSourceCreateWithURL(url as CFURL, nil) {
            let maxDimension = max(targetSize.width, targetSize.height) * 2.0
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maxDimension,
                kCGImageSourceShouldCacheImmediately: true,
            ]
            if let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) {
                return UIImage(cgImage: cgImage)
            }
        }

        // Fallback: load full image and downscale
        guard let image = UIImage(contentsOfFile: url.path) else { return nil }
        let scale = max(image.size.width / targetSize.width, image.size.height / targetSize.height, 1)
        let newSize = CGSize(width: image.size.width / scale, height: image.size.height / scale)
        return image.preparingThumbnail(of: newSize)
    }

    /// Load the full image from disk.
    nonisolated static func loadFullImage(from url: URL, targetSize: CGSize) async -> UIImage? {
        // Use UIImage(contentsOfFile:) which decodes on access, or manually decode.
        guard let image = UIImage(contentsOfFile: url.path) else {
            return nil
        }

        // Downsize if the image is much larger than the target
        let scale = max(
            image.size.width / targetSize.width,
            image.size.height / targetSize.height
        )

        if scale > 2.0 {
            let newSize = CGSize(
                width: image.size.width / scale,
                height: image.size.height / scale
            )
            return image.preparingThumbnail(of: newSize)
        }

        return image
    }

    // MARK: - Cache Keys

    private func thumbnailKey(for identifier: String) -> String {
        "\(identifier)_thumb"
    }

    private func fullQualityKey(for identifier: String) -> String {
        "\(identifier)_full"
    }
}
