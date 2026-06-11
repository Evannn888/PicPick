import Foundation

/// Lightweight persistence for app state using UserDefaults.
/// Stores the last-viewed photo index so the app resumes where the user left off.
@MainActor
final class PersistenceService: Sendable {

    // MARK: - Singleton

    static let shared = PersistenceService()

    // MARK: - Keys

    private enum Key: String {
        case lastViewedPhotoIdentifier
        case lastViewedPhotoIndex
        case hasLaunchedBefore
        case userPreferences
    }

    private let defaults = UserDefaults(suiteName: "group.com.picpick") ?? .standard

    // MARK: - Init

    private init() {}

    // MARK: - Last Viewed Photo

    /// The localIdentifier of the last photo the user viewed.
    var lastViewedPhotoIdentifier: String? {
        get { defaults.string(forKey: Key.lastViewedPhotoIdentifier.rawValue) }
        set { defaults.set(newValue, forKey: Key.lastViewedPhotoIdentifier.rawValue) }
    }

    /// The index of the last photo the user viewed (for grid scrolling position).
    var lastViewedPhotoIndex: Int {
        get { defaults.integer(forKey: Key.lastViewedPhotoIndex.rawValue) }
        set { defaults.set(newValue, forKey: Key.lastViewedPhotoIndex.rawValue) }
    }

    // MARK: - Launch State

    var hasLaunchedBefore: Bool {
        get { defaults.bool(forKey: Key.hasLaunchedBefore.rawValue) }
        set {
            defaults.set(newValue, forKey: Key.hasLaunchedBefore.rawValue)
            // Ensure we sync immediately on first launch
            if !newValue {
                defaults.set(true, forKey: Key.hasLaunchedBefore.rawValue)
            }
        }
    }

    // MARK: - Utilities

    func synchronize() {
        defaults.synchronize()
    }

    func clearAll() {
        let keys: [Key] = [.lastViewedPhotoIdentifier, .lastViewedPhotoIndex]
        for key in keys {
            defaults.removeObject(forKey: key.rawValue)
        }
        defaults.synchronize()
    }
}
