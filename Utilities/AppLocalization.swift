import Foundation

/// Explicit bundles keep model-generated strings in the same language as SwiftUI.
enum AppLocalization {
    nonisolated static var selection: String {
        let value = UserDefaults.standard.string(forKey: "appLanguage") ?? "system"
        return ["en", "ru", "az"].contains(value) ? value : "system"
    }

    nonisolated static var locale: Locale {
        guard selection != "system" else { return .current }
        var components = Locale.Components(locale: .current)
        components.languageComponents.languageCode = Locale.LanguageCode(selection)
        return Locale(components: components)
    }

    nonisolated static func string(_ key: String, tableName: String? = nil,
                                   bundle: Bundle = .main, value: String = "", comment: String) -> String {
        let selected: Bundle
        if selection != "system", bundle == .main,
           let path = bundle.path(forResource: selection, ofType: "lproj"), let localized = Bundle(path: path) {
            selected = localized
        } else { selected = bundle }
        return Foundation.NSLocalizedString(key, tableName: tableName, bundle: selected, value: value, comment: comment)
    }
}
