import SwiftUI

/// Lightweight wrapper to avoid making `Int` globally `Identifiable`.
struct PhotoIndex: Identifiable, Equatable {
    let id: Int
    init(_ index: Int) { self.id = index }
}

/// Root view of PicPick. Handles grid ↔ viewer transitions.
struct ContentView: View {
    @Environment(PhotoGridViewModel.self) private var gridViewModel

    @State private var selectedPhotoIndex: PhotoIndex?
    @State private var viewerViewModel: PhotoViewerViewModel?
    @State private var showPickerOnEmpty = false

    var body: some View {
        NavigationStack {
            ZStack {
                PhotoGridView(onPhotoTap: { index in
                    selectedPhotoIndex = PhotoIndex(index)
                })
                .navigationTitle("PicPick")
                .navigationBarTitleDisplayMode(.large)
            }
            .fullScreenCover(item: $selectedPhotoIndex) { photoIndex in
                viewerView(for: photoIndex.id)
            }
        }
        .task {
            await gridViewModel.loadInitialDirectory()

            // If still empty after loading, show picker automatically
            if gridViewModel.imageFiles.isEmpty {
                showPickerOnEmpty = true
            }
        }
        .onChange(of: selectedPhotoIndex) { _, newValue in
            if newValue == nil { viewerViewModel = nil }
        }
    }

    @ViewBuilder
    private func viewerView(for index: Int) -> some View {
        let vm = PhotoViewerViewModel(
            imageFiles: gridViewModel.imageFiles,
            initialIndex: index,
            imageLoadingService: ImageLoadingService()
        )

        PhotoViewer()
            .environment(vm)
            .onAppear {
                viewerViewModel = vm
                let screenSize = UIScreen.main.bounds.size
                let targetSize = CGSize(
                    width: screenSize.width * UIScreen.main.scale,
                    height: screenSize.height * UIScreen.main.scale
                )
                vm.updatePrefetching(targetSize: targetSize)
            }
    }
}

