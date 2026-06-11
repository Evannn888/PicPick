import Foundation

/// Scans and manages image files. All displayed images live in the app's Documents
/// directory so they remain accessible without security-scoped bookmarks.
@MainActor
final class FileSystemService: Sendable {

    static let shared = FileSystemService()

    // MARK: - Supported Types

    private nonisolated static let supportedExtensions: Set<String> = [
        "jpg", "jpeg", "png", "heic", "heif", "webp",
        "tiff", "tif", "bmp", "gif",
    ]

    // MARK: - State

    private(set) var imageFiles: [ImageFile] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    var onFilesDidChange: (() -> Void)?

    // MARK: - Docs Directory

    private var docsDir: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    // MARK: - Init

    private init() {}

    // MARK: - Public API

    /// Scan the Documents directory (always accessible).
    func scanDocumentsDirectory() async {
        isLoading = true
        errorMessage = nil

        let dir = docsDir  // capture before crossing actor boundary
        let files = await Task.detached(priority: .userInitiated) {
            Self.enumerateDirectory(dir)
        }.value

        imageFiles = files.sorted {
            ($0.modificationDate ?? .distantPast) > ($1.modificationDate ?? .distantPast)
        }
        isLoading = false
        onFilesDidChange?()

        if imageFiles.isEmpty {
            errorMessage = "No images found. Pick a folder or import photos."
        }
    }

    /// Copy images from a user-picked folder into Documents, then scan.
    func importFromUserDirectory(_ url: URL) async {
        guard url.startAccessingSecurityScopedResource() else {
            errorMessage = "Cannot access this directory."
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }

        isLoading = true
        errorMessage = nil

        let sourceURL = url
        let destDir = docsDir

        let count = await Task.detached(priority: .userInitiated) {
            Self.copyImages(from: sourceURL, to: destDir)
        }.value

        await scanDocumentsDirectory()

        if count == 0 {
            errorMessage = "No compatible images found in that folder."
        }
    }

    /// Delete all imported files and reset state.
    func reset() {
        if let contents = try? FileManager.default.contentsOfDirectory(at: docsDir, includingPropertiesForKeys: nil) {
            for url in contents where Self.isImageFile(url) {
                try? FileManager.default.removeItem(at: url)
            }
        }
        imageFiles = []
        errorMessage = nil
    }

    func refresh() async {
        await scanDocumentsDirectory()
    }

    // MARK: - Off-main-actor Helpers

    /// Resource keys to prefetch during directory enumeration to avoid per-file stat() calls.
    nonisolated private static let prefetchKeys: [URLResourceKey] = [
        .fileSizeKey, .contentModificationDateKey,
    ]

    nonisolated private static func enumerateDirectory(_ url: URL) -> [ImageFile] {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: prefetchKeys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }

        var results: [ImageFile] = []
        results.reserveCapacity(1000)
        let maxFiles = 200_000

        for case let fileURL as URL in enumerator {
            guard results.count < maxFiles else { break }
            guard isImageFile(fileURL) else { continue }
            let resourceValues = try? fileURL.resourceValues(forKeys: Set(prefetchKeys))
            results.append(ImageFile(url: fileURL, prefetchedResourceValues: resourceValues))
        }
        return results
    }

    nonisolated private static func copyImages(from source: URL, to dest: URL) -> Int {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: source,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return 0 }

        var copied = 0
        let maxCopy = 10_000

        for case let fileURL as URL in enumerator {
            guard copied < maxCopy else { break }
            guard isImageFile(fileURL) else { continue }

            let destURL = dest.appendingPathComponent(fileURL.lastPathComponent)
            // Skip if already exists
            if fm.fileExists(atPath: destURL.path) { continue }

            do {
                try fm.copyItem(at: fileURL, to: destURL)
                copied += 1
            } catch {
                // Skip files that can't be copied
            }
        }
        return copied
    }

    nonisolated private static func isImageFile(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        guard supportedExtensions.contains(ext) else { return false }
        // Filter out directories (e.g. folders named "photos.jpg")
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) && !isDir.boolValue
    }
}
