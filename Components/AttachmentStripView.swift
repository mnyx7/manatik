import PhotosUI
import SwiftUI

/// Shows the bills attached to an entry and lets the user add or remove them.
///
/// Files are written to disk as soon as they are picked, so a cancelled form
/// can leave orphans; the store prunes those at launch.
struct AttachmentStripView: View {
    @Binding var attachments: [Attachment]
    var isEditable: Bool = true

    @State private var photoSelection: [PhotosPickerItem] = []
    @State private var isShowingFileImporter = false
    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var previewAttachment: Attachment?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !attachments.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(attachments) { attachment in
                            thumbnail(attachment)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .scrollClipDisabled()
            }

            if isEditable {
                HStack(spacing: 10) {
                    PhotosPicker(
                        selection: $photoSelection,
                        maxSelectionCount: 5,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        Label("Photo", systemImage: "photo.on.rectangle")
                            .font(.footnote.weight(.medium))
                            .frame(minHeight: AppTheme.minimumTapTarget)
                    }

                    Button {
                        isShowingFileImporter = true
                    } label: {
                        Label("Document", systemImage: "doc.badge.plus")
                            .font(.footnote.weight(.medium))
                            .frame(minHeight: AppTheme.minimumTapTarget)
                    }

                    if isWorking {
                        ProgressView().controlSize(.small)
                    }
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(AppTheme.expenseAccent)
            }
        }
        .onChange(of: photoSelection) { _, items in
            guard !items.isEmpty else { return }
            Task { await importPhotos(items) }
        }
        .fileImporter(
            isPresented: $isShowingFileImporter,
            allowedContentTypes: [.pdf, .image],
            allowsMultipleSelection: true
        ) { result in
            importFiles(result)
        }
        .sheet(item: $previewAttachment) { attachment in
            AttachmentPreviewView(attachment: attachment)
        }
    }

    @ViewBuilder
    private func thumbnail(_ attachment: Attachment) -> some View {
        let image = AttachmentStore.image(for: attachment)

        Button {
            previewAttachment = attachment
        } label: {
            ZStack(alignment: .topTrailing) {
                Group {
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        VStack(spacing: 4) {
                            Image(systemName: attachment.kind.systemImage)
                                .font(.title3)
                            Text(attachment.kind == .pdf ? "PDF" : "File")
                                .font(.caption2)
                        }
                        .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .background(
                    AppTheme.cardBackground,
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )

                if isEditable {
                    Button {
                        remove(attachment)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.body)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, .black.opacity(0.6))
                    }
                    .padding(3)
                    .accessibilityLabel(Text("Remove attachment"))
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(attachment.displayName))
        .accessibilityHint(Text("Opens the attachment"))
    }

    private func remove(_ attachment: Attachment) {
        attachments.removeAll { $0.id == attachment.id }
        AttachmentStore.delete(attachment)
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
                let stored = try AttachmentStore.store(
                    image: image,
                    displayName: NSLocalizedString("Bill photo", comment: "Attachment name")
                )
                attachments.append(stored)
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

/// Full-screen look at one attachment.
struct AttachmentPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    let attachment: Attachment

    var body: some View {
        NavigationStack {
            Group {
                if let image = AttachmentStore.image(for: attachment) {
                    ScrollView([.horizontal, .vertical]) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                    }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: attachment.kind.systemImage)
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text(attachment.displayName)
                            .font(.subheadline)
                        ShareLink(item: AttachmentStore.url(for: attachment)) {
                            Label("Open or share", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(.bordered)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .background(AppTheme.pageBackground)
            .navigationTitle(attachment.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
