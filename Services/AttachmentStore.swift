//
//  AttachmentStore.swift
//  muna
//
//  Created by Minaya Yagubova on 04.11.26.
//

import Foundation

#if canImport(UIKit)
import UIKit
#endif

enum AttachmentStoreError: LocalizedError {
    case unreadableSource
    case unsupportedType
    case tooLarge(limitMB: Int)

    var errorDescription: String? {
        switch self {
        case .unreadableSource:
            return NSLocalizedString("That file could not be read.", comment: "Attachment error")
        case .unsupportedType:
            return NSLocalizedString("Only images and PDF files can be attached.", comment: "Attachment error")
        case .tooLarge(let limit):
            return String(
                format: NSLocalizedString("Attachments must be under %d MB.", comment: "Attachment error"),
                limit
            )
        }
    }
}

/// Stores bill photos and documents as files under `Documents/Attachments`.
///
/// App state keeps only the reference. That keeps the state file small and fast
/// to rewrite, at the cost of the JSON backup not carrying the bytes -- which
/// Settings says out loud rather than letting the user discover it on restore.
enum AttachmentStore {
    static let maximumSizeMB = 25

    nonisolated static var directory: URL {
        let documents = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)
            .first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return documents.appendingPathComponent("Attachments", isDirectory: true)
    }

    nonisolated static func url(for attachment: Attachment) -> URL {
        directory.appendingPathComponent(attachment.fileName)
    }

    nonisolated static func exists(_ attachment: Attachment) -> Bool {
        FileManager.default.fileExists(atPath: url(for: attachment).path)
    }

    @discardableResult
    static func store(
        data: Data,
        kind: AttachmentKind,
        displayName: String
    ) throws -> Attachment {
        guard !data.isEmpty else { throw AttachmentStoreError.unreadableSource }
        guard data.count <= maximumSizeMB * 1_024 * 1_024 else {
            throw AttachmentStoreError.tooLarge(limitMB: maximumSizeMB)
        }

        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        let id = UUID()
        let fileName = "\(id.uuidString).\(kind == .pdf ? "pdf" : "jpg")"
        let destination = directory.appendingPathComponent(fileName)
        try data.write(to: destination, options: .atomic)

        // Bills can show account numbers, so keep them unreadable while locked.
        #if canImport(UIKit)
        try? FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.completeUnlessOpen],
            ofItemAtPath: destination.path
        )
        #endif

        return Attachment(
            id: id,
            fileName: fileName,
            kind: kind,
            displayName: displayName.isEmpty ? fileName : displayName
        )
    }

    /// Reads a picked file, converting images to JPEG so a 40 MB HEIC does not
    /// end up sitting in Documents untouched.
    static func store(contentsOf source: URL) throws -> Attachment {
        let didAccess = source.startAccessingSecurityScopedResource()
        defer {
            if didAccess { source.stopAccessingSecurityScopedResource() }
        }

        guard let data = try? Data(contentsOf: source) else {
            throw AttachmentStoreError.unreadableSource
        }

        let extensionName = source.pathExtension.lowercased()
        if extensionName == "pdf" {
            return try store(data: data, kind: .pdf, displayName: source.lastPathComponent)
        }

        #if canImport(UIKit)
        guard let image = UIImage(data: data) else {
            throw AttachmentStoreError.unsupportedType
        }
        return try store(
            data: compressed(image),
            kind: .image,
            displayName: source.lastPathComponent
        )
        #else
        throw AttachmentStoreError.unsupportedType
        #endif
    }

    static func delete(_ attachment: Attachment) {
        try? FileManager.default.removeItem(at: url(for: attachment))
    }

    static func delete(_ attachments: [Attachment]) {
        attachments.forEach(delete)
    }

    /// Removes files no entry references any more. Called after deletes so
    /// abandoned bill photos do not quietly fill up the device.
    static func pruneOrphans(keeping referenced: Set<String>) {
        guard let names = try? FileManager.default.contentsOfDirectory(
            atPath: directory.path
        ) else {
            return
        }
        for name in names where !referenced.contains(name) {
            try? FileManager.default.removeItem(at: directory.appendingPathComponent(name))
        }
    }

    #if canImport(UIKit)
    static func store(image: UIImage, displayName: String) throws -> Attachment {
        try store(data: compressed(image), kind: .image, displayName: displayName)
    }

    /// Caps the long edge at 2000pt, which is ample for reading a bill.
    private static func compressed(_ image: UIImage) -> Data {
        let maximumEdge: CGFloat = 2_000
        let longest = max(image.size.width, image.size.height)

        guard longest > maximumEdge, longest > 0 else {
            return image.jpegData(compressionQuality: 0.8) ?? Data()
        }

        let scale = maximumEdge / longest
        let target = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: target)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return resized.jpegData(compressionQuality: 0.8) ?? Data()
    }
    #endif
}
