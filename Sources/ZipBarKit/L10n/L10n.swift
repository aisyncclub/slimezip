import Foundation

/// Translation, keyed by the Korean string itself.
///
/// No symbolic keys. `L("설정…")` reads as what it draws, and a string with no
/// entry in the table falls back to the Korean — which is exactly what the app
/// shipped before this file existed. A missing translation therefore degrades
/// to the old behaviour rather than to `settings.menu.item.title` on screen.
///
/// The table is compiled in rather than loaded from a resource. The app bundle
/// here is assembled by hand in `scripts/build-app.sh`, so a `.strings` file is
/// one more thing that can be forgotten during packaging and fail silently at
/// the worst moment. A dictionary cannot fail to load.
public enum L10n {

    public enum Language: String, CaseIterable {
        case auto, ko, en

        public var label: String {
            switch self {
            case .auto: return L("시스템 설정 따름")
            case .ko: return "한국어"
            case .en: return "English"
            }
        }
    }

    public static let key = "com.zipbar.language"

    /// Changing this is what the language picker does. Views read `current`
    /// through `L(_:)` on every draw, so a change lands as soon as the view
    /// redraws — no restart, no bundle reload.
    public static var preference: Language {
        get { Language(rawValue: UserDefaults.standard.string(forKey: key) ?? "") ?? .auto }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: key) }
    }

    /// The language actually in use.
    ///
    /// `auto` follows the system's preferred order rather than just the first
    /// entry: somebody whose list is [ja, en, ko] gets English, which is closer
    /// to what they asked for than Korean.
    public static var current: Language {
        switch preference {
        case .ko: return .ko
        case .en: return .en
        case .auto:
            for tag in Locale.preferredLanguages {
                if tag.hasPrefix("ko") { return .ko }
                if tag.hasPrefix("en") { return .en }
            }
            // Everything else gets English. A Japanese speaker is far more
            // likely to read English than Korean, and shipping Korean as the
            // universal default was only ever an accident of who wrote it.
            return .en
        }
    }

    public static func t(_ korean: String) -> String {
        guard current == .en else { return korean }
        return english[korean] ?? korean
    }

    /// Filled in by `L10nTable.swift`, kept apart so this file stays readable.
    static let english: [String: String] = L10nTable.english
}

/// Shorthand. Two forms: a plain lookup, and one that fills placeholders.
public func L(_ korean: String) -> String { L10n.t(korean) }

/// Formatted lookup.
///
/// The Korean key carries the placeholders, so the table's English value can
/// put them in a different order — "%@개 숨김" against "%@ hidden" happens to
/// agree, but "%1$@ / %2$@" ordering will not always.
public func L(_ korean: String, _ args: CVarArg...) -> String {
    String(format: L10n.t(korean), arguments: args)
}
