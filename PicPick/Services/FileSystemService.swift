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

    /// Import logic removed in favor of streaming directly from the USB drive.
    /// This keeps the app fast and prevents filling up internal storage.
    func scanDocumentsDirectory() async {
        // Fallback for empty state
    }

    private var activeDirectoryURL: URL?

    /// Sets the active directory and maintains security-scoped access for USB drives.
    func setActiveDirectory(_ url: URL?) {
        activeDirectoryURL?.stopAccessingSecurityScopedResource()
        activeDirectoryURL = nil
        
        if let url = url, url.startAccessingSecurityScopedResource() {
            activeDirectoryURL = url
        }
    }

    nonisolated func streamPhotos(directory url: URL) -> AsyncStream<[ImageFile]> {
        AsyncStream { continuation in
            Task.detached(priority: .userInitiated) {
                // Get volume UUID or fallback to URL string if missing
                let resourceValues = try? url.resourceValues(forKeys: [.volumeIdentifierKey])
                let volumeUUID = (resourceValues?.volumeIdentifier as? String) ?? url.absoluteString
                
                // 1. Check Database Index
                let cachedFiles = await USBIndexDatabase.shared.fetchIndexedFiles(for: volumeUUID)
                if !cachedFiles.isEmpty {
                    let chunkSize = 100
                    var current = 0
                    while current < cachedFiles.count {
                        if Task.isCancelled { break }
                        let end = min(current + chunkSize, cachedFiles.count)
                        continuation.yield(Array(cachedFiles[current..<end]))
                        current = end
                        await Task.yield()
                    }
                    continuation.finish()
                    return
                }

                // 2. Perform File System Scan
                let fm = FileManager.default
                guard let enumerator = fm.enumerator(
                    at: url,
                    includingPropertiesForKeys: Self.prefetchKeys,
                    options: [.skipsHiddenFiles, .skipsPackageDescendants]
                ) else {
                    continuation.finish()
                    return
                }

                var batch: [ImageFile] = []
                var allFiles: [ImageFile] = []
                batch.reserveCapacity(100)

                for case let fileURL as URL in enumerator {
                    if Task.isCancelled { break }
                    guard Self.isImageFile(fileURL) else { continue }
                    
                    let values = try? fileURL.resourceValues(forKeys: Set(Self.prefetchKeys))
                    let file = ImageFile(url: fileURL, fileSize: Int64(values?.fileSize ?? 0), modificationDate: values?.contentModificationDate)
                    
                    batch.append(file)
                    allFiles.append(file)

                    if batch.count >= 100 {
                        continuation.yield(batch)
                        batch = []
                        await Task.yield()
                    }
                }

                if !batch.isEmpty && !Task.isCancelled {
                    continuation.yield(batch)
                }
                
                // 3. Save to database for next time
                if !Task.isCancelled {
                    await USBIndexDatabase.shared.indexFiles(allFiles, volumeUUID: volumeUUID)
                }
                
                continuation.finish()
            }
        }
    }

    /// Delete all imported files and reset state.
    func reset() {
        setActiveDirectory(nil)
        imageFiles = []
        errorMessage = nil
    }

    func refresh() async {
        await scanDocumentsDirectory()
    }

    // MARK: - Off-main-actor Helpers

    /// Resource keys to prefetch during directory enumeration to avoid per-file stat() calls.
    nonisolated private static let prefetchKeys: [URLResourceKey] = [
        .fileSizeKey, .contentModificationDateKey, .volumeIdentifierKey
    ]
    
    nonisolated private static func isImageFile(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        guard supportedExtensions.contains(ext) else { return false }
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) && !isDir.boolValue
    }
}
actor USBIndexDatabase {
    static let shared = USBIndexDatabase()
    private let fileURL: URL
    
    // In-memory cache of the index
    private var index: [String: [ImageFile]] = [:]
    
    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        fileURL = appSupport.appendingPathComponent("usb_index.json")
        
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([String: [ImageFile]].self, from: data) {
            self.index = decoded
        } else {
            self.index = [:]
        }
    }
    
    private func saveToDisk() {
        guard let data = try? JSONEncoder().encode(index) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
    
    func indexFiles(_ files: [ImageFile], volumeUUID: String) {
        index[volumeUUID] = files
        // Fire and forget save
        Task.detached { await self.saveToDisk() }
    }
    
    func fetchIndexedFiles(for volumeUUID: String) -> [ImageFile] {
        return index[volumeUUID] ?? []
    }
}
