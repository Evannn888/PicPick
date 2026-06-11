import XCTest
@testable import PicPick

/// Tests for PhotoViewerViewModel navigation and bounds logic.
@MainActor
final class PhotoViewerViewModelTests: XCTestCase {

    var viewModel: PhotoViewerViewModel!
    var mockFiles: [ImageFile] = []

    override func setUp() async throws {
        let loadingService = ImageLoadingService()

        // Create mock ImageFile instances using real temp files
        let tempDir = FileManager.default.temporaryDirectory
        for i in 0..<10 {
            let url = tempDir.appendingPathComponent("test_\(i).jpg")
            let imageData = createTestJPEGData()
            try? imageData.write(to: url)
            mockFiles.append(ImageFile(url: url))
        }

        guard !mockFiles.isEmpty else {
            XCTFail("Failed to create mock files")
            return
        }

        viewModel = PhotoViewerViewModel(
            imageFiles: mockFiles,
            initialIndex: 0,
            imageLoadingService: loadingService
        )
    }

    override func tearDown() async throws {
        for file in mockFiles {
            try? FileManager.default.removeItem(at: file.url)
        }
    }

    // MARK: - Navigation

    func testInitialIndex_IsCorrect() {
        XCTAssertEqual(viewModel.currentIndex, 0)
    }

    func testInitialIndex_ClampedToMax() {
        let vm = PhotoViewerViewModel(
            imageFiles: mockFiles,
            initialIndex: 999,
            imageLoadingService: ImageLoadingService()
        )
        XCTAssertEqual(vm.currentIndex, max(0, mockFiles.count - 1))
    }

    func testGoToNext_Increments() {
        let initial = viewModel.currentIndex
        viewModel.goToNext()
        XCTAssertEqual(viewModel.currentIndex, initial + 1)
    }

    func testGoToNext_StopsAtEnd() {
        let vm = PhotoViewerViewModel(
            imageFiles: mockFiles,
            initialIndex: mockFiles.count - 1,
            imageLoadingService: ImageLoadingService()
        )
        vm.goToNext()
        XCTAssertEqual(vm.currentIndex, mockFiles.count - 1)
    }

    func testGoToPrevious_Decrements() {
        let vm = PhotoViewerViewModel(
            imageFiles: mockFiles,
            initialIndex: 2,
            imageLoadingService: ImageLoadingService()
        )
        vm.goToPrevious()
        XCTAssertEqual(vm.currentIndex, 1)
    }

    func testGoToPrevious_StopsAtStart() {
        viewModel.goToPrevious()
        XCTAssertEqual(viewModel.currentIndex, 0)
    }

    // MARK: - Access

    func testCurrentFile_ReturnsCorrectFile() {
        let file = viewModel.currentFile
        XCTAssertNotNil(file)
        XCTAssertEqual(file?.id, mockFiles[0].id)
    }

    func testFileAt_ReturnsNilWhenOutOfBounds() {
        XCTAssertNil(viewModel.file(at: -1))
        XCTAssertNil(viewModel.file(at: mockFiles.count + 1))
    }

    func testPhotoCount_MatchesInput() {
        XCTAssertEqual(viewModel.photoCount, mockFiles.count)
    }

    // MARK: - Helpers

    private func createTestJPEGData() -> Data {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 10, height: 10))
        let image = renderer.image { ctx in
            UIColor.blue.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 10, height: 10))
        }
        return image.jpegData(compressionQuality: 0.8)!
    }
}
