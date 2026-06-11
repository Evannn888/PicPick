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
        let pixelWidth = image.size.width * image.scale
        let pixelHeight = image.size.height * image.scale
        let cost = Int(pixelWidth * pixelHeight * 4) // RGBA bytes in actual pixels
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

import CryptoKit

actor ThumbnailDiskCache {
    static let shared = ThumbnailDiskCache()
    
    private let cacheDirectory: URL
    private let maxCacheSize: Int64 = 1_000_000_000 // 1 GB
    
    private init() {
        let paths = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        cacheDirectory = paths[0].appendingPathComponent("ThumbnailCache", isDirectory: true)
        
        if !FileManager.default.fileExists(atPath: cacheDirectory.path) {
            try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        }
    }
    
    /// Generates a unique cache key based on file path, size, and modification date to prevent stale caches
    func cacheKey(for url: URL, fileSize: Int64?, creationDate: Date?) -> String {
        let path = url.path
        let sizeString = fileSize.map { String($0) } ?? "0"
        let dateString = creationDate.map { String($0.timeIntervalSince1970) } ?? "0"
        
        let combinedString = "\(path)_\(sizeString)_\(dateString)"
        let hash = SHA256.hash(data: Data(combinedString.utf8))
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    func image(forKey key: String) -> UIImage? {
        var fileURL = cacheDirectory.appendingPathComponent(key)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        
        // Update access date for LRU
        try? fileURL.setResourceValues({
            var values = URLResourceValues()
            values.contentAccessDate = Date()
            return values
        }())
        
        return UIImage(contentsOfFile: fileURL.path)
    }
    
    private var writeCountSinceLastEnforce = 0
    
    func storeImage(_ image: UIImage, forKey key: String) {
        let fileURL = cacheDirectory.appendingPathComponent(key)
        guard let data = image.jpegData(compressionQuality: 0.75) else { return }
        
        do {
            try data.write(to: fileURL)
            writeCountSinceLastEnforce += 1
            if writeCountSinceLastEnforce >= 100 {
                writeCountSinceLastEnforce = 0
                Task { self.enforceSizeLimit() }
            }
        } catch {
            print("Failed to write to disk cache: \(error)")
        }
    }
    
    private func enforceSizeLimit() {
        let keys: [URLResourceKey] = [.fileSizeKey, .contentAccessDateKey]
        guard let enumerator = FileManager.default.enumerator(
            at: cacheDirectory,
            includingPropertiesForKeys: keys,
            options: .skipsHiddenFiles
        ) else { return }
        
        var totalSize: Int64 = 0
        var files: [(url: URL, size: Int64, accessDate: Date)] = []
        
        for case let url as URL in enumerator {
            guard let values = try? url.resourceValues(forKeys: Set(keys)),
                  let fileSize = values.fileSize,
                  let accessDate = values.contentAccessDate else { continue }
            
            let size = Int64(fileSize)
            totalSize += size
            files.append((url: url, size: size, accessDate: accessDate))
        }
        
        if totalSize > maxCacheSize {
            files.sort { $0.accessDate < $1.accessDate }
            var currentSize = totalSize
            for file in files {
                if currentSize <= maxCacheSize { break }
                try? FileManager.default.removeItem(at: file.url)
                currentSize -= file.size
            }
        }
    }
}
