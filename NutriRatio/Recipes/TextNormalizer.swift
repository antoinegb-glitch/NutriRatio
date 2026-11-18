import Foundation

/// Normalisation de noms d'aliments : insensible à la casse, aux accents et au pluriel.
enum TextNormalizer {
    private static let stopWords: Set<String> = ["de", "d", "du", "des", "la", "le", "les", "l", "un", "une", "au", "aux", "of", "the"]

    /// Minuscules, sans accents, « œ » → « oe ».
    static func fold(_ text: String) -> String {
        text.replacingOccurrences(of: "œ", with: "oe")
            .replacingOccurrences(of: "Œ", with: "oe")
            .replacingOccurrences(of: "æ", with: "ae")
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr_FR"))
    }

    /// Mots significatifs au singulier : « Gousses d'ail » → [gousse, ail].
    static func tokens(_ text: String) -> [String] {
        var result: [String] = []
        var current = ""
        for character in fold(text) {
            if character.isLetter || character.isNumber {
                current.append(character)
            } else if !current.isEmpty {
                result.append(current)
                current = ""
            }
        }
        if !current.isEmpty { result.append(current) }
        return result.filter { !stopWords.contains($0) }.map(singular)
    }

    static func key(_ text: String) -> Set<String> { Set(tokens(text)) }

    private static func singular(_ token: String) -> String {
        token.count > 3 && token.hasSuffix("s") && !token.hasSuffix("ss") ? String(token.dropLast()) : token
    }
}
