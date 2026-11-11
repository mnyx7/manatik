import PhotosUI
import QuickLook
import QuickLookThumbnailing
import SwiftUI

// Attachments are split into two pieces on purpose. The paperclip is small
// enough to share the note line; the files themselves get their own row, where
// they are big enough to recognise and to tap. Squeezing both onto one line
// shrank the thumbnails to a sliver and made them impossible to reopen.

/// The paperclip: picks a photo or a document and shows how many are attached.
struct AttachmentButton: View {
    @Binding var attachments: [Attachment]

    @State private var photoSelection: [PhotosPickerItem] = []
    @State private var isShowingPhotoPicker = false
    @State private var isShowingFileImporter = false
    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        Menu {
            Button {
                isShowingPhotoPicker = true
            } label: {
                Label("Photo", systemImage: "photo.on.rectangle")
            }
            Button {
                isShowingFileImporter = true
            } label: {
                Label("Document", systemImage: "doc")
            }
        } label: {
            ZStack(alignment: .topTrailing) {
                if isWorking {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "paperclip")
                        .font(.body.weight(.medium))
                }
            }
            .frame(width: AppTheme.minimumTapTarget, height: AppTheme.minimumTapTarget)
            .overlay(alignment: .topTrailing) {
                if !attachments.isEmpty && !isWorking {
                    Text("\(attachments.count)")
                        .font(.caption2.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .frame(minWidth: 16, minHeight: 16)
                        .background(Color.accentColor, in: Capsule())
                        .offset(x: -4, y: 4)
                }
            }
            .contentShape(Rectangle())
        }
        .accessibilityLabel(Text("Attach a bill"))
        .accessibilityValue(
            attachments.isEmpty
                ? NSLocalizedString("none attached", comment: "Accessibility")
                : String(
                    format: NSLocalizedString("%d attached", comment: "Accessibility"),
                    attachments.count
                )
        )
        .onChange(of: photoSelection) { _, items in
            guard !items.isEmpty else { return }
            Task { await importPhotos(items) }
        }
        .photosPicker(
            isPresented: $isShowingPhotoPicker,
            selection: $photoSelection,
            maxSelectionCount: 5,
            matching: .images,
            photoLibrary: .shared()
        )
        .fileImporter(
            isPresented: $isShowingFileImporter,
            allowedContentTypes: [.pdf, .image],
            allowsMultipleSelection: true
        ) { result in
            importFiles(result)
        }
        .alert(
            "Could not attach",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func importPhotos(_ items: [PhotosPickerItem]) async {
        isWorking = true
        defer {
            isWorking = false
            photoSelection = []
        }

        for item in items {
            do {
                guard let data = try await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else {
                    continue
                }
                attachments.append(
                    try AttachmentStore.store(
                        image: image,
                        displayName: NSLocalizedString("Bill photo", comment: "Attachment name")
                    )
                )
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func importFiles(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            for url in urls {
                do {
                    attachments.append(try AttachmentStore.store(contentsOf: url))
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }
}

/// The attached files as tiles big enough to recognise. Tapping one opens the
/// system viewer, which zooms photos, renders PDFs and swipes between files.
struct AttachmentGalleryView: View {
    @Binding var attachments: [Attachment]
    var isEditable: Bool = true

    @State private var previewURL: URL?

    private static let tileSize: CGFloat = 64

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(attachments) { attachment in
                    tile(attachment)
                }
            }
            // Room for the remove badge, which sits half outside the tile.
            .padding(.top, 6)
            .padding(.trailing, 6)
        }
        .scrollClipDisabled()
        .quickLookPreview($previewURL, in: existingURLs)
    }

    private var existingURLs: [URL] {
        attachments.filter(AttachmentStore.exists).map(AttachmentStore.url(for:))
    }

    private func tile(_ attachment: Attachment) -> some View {
        let isMissing = !AttachmentStore.exists(attachment)

        return Button {
            previewURL = AttachmentStore.url(for: attachment)
        } label: {
            AttachmentThumbnail(attachment: attachment, side: Self.tileSize)
        }
        .buttonStyle(.plain)
        .disabled(isMissing)
        // A sibling of the tile, not a button inside its label, so a tap on
        // the tile opens it and a tap on the badge removes it.
        .overlay(alignment: .topTrailing) {
            if isEditable {
                Button {
                    // Only the draft changes here. The file goes when the entry
                    // is saved, so Cancel brings the attachment back.
                    attachments.removeAll { $0.id == attachment.id }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.body)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .black.opacity(0.6))
                        .frame(width: 28, height: 28)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .offset(x: 10, y: -10)
                .accessibilityLabel(Text("Remove attachment"))
            }
        }
        .contextMenu {
            if !isMissing {
                Button {
                    previewURL = AttachmentStore.url(for: attachment)
                } label: {
                    Label("Open", systemImage: "eye")
                }
                ShareLink(item: AttachmentStore.url(for: attachment)) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
            }
            if isEditable {
                Button(role: .destructive) {
                    attachments.removeAll { $0.id == attachment.id }
                } label: {
                    Label("Remove", systemImage: "trash")
                }
            }
        }
        .accessibilityLabel(Text(attachment.displayName))
        .accessibilityHint(Text(isMissing ? "File is missing" : "Opens the attachment"))
    }
}

/// A real preview of the file: the photo, or the first page of a PDF.
struct AttachmentThumbnail: View {
    let attachment: Attachment
    let side: CGFloat

    @Environment(\.displayScale) private var displayScale
    @State private var image: UIImage?
    @State private var didFail = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)

        ZStack {
            AppTheme.cardBackground

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if didFail {
                Image(systemName: AttachmentStore.exists(attachment)
                    ? attachment.kind.systemImage
                    : "exclamationmark.triangle")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            } else {
                ProgressView().controlSize(.small)
            }
        }
        .frame(width: side, height: side)
        .clipShape(shape)
        .overlay(shape.strokeBorder(.separator, lineWidth: 0.5))
        .overlay(alignment: .bottomLeading) {
            if attachment.kind == .pdf {
                Text(verbatim: "PDF")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(.black.opacity(0.55), in: Capsule())
                    .padding(4)
            }
        }
        .task(id: attachment.id) {
            image = await AttachmentStore.thumbnail(
                for: attachment,
                side: side,
                scale: displayScale
            )
            didFail = image == nil
        }
    }
}

extension AttachmentStore {
    /// Downsampled preview from QuickLook, so a list of tiles never decodes
    /// full 2000pt bill photos on the main thread, and PDFs show a page.
    nonisolated static func thumbnail(
        for attachment: Attachment,
        side: CGFloat,
        scale: CGFloat
    ) async -> UIImage? {
        let url = url(for: attachment)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }

        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: CGSize(width: side, height: side),
            scale: scale,
            representationTypes: .thumbnail
        )
        return await withCheckedContinuation { continuation in
            QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { representation, _ in
                continuation.resume(returning: representation?.uiImage)
            }
        }
    }
}
