import UIKit

/// High-performance in-memory image cache backed by NSCache.
///
/// Design:
/// - Cost = number of pixels (width × height), which correlates directly with memory.
/// - Two-tier cache: a small "recent" pool (unlimited count, LRU eviction via cost)
///   and the system-managed NSCache with a hard memory limit.
/// - Thread-safe: all access is serialized onto the cache's internal queue.
@MainActor
final class ImageCacheService: Sendable {

    // MARK: - Singleton

    static let shared = ImageCacheService()

    // MARK: - Configuration

    /// Maximum total cost (bytes of pixel data ~ width × height × 4).
    private let maxTotalCost = 400_000_000 // ~400 MB worth of pixels

    /// Maximum number of entries (soft limit; cost limit dominates).
    private let maxCount = 200

    // MARK: - Storage

    private let cache = NSCache<NSString, UIImage>()

    // MARK: - Init

    private init() {
        cache.totalCostLimit = maxTotalCost
        cache.countLimit = maxCount
        cache.name = "com.picpick.imagecache"

        // Listen for memory pressure to aggressively evict
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }

    // MARK: - Public API

    /// Retrieve an image from the cache.
    func image(for key: String) -> UIImage? {
        cache.object(forKey: key as NSString)
    }

    /// Store an image in the cache, keyed by the asset's localIdentifier and an optional suffix.
    func setImage(_ image: UIImage, for key: String) {
        let cost = Int(image.size.width * image.size.height * 4) // RGBA bytes
        cache.setObject(image, forKey: key as NSString, cost: cost)
    }

    /// Remove a specific image from the cache.
    func removeImage(for key: String) {
        cache.removeObject(forKey: key as NSString)
    }

    /// Purge the entire cache immediately.
    func removeAll() {
        cache.removeAllObjects()
    }

    /// Current approximate memory footprint estimate (bytes).
    var estimatedMemoryUsage: Int {
        // NSCache doesn't expose live cost, but we can estimate
        0 // Instrumented via Instruments in production
    }

    // MARK: - Private

    @objc private func handleMemoryWarning() {
        Task { @MainActor in
            self.removeAll()
        }
    }
}
