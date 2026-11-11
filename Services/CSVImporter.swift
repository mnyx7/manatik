import Foundation

/// One entry read from another app's CSV export.
struct CSVImportRow: Hashable {
    let date: Date
    /// Always positive; `type` carries the direction.
    let amount: Decimal
    let type: TransactionType
    let note: String
    /// First tag, used to find or create the category. Empty means Other.
    let tag: String
    let currency: String
}

/// What a CSV file holds, shown to the user before anything is added.
struct CSVImportPreview {
    let rows: [CSVImportRow]
    /// 1-based line numbers that could not be read, for the summary.
    let skippedLines: [Int]

    var firstDate: Date? { rows.map(\.date).min() }
    var lastDate: Date? { rows.map(\.date).max() }
    var tags: Set<String> { Set(rows.map(\.tag).filter { !$0.isEmpty }) }
    var currencies: Set<String> { Set(rows.map(\.currency).filter { !$0.isEmpty }) }
}

enum CSVImportError: LocalizedError {
    case unreadable
    case noHeader
    case missingColumns
    case noRows

    var errorDescription: String? {
        switch self {
        case .unreadable:
            return NSLocalizedString("That file could not be read as text.", comment: "CSV import error")
        case .noHeader:
            return NSLocalizedString("The file is empty.", comment: "CSV import error")
        case .missingColumns:
            return NSLocalizedString("The file needs at least a date column and an amount column.", comment: "CSV import error")
        case .noRows:
            return NSLocalizedString("No entries could be read from the file.", comment: "CSV import error")
        }
    }
}

/// Reads budget exports from other apps.
///
/// Expected shape, as most apps write it: a header row, then one entry per
/// row with a date, a signed amount (negative = expense) and optionally the
/// currency, tags and a note. Commas, semicolons and tabs are all accepted as
/// separators, since Excel saves with ';' in many locales.
enum CSVImporter {
    static func preview(data: Data) throws -> CSVImportPreview {
        guard var text = String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .windowsCP1251)
            ?? String(data: data, encoding: .isoLatin1) else {
            throw CSVImportError.unreadable
        }
        if text.hasPrefix("\u{FEFF}") { text.removeFirst() }

        let records = parseRecords(text, separator: detectSeparator(text))
        guard let header = records.first else { throw CSVImportError.noHeader }

        let columns = Columns(header: header)
        guard columns.date != nil, columns.amount != nil else {
            throw CSVImportError.missingColumns
        }

        var rows: [CSVImportRow] = []
        var skipped: [Int] = []
        for (offset, record) in records.dropFirst().enumerated() {
            if record.allSatisfy({ $0.trimmingCharacters(in: .whitespaces).isEmpty }) { continue }
            if let row = columns.row(from: record) {
                rows.append(row)
            } else {
                skipped.append(offset + 2)
            }
        }

