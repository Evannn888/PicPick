import SwiftUI

/// A single cell in the photo grid with cached thumbnail loading.
struct PhotoGridCell: View {
    let file: ImageFile
    let isFavorited: Bool
    let cellSize: CGSize
    let onTap: () -> Void
    let onFavoriteToggle: () -> Void

    @State private var thumbnail: UIImage?

    private var cacheKey: String { "\(file.id)_thumb" }

    var body: some View {
        ZStack {
            if let thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: cellSize.width, height: cellSize.height)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: cellSize.width, height: cellSize.height)
            }

            if isFavorited {
                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: "heart.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.red)
                            .padding(4)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                            .padding(4)
                    }
                    Spacer()
                }
            }

            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { onTap() }
        }
        .frame(width: cellSize.width, height: cellSize.height)
        .task(id: file.id) {
            // Check memory cache first
            if let cached = ImageCacheService.shared.image(for: cacheKey) {
                thumbnail = cached
                return
            }

            // Load thumbnail from disk
            let thumb = await Task.detached(priority: .medium) {
                ImageLoadingService.loadThumbnail(from: file.url, targetSize: cellSize)
            }.value

            guard !Task.isCancelled, let thumb else { return }

            ImageCacheService.shared.setImage(thumb, for: cacheKey)
            self.thumbnail = thumb
        }
    }
}
