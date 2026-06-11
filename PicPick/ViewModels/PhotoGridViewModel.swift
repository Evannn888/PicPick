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

    private var scanTask: Task<Void, Never>?

    func loadInitialDirectory() async {
        // Fallback or previously accessed directory logic
    }

    func loadFromUserDirectory(_ url: URL) async {
        scanTask?.cancel()
        fileSystemService.setActiveDirectory(url)
        
        imageFiles = []
        isLoading = true
        errorMessage = nil

        scanTask = Task { @MainActor in
            let stream = fileSystemService.streamPhotos(directory: url)
            
            for await batch in stream {
                guard !Task.isCancelled else { break }
                imageFiles.append(contentsOf: batch)
                // Stop showing the loading spinner as soon as we have the first batch
                if !imageFiles.isEmpty {
                    isLoading = false
                }
            }
            
            guard !Task.isCancelled else { return }
            
            // Final sort by modification date descending
            imageFiles.sort {
                ($0.modificationDate ?? .distantPast) > ($1.modificationDate ?? .distantPast)
            }
            isLoading = false
            
            if imageFiles.isEmpty {
                errorMessage = "No compatible images found in that folder."
            }
        }
    }

    func reloadFromDocuments() async {
        // Obsolete
    }

    func refresh() async {
        // Could implement re-scan if needed
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
    
    // MARK: - Prefetching

    private var lastVisibleIndex: Int = 0
    private var scrollDirectionIsDown: Bool = true
    
    func onItemAppear(index: Int, targetSize: CGSize) {
        guard !imageFiles.isEmpty, index < imageFiles.count else { return }
        
        // Determine scroll direction
        scrollDirectionIsDown = index >= lastVisibleIndex
        lastVisibleIndex = index
        
        let prefetchAmount = 30
        let prefetchStart = scrollDirectionIsDown ? index + 1 : max(0, index - prefetchAmount)
        let prefetchEnd = scrollDirectionIsDown ? min(imageFiles.count, index + prefetchAmount + 1) : index
        
        guard prefetchStart < prefetchEnd else { return }
        
        let prefetchRange = prefetchStart..<prefetchEnd
        let filesToPrefetch = Array(imageFiles[prefetchRange])
        
        ImageLoadingService.shared.startPrefetching(files: filesToPrefetch, targetSize: targetSize)
    }
}
