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
                batch.reserveCapacity(100)

                for case let fileURL as URL in enumerator {
                    if Task.isCancelled { break }
                    guard Self.isImageFile(fileURL) else { continue }
                    
                    let values = try? fileURL.resourceValues(forKeys: Set(Self.prefetchKeys))
                    let file = ImageFile(url: fileURL, fileSize: Int64(values?.fileSize ?? 0), modificationDate: values?.contentModificationDate)
                    
                    batch.append(file)

                    if batch.count >= 100 {
                        continuation.yield(batch)
                        await USBIndexDatabase.shared.indexFiles(batch, volumeUUID: volumeUUID)
                        batch = []
                        await Task.yield()
                    }
                }

                if !batch.isEmpty && !Task.isCancelled {
                    continuation.yield(batch)
                    await USBIndexDatabase.shared.indexFiles(batch, volumeUUID: volumeUUID)
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
import SQLite3

actor USBIndexDatabase {
    static let shared = USBIndexDatabase()
    private var db: OpaquePointer?
    
    // SQLite destructor constant for Swift
    private let SQLITE_TRANSIENT = unsafeBitCast(OpaquePointer(bitPattern: -1), to: sqlite3_destructor_type.self)
    
    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let fileURL = appSupport.appendingPathComponent("usb_index.sqlite")
        
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        
        if sqlite3_open(fileURL.path, &db) == SQLITE_OK {
            let createTableString = """
            CREATE TABLE IF NOT EXISTS Photos(
            Id TEXT PRIMARY KEY,
            VolumeUUID TEXT,
            Path TEXT,
            FileSize INTEGER,
            ModificationDate REAL);
            """
            
            var statement: OpaquePointer?
            if sqlite3_prepare_v2(db, createTableString, -1, &statement, nil) == SQLITE_OK {
                sqlite3_step(statement)
            }
            sqlite3_finalize(statement)
        }
    }
    
    // Intentionally omitting deinit because the actor is a singleton and db is kept open
    
    func indexFiles(_ files: [ImageFile], volumeUUID: String) {
        sqlite3_exec(db, "BEGIN TRANSACTION", nil, nil, nil)
        
        let insertString = "INSERT OR REPLACE INTO Photos (Id, VolumeUUID, Path, FileSize, ModificationDate) VALUES (?, ?, ?, ?, ?);"
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, insertString, -1, &statement, nil) == SQLITE_OK {
            for file in files {
                let id = file.id as NSString
                let vol = volumeUUID as NSString
                let path = file.url.path as NSString
                let size = Int64(file.fileSize)
                let date = file.modificationDate?.timeIntervalSince1970 ?? 0
                
                sqlite3_bind_text(statement, 1, id.utf8String, -1, SQLITE_TRANSIENT)
                sqlite3_bind_text(statement, 2, vol.utf8String, -1, SQLITE_TRANSIENT)
                sqlite3_bind_text(statement, 3, path.utf8String, -1, SQLITE_TRANSIENT)
                sqlite3_bind_int64(statement, 4, size)
                sqlite3_bind_double(statement, 5, date)
                
                sqlite3_step(statement)
                sqlite3_reset(statement)
            }
        }
        sqlite3_finalize(statement)
        sqlite3_exec(db, "COMMIT TRANSACTION", nil, nil, nil)
    }
    
    func fetchIndexedFiles(for volumeUUID: String) -> [ImageFile] {
        let queryString = "SELECT Id, Path, FileSize, ModificationDate FROM Photos WHERE VolumeUUID = ?;"
        var statement: OpaquePointer?
        var results: [ImageFile] = []
        results.reserveCapacity(1000)
        
        if sqlite3_prepare_v2(db, queryString, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (volumeUUID as NSString).utf8String, -1, SQLITE_TRANSIENT)
            
            while sqlite3_step(statement) == SQLITE_ROW {
                guard let pathCStr = sqlite3_column_text(statement, 1) else { continue }
                let pathStr = String(cString: pathCStr)
                let size = sqlite3_column_int64(statement, 2)
                let dateDouble = sqlite3_column_double(statement, 3)
                
                let url = URL(fileURLWithPath: pathStr)
                let date = dateDouble > 0 ? Date(timeIntervalSince1970: dateDouble) : nil
                
                results.append(ImageFile(url: url, fileSize: size, modificationDate: date))
            }
        }
        sqlite3_finalize(statement)
        return results
    }
}
