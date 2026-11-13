//
//  AppBackupDocument.swift
//  muna
//
//  Created by Minaya Yagubova on 04.11.26.
//

import SwiftUI
import UniformTypeIdentifiers

struct AppBackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw AppStatePersistenceError.invalidFile
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
