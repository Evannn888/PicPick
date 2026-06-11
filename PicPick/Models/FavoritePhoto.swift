import Foundation

/// A favorited photo, persisted as JSON in UserDefaults.
/// Avoids SwiftData's `@Model` macro which has Sendable incompatibilities in this Swift 6 version.
struct FavoritePhoto: Codable, Identifiable, Sendable {
    let localIdentifier: String
    let favoritedAt: Date
    var sortOrder: Int

    var id: String { localIdentifier }

    init(localIdentifier: String, favoritedAt: Date = .now, sortOrder: Int = 0) {
        self.localIdentifier = localIdentifier
        self.favoritedAt = favoritedAt
        self.sortOrder = sortOrder
    }
}
