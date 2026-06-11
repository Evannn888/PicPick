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

    static let shared = ImageLoadingService()

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

        // Stage 1: Check Memory Cache
        if let full = cacheService.image(for: fullQualityKey(for: identifier)) {
            onStage(.cached(full))
            return
        }

        if let thumb = cacheService.image(for: thumbnailKey(for: identifier)) {
            onStage(.cached(thumb))
            // Only proceed if we want full quality after thumbnail
        }

        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }

            // Calculate disk cache key
            let fileSize = file.fileSize
            let diskKey = await ThumbnailDiskCache.shared.cacheKey(for: file.url, fileSize: fileSize, creationDate: file.modificationDate)

            // Stage 2: Check Disk Cache
            if let diskThumb = await ThumbnailDiskCache.shared.image(forKey: diskKey) {
                await MainActor.run { [weak self] in
                    self?.cacheService.setImage(diskThumb, for: self?.thumbnailKey(for: identifier) ?? "")
                    onStage(.thumbnail(diskThumb))
                }
            } else {
                // Stage 3 & 4: Load EXIF or Generate Thumbnail via Worker Pool
                let thumbImage = try? await ThumbnailWorkerPool.shared.execute {
                    Self.loadThumbnailPipeline(from: file.url, targetSize: targetSize, diskKey: diskKey)
                }

                if let thumbImage {
                    await MainActor.run { [weak self] in
                        self?.cacheService.setImage(thumbImage, for: self?.thumbnailKey(for: identifier) ?? "")
                        onStage(.thumbnail(thumbImage))
                    }
                }
            }

            if Task.isCancelled { return }
            
            // Stage 5: Load Full-Quality Image (Progressive Viewer)
            let fullImage = await Self.loadFullImage(from: file.url, targetSize: targetSize)

            if Task.isCancelled { return }
            
            await MainActor.run { [weak self] in
                guard let self, let fullImage else { return }
                self.cacheService.setImage(fullImage, for: self.fullQualityKey(for: identifier))
                onStage(.fullQuality(fullImage))
            }
        }
    }

    /// Prefetch images into the cache.
    func startPrefetching(files: [ImageFile], targetSize: CGSize) {
        cancelPrefetching()

        let task = Task.detached(priority: .utility) { [weak self] in
            guard let self else { return }
            for file in files {
                guard !Task.isCancelled else { break }
                
                let fileSize = file.fileSize
                let diskKey = await ThumbnailDiskCache.shared.cacheKey(for: file.url, fileSize: fileSize, creationDate: file.modificationDate)
                
                // If it's already in memory, skip
                let memKey = await MainActor.run { self.thumbnailKey(for: file.id) }
                let hasMemCache = await MainActor.run { self.cacheService.image(for: memKey) != nil }
                if hasMemCache { continue }
                
                // If it's already on disk, load it into memory
                if let diskThumb = await ThumbnailDiskCache.shared.image(forKey: diskKey) {
                    await MainActor.run { [weak self] in
                        self?.cacheService.setImage(diskThumb, for: memKey)
                    }
                    continue
                }
                
                // Otherwise fetch/generate using the worker pool
                let thumb = try? await ThumbnailWorkerPool.shared.execute {
                    Self.loadThumbnailPipeline(from: file.url, targetSize: targetSize, diskKey: diskKey)
                }
                
                guard let thumb else { continue }
                await MainActor.run { [weak self] in
                    self?.cacheService.setImage(thumb, for: memKey)
                }
            }
        }
        activePrefetchTasks.append(task)
    }

    func stopPrefetching(files: [ImageFile], targetSize: CGSize) {
        cancelPrefetching()
    }

    private func cancelPrefetching() {
        for task in activePrefetchTasks {
            task.cancel()
        }
        activePrefetchTasks.removeAll()
    }

    private var activePrefetchTasks: [Task<Void, Never>] = []

    // MARK: - Pipeline Helpers

    /// Public endpoint for views (like PhotoGridCell) to fetch a thumbnail through the disk -> exif -> gen pipeline.
    nonisolated static func fetchThumbnail(for file: ImageFile, targetSize: CGSize) async -> UIImage? {
        let fileSize = file.fileSize
        let diskKey = await ThumbnailDiskCache.shared.cacheKey(for: file.url, fileSize: fileSize, creationDate: file.modificationDate)
        
        if let diskThumb = await ThumbnailDiskCache.shared.image(forKey: diskKey) {
            return diskThumb
        }
        
        return try? await ThumbnailWorkerPool.shared.execute {
            Self.loadThumbnailPipeline(from: file.url, targetSize: targetSize, diskKey: diskKey)
        }
    }

    /// Implements Stage 3 (EXIF) and Stage 4 (Generate)
    nonisolated private static func loadThumbnailPipeline(from url: URL, targetSize: CGSize, diskKey: String) -> UIImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        
        // Stage 3: Try to extract embedded EXIF thumbnail instantly
        let exifOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageIfAbsent: false,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]
        
        if let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, exifOptions as CFDictionary) {
            let exifThumb = UIImage(cgImage: cgImage)
            Task { await ThumbnailDiskCache.shared.storeImage(exifThumb, forKey: diskKey) }
            return exifThumb
        }
        
        // Stage 4: Generation Fallback (max 400px as per spec)
        let maxDimension = max(targetSize.width, targetSize.height, 400)
        let genOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension
        ]
        
        if let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, genOptions as CFDictionary) {
            let generatedThumb = UIImage(cgImage: cgImage)
            Task { await ThumbnailDiskCache.shared.storeImage(generatedThumb, forKey: diskKey) }
            return generatedThumb
        }

        return nil
    }

    /// Load the full image from disk.
    nonisolated static func loadFullImage(from url: URL, targetSize: CGSize) async -> UIImage? {
        guard let image = UIImage(contentsOfFile: url.path) else { return nil }

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

/// Limits concurrent thumbnail generation to prevent overwhelming the CPU and USB bandwidth.
actor ThumbnailWorkerPool {
    static let shared = ThumbnailWorkerPool()
    
    private let maxConcurrentWorkers: Int = 4
    private var activeWorkers: Int = 0
    private var waitingTasks: [CheckedContinuation<Void, Never>] = []
    
    private init() {}
    
    func acquire() async {
        if activeWorkers < maxConcurrentWorkers {
            activeWorkers += 1
            return
        }
        
        await withCheckedContinuation { continuation in
            waitingTasks.append(continuation)
        }
    }
    
    func release() {
        if !waitingTasks.isEmpty {
            let next = waitingTasks.removeFirst()
            next.resume()
        } else {
            activeWorkers -= 1
        }
    }
    
    func execute<T: Sendable>(_ operation: @Sendable @escaping () async -> T) async throws -> T {
        if Task.isCancelled { throw CancellationError() }
        
        await acquire()
        
        if Task.isCancelled {
            self.release()
            throw CancellationError()
        }
        
        defer { self.release() }
        return await operation()
    }
}
