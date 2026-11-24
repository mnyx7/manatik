import Foundation
import Speech

struct SpeechLanguage: Identifiable {
    let id: String
    let supportsOffline: Bool

    var name: String {
        AppLocalization.locale.localizedString(forIdentifier: id)
            ?? AppLocalization.locale.localizedString(forLanguageCode: Locale(identifier: id).language.languageCode?.identifier ?? id)
            ?? id
    }
    var nativeName: String {
        let locale = Locale(identifier: id)
        return locale.localizedString(forIdentifier: id)
            ?? locale.localizedString(forLanguageCode: locale.language.languageCode?.identifier ?? id) ?? id
    }
}

enum SpeechLanguages {
    static func all() -> [SpeechLanguage] {
        SFSpeechRecognizer.supportedLocales().map { locale in
            SpeechLanguage(id: locale.identifier,
                           supportsOffline: SFSpeechRecognizer(locale: locale)?.supportsOnDeviceRecognition == true)
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    static func defaultID(in languages: [SpeechLanguage]) -> String {
        let available = languages.filter(\.supportsOffline)
        let preferred = Locale.preferredLanguages + [Locale.current.identifier, "en-US"]
        func canonical(_ id: String) -> String { id.replacingOccurrences(of: "_", with: "-").lowercased() }
        let commonRegions = ["en": "en-US", "ru": "ru-RU", "az": "az-AZ", "es": "es-ES", "fr": "fr-FR", "de": "de-DE", "pt": "pt-BR", "zh": "zh-CN"]
        for id in preferred {
            let locale = Locale(identifier: id)
            if let exact = available.first(where: { canonical($0.id) == canonical(id) }) { return exact.id }
            let code = locale.language.languageCode?.identifier ?? ""
            let candidates = available.filter { Locale(identifier: $0.id).language.languageCode?.identifier == code }
            if let region = Locale.current.region,
               let regional = candidates.first(where: { Locale(identifier: $0.id).region == region }) { return regional.id }
            if let standard = commonRegions[code], let match = candidates.first(where: { canonical($0.id) == canonical(standard) }) { return match.id }
            if let match = candidates.first { return match.id }
        }
        return available.first?.id ?? languages.first?.id ?? "en-US"
    }

    static func resolvedID(_ stored: String, in languages: [SpeechLanguage]) -> String {
        guard !stored.isEmpty else { return defaultID(in: languages) }
        return languages.first(where: {
            $0.id.replacingOccurrences(of: "_", with: "-").lowercased() == stored.replacingOccurrences(of: "_", with: "-").lowercased()
        })?.id ?? defaultID(in: languages)
    }

    static func name(for id: String) -> String {
        AppLocalization.locale.localizedString(forIdentifier: id) ?? id
    }
}
