import PhotosUI
import SwiftUI

/// One paperclip and the thumbnails beside it.
///
/// The choice between a photo and a document lives in the paperclip's menu, so
/// the form carries a single icon rather than two labelled buttons.
struct AttachmentStripView: View {
    @Binding var attachments: [Attachment]
    var isEditable: Bool = true

    @State private var photoSelection: [PhotosPickerItem] = []
    @State private var isShowingPhotoPicker = false
    @State private var isShowingFileImporter = false
    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var previewAttachment: Attachment?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                if isEditable {
                    attachButton
                }

                if attachments.isEmpty {
                    if isEditable {
                        Text("Attach a bill")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(attachments) { attachment in
                                thumbnail(attachment)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .scrollClipDisabled()
                }

                Spacer(minLength: 0)
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
        .sheet(item: $previewAttachment) { attachment in
            AttachmentPreviewView(attachment: attachment)
        }
    }

    private var attachButton: some View {
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
            ZStack {
                if isWorking {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "paperclip")
                        .font(.body.weight(.medium))
                }
            }
            .frame(width: AppTheme.minimumTapTarget, height: AppTheme.minimumTapTarget)
            .background(
                AppTheme.cardBackground,
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
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
                        Image(systemName: attachment.kind.systemImage)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .background(
                    AppTheme.cardBackground,
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )

                if isEditable {
                    Button {
                        remove(attachment)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, .black.opacity(0.65))
                    }
                    .offset(x: 4, y: -4)
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