        guard !rows.isEmpty else { throw CSVImportError.noRows }
        return CSVImportPreview(rows: rows, skippedLines: skipped)
    }

    // MARK: - Columns

    private struct Columns {
        var date: Int?
        var amount: Int?
        var currency: Int?
        var tags: Int?
        var note: Int?

        init(header: [String]) {
            for (index, raw) in header.enumerated() {
                let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                    .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
                func matches(_ names: [String]) -> Bool { names.contains(name) }

                if date == nil, matches(["date", "time", "datetime", "дата", "tarix", "время"]) {
                    date = index
                } else if amount == nil, matches(["amount", "sum", "value", "сумма", "mebleg", "məbləğ", "meblag"]) {
                    amount = index
                } else if currency == nil, matches(["currency", "валюта", "valyuta"]) {
                    currency = index
                } else if tags == nil, matches(["tags", "tag", "category", "categories", "категория", "теги", "kateqoriya", "teqler"]) {
                    tags = index
                } else if note == nil, matches(["note", "notes", "comment", "description", "memo", "payee", "примечание", "комментарий", "qeyd"]) {
                    note = index
                }
            }
        }

        func row(from record: [String]) -> CSVImportRow? {
            func field(_ index: Int?) -> String {
                guard let index, record.indices.contains(index) else { return "" }
                return record[index].trimmingCharacters(in: .whitespacesAndNewlines)
            }

            guard let date = CSVImporter.parseDate(field(date)),
                  let signed = CSVImporter.parseAmount(field(amount)),
                  signed != 0 else {
                return nil
            }

            let tag = field(tags)
                .split(whereSeparator: { ",;|".contains($0) })
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .first { !$0.isEmpty } ?? ""

            return CSVImportRow(
                date: date,
                amount: signed < 0 ? -signed : signed,
                type: signed < 0 ? .expense : .income,
                note: field(note),
                tag: tag,
                currency: field(currency).uppercased()
            )
        }
    }

    // MARK: - Values

    private static let dateFormats = [
        "dd.MM.yy, HH:mm", "dd.MM.yyyy, HH:mm", "dd.MM.yy HH:mm", "dd.MM.yyyy HH:mm",
        "dd.MM.yyyy", "dd.MM.yy",
        "yyyy-MM-dd'T'HH:mm:ssZ", "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd HH:mm", "yyyy-MM-dd",
        "dd/MM/yyyy HH:mm", "dd/MM/yyyy", "MM/dd/yyyy", "dd-MM-yyyy"
    ]

    private static let dateFormatters: [DateFormatter] = dateFormats.map { format in
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = format
        formatter.isLenient = false
        return formatter
    }

    static func parseDate(_ text: String) -> Date? {
        guard !text.isEmpty else { return nil }
        for formatter in dateFormatters {
            if let date = formatter.date(from: text) { return date }
        }
        return nil
    }

    /// Accepts "200.0", "-1.43", "-1,43", "1 234,50", "−12" and a stray symbol.
    static func parseAmount(_ text: String) -> Decimal? {
        var value = text
            .replacingOccurrences(of: "\u{2212}", with: "-")
            .filter { $0.isNumber || $0 == "-" || $0 == "." || $0 == "," }
        guard !value.isEmpty else { return nil }

        let lastDot = value.lastIndex(of: ".")
        let lastComma = value.lastIndex(of: ",")
        switch (lastDot, lastComma) {
        case let (dot?, comma?):
            // Whichever comes last is the decimal mark; the other groups.
            if dot > comma {
                value.removeAll { $0 == "," }
            } else {
                value.removeAll { $0 == "." }
                value = value.replacingOccurrences(of: ",", with: ".")
            }
        case (nil, _?):
            value = value.replacingOccurrences(of: ",", with: ".")
        default:
            break
        }
        return Decimal(string: value, locale: Locale(identifier: "en_US_POSIX"))
    }

    // MARK: - Records

    private static func detectSeparator(_ text: String) -> Character {
        let headerLine = text.prefix { $0 != "\n" && $0 != "\r" }
        var counts: [Character: Int] = [",": 0, ";": 0, "\t": 0]
        var inQuotes = false
        for character in headerLine {
            if character == "\"" { inQuotes.toggle() }
            if !inQuotes, counts[character] != nil { counts[character, default: 0] += 1 }
        }
        return counts.max { $0.value < $1.value }?.key ?? ","
    }

    /// RFC 4180 style: quoted fields may hold the separator, newlines and "".
    private static func parseRecords(_ text: String, separator: Character) -> [[String]] {
        var records: [[String]] = []
        var record: [String] = []
        var field = ""
        var inQuotes = false
        var iterator = Array(text).makeIterator()
        var pending: Character? = iterator.next()

        while let character = pending {
            pending = iterator.next()
            if inQuotes {
                if character == "\"" {
                    if pending == "\"" {
                        field.append("\"")
                        pending = iterator.next()
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.append(character)
                }
            } else if character == "\"" {
                inQuotes = true
            } else if character == separator {
                record.append(field)
                field = ""
            } else if character == "\n" || character == "\r" || character == "\r\n" {
                record.append(field)
                records.append(record)
                record = []
                field = ""
                if character == "\r", pending == "\n" { pending = iterator.next() }
            } else {
                field.append(character)
            }
        }
        if !field.isEmpty || !record.isEmpty {
            record.append(field)
            records.append(record)
        }
        return records
    }
}
