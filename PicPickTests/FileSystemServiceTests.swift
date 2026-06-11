import XCTest
@testable import PicPick

/// Tests for FileSystemService.
@MainActor
final class FileSystemServiceTests: XCTestCase {

    var service: FileSystemService!
    let tempDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("PicPickTests-\(UUID().uuidString)")

    override func setUp() async throws {
        service = FileSystemService.shared
        // Create a temp directory with test images
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    // MARK: - Scanning

    func testScanEmptyDirectory_ReturnsNoFiles() async {
        await service.scanDirectory(tempDir)
        XCTAssertTrue(service.imageFiles.isEmpty)
    }

    func testScanDirectoryWithImages_ReturnsImageFiles() async throws {
        // Create a test image file
        let testFile = tempDir.appendingPathComponent("test.jpg")
        let imageData = createTestJPEGData()
        try imageData.write(to: testFile)

        await service.scanDirectory(tempDir)

        XCTAssertEqual(service.imageFiles.count, 1)
        XCTAssertEqual(service.imageFiles.first?.fileName, "test.jpg")
        XCTAssertTrue(service.imageFiles.first?.fileSize ?? 0 > 0)
    }

    func testScanDirectory_SortsByModificationDateDescending() async throws {
        let file1 = tempDir.appendingPathComponent("a.jpg")
        let file2 = tempDir.appendingPathComponent("b.png")

        try createTestJPEGData().write(to: file1)
        try createTestJPEGData().write(to: file2)

        await service.scanDirectory(tempDir)

        guard service.imageFiles.count >= 2 else {
            XCTFail("Expected at least 2 files")
            return
        }

        // Newest first
        let dates = service.imageFiles.compactMap(\.modificationDate)
        XCTAssertEqual(dates, dates.sorted(by: >), "Files should be sorted newest-first")
    }

    func testIsImageFile_ValidatesCorrectly() {
        let jpgFile = tempDir.appendingPathComponent("photo.jpg")
        let txtFile = tempDir.appendingPathComponent("notes.txt")

        XCTAssertTrue(service.isImageFile(jpgFile))
        XCTAssertFalse(service.isImageFile(txtFile))
    }

    // MARK: - Helpers

    private func createTestJPEGData() -> Data {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 10, height: 10))
        let image = renderer.image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 10, height: 10))
        }
        return image.jpegData(compressionQuality: 0.8)!
    }
}
