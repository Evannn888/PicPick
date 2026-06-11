# PicPick

Ultra-fast native photo viewer for iPhone — faster than Apple Photos for browsing large libraries (100k+ photos).

## Architecture

```
PicPick/
├── App/                    # Entry point + SwiftData container
│   └── PicPickApp.swift
├── Models/                 # Domain types
│   ├── PhotoAsset.swift    # Sendable PHAsset wrapper
│   └── FavoritePhoto.swift # SwiftData @Model
├── ViewModels/             # MVVM state layer (@Observable)
│   ├── PhotoGridViewModel.swift
│   ├── PhotoViewerViewModel.swift
│   └── FavoritesViewModel.swift
├── Views/                  # UI layer
│   ├── ContentView.swift           # Root: grid ↔ viewer
│   ├── PhotoGridView.swift         # LazyVGrid (3 columns)
│   ├── PhotoGridCell.swift         # Thumbnail cell
│   ├── PhotoViewer.swift           # Full-screen pager
│   ├── PhotoCellView.swift         # Single zoomable page
│   ├── PhotoPageViewController.swift # UIPageViewController (UIKit)
│   └── ZoomableScrollView.swift    # Pinch + double-tap zoom (UIKit)
├── Services/               # Business logic
│   ├── PhotoLibraryService.swift   # PHFetchResult + PHCachingImageManager
│   ├── ImageLoadingService.swift   # Progressive image loading
│   ├── ImageCacheService.swift     # High-level NSCache wrapper
│   └── PersistenceService.swift    # UserDefaults for resume
├── Cache/
│   └── ImageCache.swift            # Low-level cache primitive
└── Persistence/
```

### Layers

| Layer | Responsibility | Key Technology |
|---|---|---|
| **Views** | Declarative UI, gestures, transitions | SwiftUI + UIKit representables |
| **ViewModels** | Observable state, navigation, prefetch coordination | `@Observable` (Swift 6) |
| **Services** | Photo library access, image loading, caching | `PHCachingImageManager`, `NSCache` |
| **Cache** | Pure in-memory cache primitive | `NSCache` with cost-based eviction |
| **Persistence** | Favorites (SwiftData), settings (UserDefaults) | SwiftData `@Model`, `UserDefaults` |

### Why UIKit for performance-critical paths?

- **UIPageViewController**: Sub-16ms swipe latency via native `.scroll` transition. SwiftUI's `TabView(style: .page)` does not match this performance for large datasets.
- **UIScrollView zoom**: Pinch-to-zoom and double-tap zoom are native UIScrollView features with zero-frame-drop performance. Replicating this in pure SwiftUI would introduce gesture lag.

### Data Flow

```
Photo Library (PHAsset)
    │
    ▼
PhotoLibraryService ─── PHCachingImageManager (prefetch ±10 images)
    │
    ▼
PhotoAsset[] ─── ViewModels (@Observable)
    │
    ├──► PhotoGridView (thumbnails)
    │        │
    │        ▼
    │    PhotoGridCell ─── PHImageRequest (fast format)
    │
    └──► PhotoViewer (full screen)
             │
             ├── PhotoPageViewController (UIPageViewController)
             │        │
             │        ▼
             └── PhotoCellView ─── ZoomableScrollView
                      │
                      ▼
              Progressive Load: thumbnail → full quality
```

## Performance

| Metric | Target | Approach |
|---|---|---|
| Viewer open transition | < 100ms | Pre-cached thumbnail delivered instantly |
| Swipe latency | < 16ms/frame | Native UIPageViewController scroll |
| Library size support | 100k+ photos | PHFetchResult with batched enumeration |
| Memory usage | < 500 MB | NSCache cost-based eviction |
| Prefetch window | ±10 images | PHCachingImageManager opportunistic |

### Progressive Loading

1. **Cache hit** (instant): NSCache → display immediately.
2. **Thumbnail** (~5-20ms): `fastFormat` request from Photos' own cache.
3. **Full quality** (~50-200ms): Asynchronous `highQualityFormat` request, replaces thumbnail on arrival.

## Requirements

- iOS 18+
- Xcode 16+
- Swift 6

## Setup

1. Open `PicPick.xcodeproj` in Xcode 16+.
2. Select your development team in Signing & Capabilities.
3. Build and run on iPhone (simulator has limited photo library).

## License

MIT
