import SwiftUI

/// A single page in the full-screen photo viewer.
///
/// Wraps ZoomableScrollViewRepresentable and handles progressive image loading:
/// 1. Shows thumbnail immediately (from cache if available).
/// 2. Replaces with high-quality image asynchronously.
///
/// Single-tap toggles chrome; double-tap zooms (handled by ZoomableScrollView).
struct PhotoCellView: View {
    let file: ImageFile
    let imageLoader: (CGSize, @escaping @Sendable (UIImage?) -> Void) -> Void

    var onSingleTap: (() -> Void)?

    init(file: ImageFile,
         imageLoader: @escaping (CGSize, @escaping @Sendable (UIImage?) -> Void) -> Void,
         onSingleTap: (() -> Void)? = nil) {
        self.file = file
        self.imageLoader = imageLoader
        self.onSingleTap = onSingleTap
    }

    // MARK: - State

    @State private var currentImage: UIImage?

    // MARK: - Body

    var body: some View {
        GeometryReader { geometry in
            ZoomableScrollViewRepresentable(
                image: currentImage,
                onSingleTap: { onSingleTap?() },
                onZoomChange: { _ in }
            )
            .ignoresSafeArea()
            .task { await loadImage(targetSize: geometry.size) }
        }
    }

    // MARK: - Image Loading

    private func loadImage(targetSize: CGSize) async {
        let image = await withCheckedContinuation { continuation in
            imageLoader(targetSize) { loadedImage in
                continuation.resume(returning: loadedImage)
            }
        }

        guard let image, !Task.isCancelled else { return }
        self.currentImage = image
    }
}
