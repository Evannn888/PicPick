import SwiftUI

/// Full-screen photo viewer with paging, zoom, and swipe-to-dismiss.
struct PhotoViewer: View {
    @Environment(PhotoViewerViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss

    @State private var dragOffset: CGSize = .zero
    @State private var backgroundOpacity: Double = 1.0

    var body: some View {
        ZStack {
            Color.black
                .opacity(backgroundOpacity)
                .ignoresSafeArea()

            PhotoPageView(
                startIndex: viewModel.currentIndex,
                totalCount: viewModel.imageFiles.count,
                photoProvider: { viewModel.file(at: $0) },
                imageLoader: { file, size, completion in
                    loadProgressiveImage(for: file, targetSize: size, completion: completion)
                },
                onPageChanged: { newIndex in
                    viewModel.goTo(index: newIndex)
                },
                onSingleTap: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.isChromeVisible.toggle()
                    }
                }
            )
            .ignoresSafeArea()

            if viewModel.isChromeVisible {
                chromeOverlay
                    .transition(.opacity)
            }
        }
        .gesture(dismissGesture)
        .offset(y: dragOffset.height)
        .onAppear { viewModel.isPresented = true }
        .onDisappear { viewModel.prepareForDismiss() }
    }

    // MARK: - Chrome

    private var chromeOverlay: some View {
        VStack {
            HStack {
                Button {
                    viewModel.prepareForDismiss()
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(10)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }

                Spacer()

                Text("\(viewModel.currentIndex + 1) of \(viewModel.imageFiles.count)")
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 16)
            .padding(.top, 56)

            Spacer()
        }
    }

    // MARK: - Dismiss Gesture

    private var dismissGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                guard viewModel.currentZoomScale <= 1.05 else { return }
                guard abs(value.translation.height) > abs(value.translation.width) else { return }

                dragOffset = value.translation
                let progress = min(1.0, abs(dragOffset.height) / 300.0)
                backgroundOpacity = 1.0 - progress * 0.6
                viewModel.dismissProgress = progress
            }
            .onEnded { value in
                let velocity = abs(value.predictedEndTranslation.height)
                if abs(dragOffset.height) > 150 || velocity > 800 {
                    viewModel.prepareForDismiss()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        backgroundOpacity = 0
                        dragOffset.height = dragOffset.height > 0 ? 800 : -800
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { dismiss() }
                } else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        dragOffset = .zero
                        backgroundOpacity = 1.0
                        viewModel.dismissProgress = 0
                    }
                }
            }
    }

    // MARK: - Image Loading

    private func loadProgressiveImage(
        for file: ImageFile,
        targetSize: CGSize,
        completion: @escaping @Sendable (UIImage?) -> Void
    ) {
        let loadingService = ImageLoadingService()

        loadingService.loadImage(for: file, targetSize: targetSize, onStage: { stage in
            switch stage {
            case .cached(let image), .thumbnail(let image):
                completion(image)
            case .fullQuality(let image):
                completion(image)
            }
        })
    }
}
