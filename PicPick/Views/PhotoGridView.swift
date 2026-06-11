import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

/// Scrollable grid of photos using LazyVGrid.
struct PhotoGridView: View {
    @Environment(PhotoGridViewModel.self) private var viewModel
    let onPhotoTap: (Int) -> Void

    @State private var showingFolderPicker = false
    @State private var showingImagePicker = false
    @State private var showingPhotoImport = false
    @State private var selectedPhotoItems: [PhotosPickerItem] = []

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 1), count: 3)

    var body: some View {
        GeometryReader { geometry in
            let cellSize = (geometry.size.width - 2) / 3

            if viewModel.imageFiles.isEmpty && !viewModel.isLoading {
                emptyStateView
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.vertical) {
                        LazyVGrid(columns: columns, spacing: 1) {
                            ForEach(Array(viewModel.imageFiles.enumerated()), id: \.element.id) { index, file in
                                PhotoGridCell(
                                    file: file,
                                    isFavorited: viewModel.favoriteIdentifiers.contains(file.id),
                                    cellSize: CGSize(width: cellSize, height: cellSize),
                                    onTap: { onPhotoTap(index) },
                                    onFavoriteToggle: { viewModel.toggleFavorite(file.id) }
                                )
                                .id(index)
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                    .task {
                        if let resumeIndex = viewModel.resumeIndex {
                            proxy.scrollTo(resumeIndex, anchor: .center)
                        }
                    }
                }
            }

            if viewModel.isLoading {
                ProgressView("Loading images…")
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if !viewModel.imageFiles.isEmpty {
                    Button {
                        viewModel.clearAndStartFresh()
                    } label: {
                        Image(systemName: "house")
                    }
                    .disabled(viewModel.isLoading)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await viewModel.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(viewModel.isLoading)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { showingFolderPicker = true } label: {
                        Label("Open Folder", systemImage: "folder.badge.plus")
                    }
                    Button { showingImagePicker = true } label: {
                        Label("Import Files", systemImage: "doc.badge.plus")
                    }
                    Button { showingPhotoImport = true } label: {
                        Label("Import from Photos", systemImage: "photo.on.rectangle")
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingFolderPicker) {
            FolderPicker { url in
                Task { await viewModel.loadFromUserDirectory(url) }
            }
        }
        .sheet(isPresented: $showingImagePicker) {
            ImageFilePicker { urls in
                Task { await importFiles(urls) }
            }
        }
        .photosPicker(isPresented: $showingPhotoImport, selection: $selectedPhotoItems, maxSelectionCount: 100, matching: .images)
        .onChange(of: selectedPhotoItems) { _, items in
            guard !items.isEmpty else { return }
            Task { await importFromPhotos(items) }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text("No Photos Yet")
                .font(.title3.weight(.semibold))

            VStack(spacing: 12) {
                emptyStateButton(
                    icon: "photo.on.rectangle",
                    title: "Import from Photos",
                    subtitle: "Copy images from your photo library",
                    action: { showingPhotoImport = true }
                )
                emptyStateButton(
                    icon: "folder.badge.plus",
                    title: "Open Folder",
                    subtitle: "Browse to a folder with images",
                    action: { showingFolderPicker = true }
                )
                emptyStateButton(
                    icon: "doc.badge.plus",
                    title: "Import Files",
                    subtitle: "Select individual image files",
                    action: { showingImagePicker = true }
                )
            }
            .padding(.horizontal)
        }
        .padding()
    }

    private func emptyStateButton(icon: String, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.subheadline.weight(.medium))
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Import Helpers

    private func importFiles(_ urls: [URL]) async {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        for url in urls {
            guard url.startAccessingSecurityScopedResource() else { continue }
            defer { url.stopAccessingSecurityScopedResource() }
            let dest = docs.appendingPathComponent(url.lastPathComponent)
            try? FileManager.default.copyItem(at: url, to: dest)
        }
        await viewModel.reloadFromDocuments()
    }

    private func importFromPhotos(_ items: [PhotosPickerItem]) async {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
            let filename = "Photo_\(UUID().uuidString.prefix(8)).jpg"
            let dest = docs.appendingPathComponent(filename)
            try? data.write(to: dest)
        }
        selectedPhotoItems = []
        await viewModel.reloadFromDocuments()
    }
}

// MARK: - Pickers

struct FolderPicker: UIViewControllerRepresentable {
    let onPick: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        init(onPick: @escaping (URL) -> Void) { self.onPick = onPick }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            onPick(url)
        }
    }
}

struct ImageFilePicker: UIViewControllerRepresentable {
    let onPick: ([URL]) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let types = [UTType.image]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types)
        picker.allowsMultipleSelection = true
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: ([URL]) -> Void
        init(onPick: @escaping ([URL]) -> Void) { self.onPick = onPick }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            onPick(urls)
        }
    }
}
