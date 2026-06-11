import Foundation
import ImageIO

/// A file-system–based image. Pixel dimensions are resolved lazily to avoid I/O during scanning.
struct ImageFile: Identifiable, Hashable, Sendable {
    let id: String
    let url: URL
    let fileName: String
    let fileSize: Int64
    let modificationDate: Date?

    /// Lazily cached pixel dimensions (uses OS fast header read).
    private var _pixelWidth: Int??
    private var _pixelHeight: Int??

    var pixelWidth: Int? {
        mutating get {
            if _pixelWidth == nil { resolveDimensions() }
            return _pixelWidth ?? nil
        }
        set { _pixelWidth = newValue }
    }

    var pixelHeight: Int? {
        mutating get {
            if _pixelHeight == nil { resolveDimensions() }
            return _pixelHeight ?? nil
        }
        set { _pixelHeight = newValue }
    }

    // MARK: - Init

    init(url: URL) {
        let resourceValues = (try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey]))
        self.init(url: url, prefetchedResourceValues: resourceValues)
    }

    /// Preferred initializer when resource values have already been fetched (e.g. by
    /// the directory enumerator's `includingPropertiesForKeys`), avoiding a redundant stat().
    init(url: URL, prefetchedResourceValues resourceValues: URLResourceValues?) {
        self.id = url.absoluteString
        self.url = url
        self.fileName = url.lastPathComponent
        self.fileSize = Int64(resourceValues?.fileSize ?? 0)
        self.modificationDate = resourceValues?.contentModificationDate

        // Defer dimension reads — expensive I/O, not needed for grid display.
        self._pixelWidth = nil
        self._pixelHeight = nil
    }

    // MARK: - Hashable

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: ImageFile, rhs: ImageFile) -> Bool { lhs.id == rhs.id }

    // MARK: - Private

    private mutating func resolveDimensions() {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
            _pixelWidth = .some(nil)
            _pixelHeight = .some(nil)
            return
        }
        _pixelWidth = .some(props[kCGImagePropertyPixelWidth] as? Int)
        _pixelHeight = .some(props[kCGImagePropertyPixelHeight] as? Int)
    }
}
