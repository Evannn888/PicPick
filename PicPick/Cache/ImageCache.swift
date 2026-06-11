import UIKit

/// Low-level image cache based on NSCache with cost-based eviction.
///
/// Separated from ImageCacheService (which adds application-level logic)
/// to provide a pure, testable caching primitive.
final class ImageCache: @unchecked Sendable {

    // MARK: - Configuration

    private let maxCost: Int
    private let maxCount: Int

    // MARK: - Storage

    private let storage = NSCache<NSString, UIImage>()

    // MARK: - Init

    /// - Parameters:
    ///   - maxCost: Maximum total "cost" (pixel count proxy) before eviction.
    ///   - maxCount: Maximum number of cached images.
    init(maxCost: Int = 200_000_000, maxCount: Int = 100) {
        self.maxCost = maxCost
        self.maxCount = maxCount

        storage.totalCostLimit = maxCost
        storage.countLimit = maxCount
        storage.name = "com.picpick.raw-image-cache"
    }

    // MARK: - API

    func image(for key: String) -> UIImage? {
        storage.object(forKey: key as NSString)
    }

    func setImage(_ image: UIImage, for key: String) {
        let cost = Int(image.size.width * image.size.height * 4)
        storage.setObject(image, forKey: key as NSString, cost: cost)
    }

    func removeImage(for key: String) {
        storage.removeObject(forKey: key as NSString)
    }

    func removeAll() {
        storage.removeAllObjects()
    }

    subscript(key: String) -> UIImage? {
        get { image(for: key) }
        set {
            if let image = newValue {
                setImage(image, for: key)
            } else {
                removeImage(for: key)
            }
        }
    }
}
