import SwiftUI
import Observation

/// Manages state for the full-screen photo viewer.
///
/// Core design:
/// - Tracks the current photo index within the full file array.
/// - Coordinates preloading: current ± 10.
/// - Handles the "swipe down to dismiss" interaction state.
/// - Persists the last-viewed photo on changes.
@MainActor
@Observable
final class PhotoViewerViewModel {

    // MARK: - Published State

    var currentIndex: Int
    let imageFiles: [ImageFile]
    var isPresented = false
    var dismissProgress: CGFloat = 0
    var currentZoomScale: CGFloat = 1.0
    var isChromeVisible = true

    // MARK: - Prefetching

    private let prefetchWindowSize = 10
    private var prefetchingIDs: Set<String> = []
    private var prefetchTask: Task<Void, Never>?

    // MARK: - Dependencies

    private let persistenceService: PersistenceService
    let imageLoadingService: ImageLoadingService

    // MARK: - Init

    init(
        imageFiles: [ImageFile],
        initialIndex: Int,
        persistenceService: PersistenceService = .shared,
        imageLoadingService: ImageLoadingService
    ) {
        self.imageFiles = imageFiles
        self.currentIndex = max(0, min(initialIndex, max(0, imageFiles.count - 1)))
        self.persistenceService = persistenceService
        self.imageLoadingService = imageLoadingService
    }

    // MARK: - Computed

    var currentFile: ImageFile? {
        guard imageFiles.indices.contains(currentIndex) else { return nil }
        return imageFiles[currentIndex]
    }

    var photoCount: Int { imageFiles.count }

    // MARK: - Navigation

    func goToPrevious() {
        guard currentIndex > 0 else { return }
        currentIndex -= 1
        didChangeIndex()
    }

    func goToNext() {
        guard currentIndex < imageFiles.count - 1 else { return }
        currentIndex += 1
        didChangeIndex()
    }

    func goTo(index: Int) {
        guard imageFiles.indices.contains(index), index != currentIndex else { return }
        currentIndex = index
        didChangeIndex()
    }

    // MARK: - Prefetching

    func didChangeIndex() {
        persistCurrentPhoto()
        updatePrefetching()
    }

    func updatePrefetching(targetSize: CGSize? = nil) {
        let start = max(0, currentIndex - prefetchWindowSize)
        let end = min(imageFiles.count - 1, currentIndex + prefetchWindowSize)
        guard start <= end else { return }

        let windowIDs = Set((start...end).compactMap { idx -> String? in
            guard imageFiles.indices.contains(idx) else { return nil }
            return imageFiles[idx].id
        })

        let newIDs = windowIDs.subtracting(prefetchingIDs)
        prefetchingIDs = windowIDs

        guard let size = targetSize, !newIDs.isEmpty else { return }

        let newFiles = newIDs.compactMap { id in imageFiles.first { $0.id == id } }
        prefetchTask?.cancel()
        prefetchTask = Task {
            imageLoadingService.startPrefetching(files: newFiles, targetSize: size)
        }
    }

    // MARK: - Dismiss

    func prepareForDismiss() {
        persistCurrentPhoto()
        prefetchTask?.cancel()
        prefetchingIDs.removeAll()
    }

    // MARK: - Persistence

    private func persistCurrentPhoto() {
        guard let file = currentFile else { return }
        persistenceService.lastViewedPhotoIdentifier = file.id
        persistenceService.lastViewedPhotoIndex = currentIndex
        persistenceService.synchronize()
    }

    // MARK: - Asset Access

    func file(at index: Int) -> ImageFile? {
        guard imageFiles.indices.contains(index) else { return nil }
        return imageFiles[index]
    }

    func fileBefore() -> ImageFile? { file(at: currentIndex - 1) }
    func fileAfter() -> ImageFile? { file(at: currentIndex + 1) }
}
