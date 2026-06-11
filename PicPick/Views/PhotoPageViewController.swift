import UIKit
import SwiftUI

/// UIPageViewController-based photo pager for sub-16ms swipe latency.
final class PhotoPageViewController: UIPageViewController {

    // MARK: - Types

    typealias PhotoProvider = (Int) -> ImageFile?
    typealias ImageLoader = (ImageFile, CGSize, @escaping @Sendable (UIImage?) -> Void) -> Void

    // MARK: - Data

    private let totalCount: Int
    private var currentIndex: Int
    private let photoProvider: PhotoProvider
    private let imageLoader: ImageLoader

    // MARK: - Callbacks

    var onPageChanged: ((Int) -> Void)?
    var onSingleTap: (() -> Void)?

    // MARK: - Init

    init(
        startIndex: Int,
        totalCount: Int,
        photoProvider: @escaping PhotoProvider,
        imageLoader: @escaping ImageLoader
    ) {
        self.currentIndex = startIndex
        self.totalCount = totalCount
        self.photoProvider = photoProvider
        self.imageLoader = imageLoader

        super.init(
            transitionStyle: .scroll,
            navigationOrientation: .horizontal,
            options: [.interPageSpacing: 20]
        )
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        dataSource = self
        delegate = self
        view.backgroundColor = UIColor.clear

        if let initialVC = viewControllerForPage(at: currentIndex) {
            setViewControllers([initialVC], direction: .forward, animated: false)
        }
    }

    // MARK: - Page Factory

    private func viewControllerForPage(at index: Int) -> UIViewController? {
        guard index >= 0, index < totalCount else { return nil }
        guard let file = photoProvider(index) else { return nil }

        let pageView = PhotoCellView(
            file: file,
            imageLoader: { [weak self] (targetSize: CGSize, completion: @escaping @Sendable (UIImage?) -> Void) in
                self?.imageLoader(file, targetSize, completion)
            },
            onSingleTap: { [weak self] in
                self?.onSingleTap?()
            }
        )

        let hosting = UIHostingController(rootView: pageView)
        hosting.view.backgroundColor = UIColor.clear
        hosting.view.tag = index
        return hosting
    }

    // MARK: - Public

    func goToPage(_ index: Int, animated: Bool = false) {
        guard index != currentIndex, index >= 0, index < totalCount else { return }
        guard let vc = viewControllerForPage(at: index) else { return }
        let direction: NavigationDirection = index > currentIndex ? .forward : .reverse
        currentIndex = index
        setViewControllers([vc], direction: direction, animated: animated) { [weak self] _ in
            self?.onPageChanged?(index)
        }
    }
}

// MARK: - UIPageViewControllerDataSource

extension PhotoPageViewController: UIPageViewControllerDataSource {
    func pageViewController(_ pageViewController: UIPageViewController,
                            viewControllerBefore viewController: UIViewController) -> UIViewController? {
        viewControllerForPage(at: viewController.view.tag - 1)
    }

    func pageViewController(_ pageViewController: UIPageViewController,
                            viewControllerAfter viewController: UIViewController) -> UIViewController? {
        viewControllerForPage(at: viewController.view.tag + 1)
    }
}

// MARK: - UIPageViewControllerDelegate

extension PhotoPageViewController: UIPageViewControllerDelegate {
    func pageViewController(_ pageViewController: UIPageViewController,
                            didFinishAnimating finished: Bool,
                            previousViewControllers: [UIViewController],
                            transitionCompleted completed: Bool) {
        guard completed, let currentVC = viewControllers?.first else { return }
        let newIndex = currentVC.view.tag
        currentIndex = newIndex
        onPageChanged?(newIndex)
    }
}

// MARK: - SwiftUI Wrapper

struct PhotoPageView: UIViewControllerRepresentable {
    let startIndex: Int
    let totalCount: Int
    let photoProvider: (Int) -> ImageFile?
    let imageLoader: (ImageFile, CGSize, @escaping @Sendable (UIImage?) -> Void) -> Void

    let onPageChanged: (Int) -> Void
    let onSingleTap: () -> Void

    func makeUIViewController(context: Context) -> PhotoPageViewController {
        let pager = PhotoPageViewController(
            startIndex: startIndex,
            totalCount: totalCount,
            photoProvider: photoProvider,
            imageLoader: imageLoader
        )
        pager.onPageChanged = onPageChanged
        pager.onSingleTap = onSingleTap
        return pager
    }

    func updateUIViewController(_ uiViewController: PhotoPageViewController, context: Context) {}
}
