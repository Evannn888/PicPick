import UIKit
import SwiftUI

/// UIKit UIScrollView subclass with pinch-to-zoom and double-tap-to-zoom.
/// Wrapped for SwiftUI via UIViewRepresentable.
final class ZoomableScrollView: UIScrollView {

    // MARK: - Subviews

    let imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.clipsToBounds = true
        iv.isUserInteractionEnabled = true
        return iv
    }()

    // MARK: - Callbacks

    var onSingleTap: (() -> Void)?
    var onZoomDidChange: ((CGFloat) -> Void)?

    // MARK: - State

    private var isZoomed: Bool {
        zoomScale > minimumZoomScale + 0.01
    }

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        delegate = self
        showsHorizontalScrollIndicator = false
        showsVerticalScrollIndicator = false
        alwaysBounceVertical = false
        alwaysBounceHorizontal = false
        bouncesZoom = true
        decelerationRate = .fast
        contentInsetAdjustmentBehavior = .never

        // Zoom range: from fit-to-screen up to 5×.
        minimumZoomScale = 1.0
        maximumZoomScale = 5.0

        // Add image view
        imageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageView)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])

        // Gestures
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        addGestureRecognizer(doubleTap)

        let singleTap = UITapGestureRecognizer(target: self, action: #selector(handleSingleTap(_:)))
        singleTap.numberOfTapsRequired = 1
        singleTap.require(toFail: doubleTap)
        addGestureRecognizer(singleTap)
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        centerImage()
    }

    /// Keep the image centered when zoomed out.
    private func centerImage() {
        let boundsSize = bounds.size
        var frameToCenter = imageView.frame

        if frameToCenter.size.width < boundsSize.width {
            frameToCenter.origin.x = (boundsSize.width - frameToCenter.size.width) / 2
        } else {
            frameToCenter.origin.x = 0
        }

        if frameToCenter.size.height < boundsSize.height {
            frameToCenter.origin.y = (boundsSize.height - frameToCenter.size.height) / 2
        } else {
            frameToCenter.origin.y = 0
        }

        imageView.frame = frameToCenter
    }

    // MARK: - Gestures

    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        if isZoomed {
            setZoomScale(minimumZoomScale, animated: true)
        } else {
            let location = gesture.location(in: imageView)
            let zoomRect = zoomRectForScale(maximumZoomScale * 0.5, center: location)
            zoom(to: zoomRect, animated: true)
        }
    }

    @objc private func handleSingleTap(_ gesture: UITapGestureRecognizer) {
        onSingleTap?()
    }

    private func zoomRectForScale(_ scale: CGFloat, center: CGPoint) -> CGRect {
        var zoomRect = CGRect.zero
        zoomRect.size.width = imageView.frame.size.width / scale
        zoomRect.size.height = imageView.frame.size.height / scale
        zoomRect.origin.x = center.x - (zoomRect.size.width / 2.0)
        zoomRect.origin.y = center.y - (zoomRect.size.height / 2.0)
        return zoomRect
    }

    // MARK: - Image Management

    func setImage(_ image: UIImage?) {
        imageView.image = image

        // Update zoom scale to fit if we have a new image
        if let image {
            let widthScale = bounds.width / image.size.width
            let heightScale = bounds.height / image.size.height
            let minScale = min(widthScale, heightScale)

            minimumZoomScale = minScale
            zoomScale = minScale

            // Size the image view to the image
            imageView.frame = CGRect(origin: .zero, size: image.size)
        }

        centerImage()
    }

    func resetZoom() {
        setZoomScale(minimumZoomScale, animated: false)
    }
}

// MARK: - UIScrollViewDelegate

extension ZoomableScrollView: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        imageView
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        centerImage()
        onZoomDidChange?(scrollView.zoomScale)
    }

    func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        onZoomDidChange?(scale)
    }
}

// MARK: - SwiftUI Wrapper

/// SwiftUI representable wrapper around ZoomableScrollView.
struct ZoomableScrollViewRepresentable: UIViewRepresentable {
    let image: UIImage?
    let onSingleTap: () -> Void
    let onZoomChange: (CGFloat) -> Void

    func makeUIView(context: Context) -> ZoomableScrollView {
        let scrollView = ZoomableScrollView()
        scrollView.onSingleTap = onSingleTap
        scrollView.onZoomDidChange = onZoomChange
        return scrollView
    }

    func updateUIView(_ uiView: ZoomableScrollView, context: Context) {
        // Only set a new image if it actually changed (avoids flicker).
        if uiView.imageView.image != image {
            uiView.setImage(image)
        }
        uiView.onSingleTap = onSingleTap
        // Defer to avoid "Modifying state during view update" — scroll view
        // delegate callbacks can fire during setImage/layout, which is inside
        // SwiftUI's view update cycle.
        uiView.onZoomDidChange = { scale in
            DispatchQueue.main.async { onZoomChange(scale) }
        }
    }
}
