import Foundation
import Observation

/// Manages the favorites system backed by UserDefaults JSON storage.
///
/// Responsibilities:
/// - CRUD operations on FavoritePhoto entities
/// - Bulk fetch of all favorite identifiers for efficient set membership checks
/// - Sync with the grid view model's in-memory favorites set
@MainActor
@Observable
final class FavoritesViewModel {

    // MARK: - Published State

    /// All favorited identifiers.
    private(set) var favoriteIdentifiers: Set<String> = []

    /// All FavoritePhoto entities, sorted by favoritedAt (newest first).
    private(set) var favorites: [FavoritePhoto] = []

    // MARK: - Storage

    private let storageKey = "com.picpick.favorites"

    // MARK: - Init

    init() {
        fetchAll()
    }

    // MARK: - CRUD

    /// Fetch all favorites from storage.
    func fetchAll() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            favorites = []
            favoriteIdentifiers = []
            return
        }

        do {
            favorites = try JSONDecoder().decode([FavoritePhoto].self, from: data)
            favoriteIdentifiers = Set(favorites.map(\.localIdentifier))
        } catch {
            print("[FavoritesViewModel] Decode error: \(error.localizedDescription)")
            favorites = []
            favoriteIdentifiers = []
        }
    }

    /// Toggle the favorite status for a given photo localIdentifier.
    /// - Returns: The new favorite state (true = favorited, false = unfavorited).
    @discardableResult
    func toggleFavorite(localIdentifier: String) -> Bool {
        if favoriteIdentifiers.contains(localIdentifier) {
            removeFavorite(localIdentifier: localIdentifier)
            return false
        } else {
            addFavorite(localIdentifier: localIdentifier)
            return true
        }
    }

    /// Check if a given identifier is favorited.
    func isFavorited(_ localIdentifier: String) -> Bool {
        favoriteIdentifiers.contains(localIdentifier)
    }

    // MARK: - Private

    private func addFavorite(localIdentifier: String) {
        let favorite = FavoritePhoto(localIdentifier: localIdentifier)
        favorites.insert(favorite, at: 0)
        favoriteIdentifiers.insert(localIdentifier)
        persist()
    }

    private func removeFavorite(localIdentifier: String) {
        favorites.removeAll { $0.localIdentifier == localIdentifier }
        favoriteIdentifiers.remove(localIdentifier)
        persist()
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(favorites)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            print("[FavoritesViewModel] Encode error: \(error.localizedDescription)")
        }
    }
}
