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
            let scale = UIScreen.main.scale
            let pixelSize = CGSize(
                width: geometry.size.width * scale,
                height: geometry.size.height * scale
            )

            ZoomableScrollViewRepresentable(
                image: currentImage,
                onSingleTap: { onSingleTap?() },
                onZoomChange: { _ in }
            )
            .ignoresSafeArea()
            .task {
                // Synchronous cache check for instant display during swipe.
                let fullKey = "\(file.id)_full"
                if let cached = ImageCacheService.shared.image(for: fullKey) {
                    currentImage = scaledImageToFit(cached, geometrySize: geometry.size)
                    return
                }
                let thumbKey = "\(file.id)_thumb"
                if let cached = ImageCacheService.shared.image(for: thumbKey) {
                    currentImage = scaledImageToFit(cached, geometrySize: geometry.size)
                }

                // Then load progressively for higher quality.
                loadImage(targetSize: pixelSize, geometrySize: geometry.size)
            }
        }
    }

    // MARK: - Image Scaling

    /// Wraps the UIImage with a custom scale factor so its intrinsic size (in points)
    /// exactly aspect-fits the screen. This allows ZoomableScrollView to operate at
    /// a base zoomScale of 1.0 without creating massive layout frames that break swiping.
    private func scaledImageToFit(_ image: UIImage, geometrySize: CGSize) -> UIImage {
        guard geometrySize.width > 0, geometrySize.height > 0, let cgImage = image.cgImage else {
            return image
        }
        
        let pixelWidth = image.size.width * image.scale
        let pixelHeight = image.size.height * image.scale
        
        let widthRatio = pixelWidth / geometrySize.width
        let heightRatio = pixelHeight / geometrySize.height
        let requiredScale = max(widthRatio, heightRatio, 1.0)
        
        return UIImage(cgImage: cgImage, scale: requiredScale, orientation: image.imageOrientation)
    }

    // MARK: - Image Loading

    /// Kicks off progressive loading. The imageLoader callback fires multiple
    /// times (cached → thumbnail → fullQuality), and each delivery updates
    /// the displayed image so the user sees a sharp image as soon as it's ready.
    private func loadImage(targetSize: CGSize, geometrySize: CGSize) {
        imageLoader(targetSize) { loadedImage in
            guard let loadedImage else { return }
            Task { @MainActor in
                let scaledImage = self.scaledImageToFit(loadedImage, geometrySize: geometrySize)
                self.currentImage = scaledImage
            }
        }
    }
}

