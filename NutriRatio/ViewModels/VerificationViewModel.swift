import Foundation
import Observation

/// Ce que chaque mode d'entrée (saisie, code-barres, photo) transmet à l'écran de vérification.
struct VerificationInput: Hashable {
    var product: Product
    /// Champs dont la valeur est incertaine (OCR hésitant, valeur déduite…).
    var doubtful: Set<NutrientField> = []
    /// Message d'information affiché en haut de l'écran.
    var notice: String?
}

/// État éditable de l'écran de vérification : les valeurs sont du texte tant que
/// l'utilisateur n'a pas validé.
@Observable
final class VerificationViewModel {
    enum FieldState {
        case ok, missing, doubtful, invalid
    }

    var name: String
    var texts: [NutrientField: String]
    private(set) var doubtful: Set<NutrientField>
    let notice: String?
    private let original: Product

    init(input: VerificationInput) {
        original = input.product
        name = input.product.name
        doubtful = input.doubtful
        notice = input.notice
        var texts: [NutrientField: String] = [:]
        for field in NutrientField.allCases {
            if let value = input.product.facts[field] {
                texts[field] = value.formatted(.number.precision(.fractionLength(0...3)).grouping(.never))
            }
        }
        self.texts = texts
    }

    var subtitle: String? {
        [original.brand, original.barcode].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ").nilIfEmpty
    }

    /// Accepte la virgule comme le point ; refuse les valeurs négatives ou non numériques.
    static func parse(_ text: String) -> Double? {
        let cleaned = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        guard let value = Double(cleaned), value.isFinite, value >= 0 else { return nil }
        return value
    }

    func state(of field: NutrientField) -> FieldState {
        let text = (texts[field] ?? "").trimmingCharacters(in: .whitespaces)
        if text.isEmpty { return field.isUsedForScoring ? .missing : .ok }
        if Self.parse(text) == nil { return .invalid }
        return doubtful.contains(field) ? .doubtful : .ok
    }

    /// Une valeur corrigée à la main n'est plus douteuse.
    func userEdited(_ field: NutrientField) {
        doubtful.remove(field)
    }

    var canEvaluate: Bool {
        NutrientField.allCases.allSatisfy { state(of: $0) != .invalid }
    }

    var hasHighlightedFields: Bool {
        NutrientField.allCases.contains { state(of: $0) == .missing || state(of: $0) == .doubtful }
    }

    func makeProduct() -> Product {
        var product = original
        product.name = name.trimmingCharacters(in: .whitespaces)
        var facts = NutritionFacts()
        for field in NutrientField.allCases {
            facts[field] = texts[field].flatMap(Self.parse)
        }
        product.facts = facts
        return product
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
