import XCTest
@testable import PicPick

/// Tests for ImageCache and ImageCacheService.
@MainActor
final class ImageCacheServiceTests: XCTestCase {

    var cache: ImageCache!
    var cacheService: ImageCacheService!

    override func setUp() async throws {
        cache = ImageCache(maxCost: 50_000_000, maxCount: 20)
        cacheService = ImageCacheService.shared
        cacheService.removeAll()
    }

    override func tearDown() async throws {
        cache.removeAll()
        cacheService.removeAll()
    }

    // MARK: - ImageCache (Low-Level)

    func testCache_SetAndRetrieve_ReturnsSameImage() {
        let image = createTestImage(size: CGSize(width: 100, height: 100))
        let key = "test-image-1"

        cache.setImage(image, for: key)
        let retrieved = cache.image(for: key)

        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.size.width, 100)
        XCTAssertEqual(retrieved?.size.height, 100)
    }

    func testCache_RemoveImage_ReturnsNil() {
        let image = createTestImage(size: CGSize(width: 50, height: 50))
        let key = "test-image-2"

        cache.setImage(image, for: key)
        cache.removeImage(for: key)

        XCTAssertNil(cache.image(for: key))
    }

    func testCache_RemoveAll_ClearsEverything() {
        for i in 0..<5 {
            cache.setImage(createTestImage(size: CGSize(width: 100, height: 100)), for: "img-\(i)")
        }

        cache.removeAll()

        for i in 0..<5 {
            XCTAssertNil(cache.image(for: "img-\(i)"))
        }
    }

    func testCache_SubscriptAccess_Works() {
        let image = createTestImage(size: CGSize(width: 10, height: 10))
        let key = "sub-test"

        cache[key] = image
        XCTAssertNotNil(cache[key])

        cache[key] = nil
        XCTAssertNil(cache[key])
    }

    // MARK: - ImageCacheService (High-Level)

    func testCacheService_SetAndGet_Works() {
        let image = createTestImage(size: CGSize(width: 200, height: 200))
        let key = "service-test-1"

        cacheService.setImage(image, for: key)
        let result = cacheService.image(for: key)

        XCTAssertNotNil(result)
    }

    func testCacheService_RemoveImage_Works() {
        let image = createTestImage(size: CGSize(width: 100, height: 100))
        let key = "service-test-2"

        cacheService.setImage(image, for: key)
        cacheService.removeImage(for: key)

        XCTAssertNil(cacheService.image(for: key))
    }

    // MARK: - Helpers

    private func createTestImage(size: CGSize) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}
