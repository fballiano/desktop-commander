import Foundation
import Testing

@testable import DesktopCommander

/// The translations.
///
/// `Resources/Localizable.xcstrings` holds every string of the interface. The
/// build turns it into one `Localizable.strings` for each language, so these
/// tests read the built application and not the catalogue.
///
/// A new string reaches the application in English and stays English in the
/// other five languages, and nothing says so at build time. These tests do.
@Suite("Localization")
struct LocalizationTests {
    /// The languages the application ships.
    static let languages = ["en", "de", "es", "fr", "it", "pt-BR"]

    /// The strings that one language writes the way English writes them. Every
    /// other string must differ, otherwise it was forgotten.
    ///
    /// The comment says which language each one is for.
    static let sameInEveryLanguage: Set<String> = [
        "15 minutes",  // French.
        "30 minutes",  // French.
        "Displays",    // German.
        "General",     // Spanish.
    ]

    @Test("The application carries every language")
    func languagesArePresent() {
        for language in Self.languages {
            #expect(
                Bundle.main.localizations.contains(language),
                "\(language) is missing from the application"
            )
        }
    }

    @Test("Every language holds every string")
    func everyLanguageIsComplete() throws {
        let english = try Self.strings(of: "en")

        #expect(english.count > 90)

        for language in Self.languages where language != "en" {
            let translated = try Self.strings(of: language)
            let missing = Set(english.keys).subtracting(translated.keys).sorted()

            #expect(missing.isEmpty, "\(language) is missing \(missing)")
        }
    }

    @Test("No string is left in English by mistake")
    func nothingIsUntranslated() throws {
        let english = try Self.strings(of: "en")

        for language in Self.languages where language != "en" {
            let translated = try Self.strings(of: language)

            for (key, value) in english where !Self.sameInEveryLanguage.contains(value) {
                #expect(
                    translated[key] != value,
                    "\(language) keeps the English text of \(key)"
                )
            }
        }
    }

    /// Every string of one language: the plain table and the plural table.
    ///
    /// The build writes a binary property list, so this reads it as one.
    private static func strings(of language: String) throws -> [String: String] {
        let folder = try #require(
            Bundle.main.url(forResource: language, withExtension: "lproj"),
            "no \(language).lproj in the application"
        )

        let table = NSDictionary(
            contentsOf: folder.appending(path: "Localizable.strings")
        ) as? [String: String] ?? [:]

        // A plural string lives in its own file, and each of its forms is a
        // string of its own. The "other" form stands for the whole entry.
        let plurals = NSDictionary(
            contentsOf: folder.appending(path: "Localizable.stringsdict")
        ) as? [String: [String: Any]] ?? [:]

        var result = table

        for (key, entry) in plurals {
            for value in entry.values {
                guard let forms = value as? [String: Any],
                      let other = forms["other"] as? String else { continue }

                result[key] = other
            }
        }

        return result
    }
}
