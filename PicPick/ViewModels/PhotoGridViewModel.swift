import SwiftUI
import Observation

@MainActor
@Observable
final class PhotoGridViewModel {

    private(set) var imageFiles: [ImageFile] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    var favoriteIdentifiers: Set<String> = []

    private let fileSystemService: FileSystemService
    private let persistenceService: PersistenceService

    init(
        fileSystemService: FileSystemService = .shared,
        persistenceService: PersistenceService = .shared
    ) {
        self.fileSystemService = fileSystemService
        self.persistenceService = persistenceService

        fileSystemService.onFilesDidChange = { [weak self] in
            Task { @MainActor in
                self?.imageFiles = fileSystemService.imageFiles
            }
        }
    }

    // MARK: - Actions

    func loadInitialDirectory() async {
        await fileSystemService.scanDocumentsDirectory()
        imageFiles = fileSystemService.imageFiles
    }

    func loadFromUserDirectory(_ url: URL) async {
        await fileSystemService.importFromUserDirectory(url)
        imageFiles = fileSystemService.imageFiles
    }

    func reloadFromDocuments() async {
        await fileSystemService.scanDocumentsDirectory()
        imageFiles = fileSystemService.imageFiles
    }

    func refresh() async {
        await fileSystemService.refresh()
        imageFiles = fileSystemService.imageFiles
    }

    func clearAndStartFresh() {
        fileSystemService.reset()
        imageFiles = []
    }

    var resumeIndex: Int? {
        guard persistenceService.hasLaunchedBefore else { return nil }
        let idx = persistenceService.lastViewedPhotoIndex
        guard idx >= 0, idx < imageFiles.count else { return nil }
        return idx
    }

    func toggleFavorite(_ localIdentifier: String) {
        if favoriteIdentifiers.contains(localIdentifier) {
            favoriteIdentifiers.remove(localIdentifier)
        } else {
            favoriteIdentifiers.insert(localIdentifier)
        }
    }

    func setFavoriteIdentifiers(_ identifiers: Set<String>) {
        favoriteIdentifiers = identifiers
    }

    func favoriteFiles() -> [ImageFile] {
        imageFiles.filter { favoriteIdentifiers.contains($0.id) }
    }
}
