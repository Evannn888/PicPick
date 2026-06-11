import XCTest
@testable import PicPick

/// Tests for FavoritesViewModel CRUD operations backed by UserDefaults.
@MainActor
final class FavoritesViewModelTests: XCTestCase {

    var viewModel: FavoritesViewModel!
    private let testKey = "com.picpick.favorites"

    override func setUp() async throws {
        // Clear any persisted data before each test
        UserDefaults.standard.removeObject(forKey: testKey)
        viewModel = FavoritesViewModel()
    }

    override func tearDown() async throws {
        UserDefaults.standard.removeObject(forKey: testKey)
        viewModel = nil
    }

    // MARK: - Initial State

    func testInitialState_EmptyFavorites() {
        XCTAssertTrue(viewModel.favorites.isEmpty)
        XCTAssertTrue(viewModel.favoriteIdentifiers.isEmpty)
    }

    // MARK: - Toggle

    func testToggleFavorite_AddsFavorite() {
        let id = "test-photo-1"
        let result = viewModel.toggleFavorite(localIdentifier: id)

        XCTAssertTrue(result, "Should return true when adding")
        XCTAssertTrue(viewModel.isFavorited(id))
        XCTAssertEqual(viewModel.favoriteIdentifiers.count, 1)
        XCTAssertEqual(viewModel.favorites.count, 1)
        XCTAssertEqual(viewModel.favorites.first?.localIdentifier, id)
    }

    func testToggleFavorite_RemovesFavorite() {
        let id = "test-photo-2"

        viewModel.toggleFavorite(localIdentifier: id)
        XCTAssertTrue(viewModel.isFavorited(id))

        let result = viewModel.toggleFavorite(localIdentifier: id)
        XCTAssertFalse(result, "Should return false when removing")
        XCTAssertFalse(viewModel.isFavorited(id))
        XCTAssertTrue(viewModel.favoriteIdentifiers.isEmpty)
        XCTAssertTrue(viewModel.favorites.isEmpty)
    }

    func testToggleFavorite_MultipleToggles_Idempotent() {
        let id = "test-photo-3"

        viewModel.toggleFavorite(localIdentifier: id)
        viewModel.toggleFavorite(localIdentifier: id)
        viewModel.toggleFavorite(localIdentifier: id)

        XCTAssertTrue(viewModel.isFavorited(id))
        XCTAssertEqual(viewModel.favoriteIdentifiers.count, 1)
    }

    // MARK: - IsFavorited

    func testIsFavorited_ReturnsFalse_WhenNotExist() {
        XCTAssertFalse(viewModel.isFavorited("nonexistent"))
    }

    func testIsFavorited_ReturnsTrue_AfterAdd() {
        let id = "test-photo-4"
        viewModel.toggleFavorite(localIdentifier: id)
        XCTAssertTrue(viewModel.isFavorited(id))
    }

    // MARK: - Persistence

    func testPersistence_SurvivesVMRecreation() {
        let ids = ["a", "b", "c"]
        for id in ids {
            viewModel.toggleFavorite(localIdentifier: id)
        }

        // Create a new VM — should load from UserDefaults
        let newVM = FavoritesViewModel()
        XCTAssertEqual(newVM.favorites.count, 3)
        XCTAssertEqual(newVM.favoriteIdentifiers, Set(ids))
    }
}
