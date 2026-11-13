import Foundation

/// Les cinq critères évalués par rapport aux calories.
enum Criterion: String, CaseIterable, Codable, Hashable, Identifiable {
    case protein, fiber, sugars, saturatedFat, salt

    enum Direction {
        /// Protéines, fibres : plus il y en a par kcal, mieux c'est.
        case moreIsBetter
        /// Sucres, graisses saturées, sel : moins il y en a par kcal, mieux c'est.
        case lessIsBetter
    }

    var id: String { rawValue }

    var direction: Direction {
        switch self {
        case .protein, .fiber: .moreIsBetter
        case .sugars, .saturatedFat, .salt: .lessIsBetter
        }
    }

    var field: NutrientField {
        switch self {
        case .protein: .protein
        case .fiber: .fiber
        case .sugars: .sugars
        case .saturatedFat: .saturatedFat
        case .salt: .salt
        }
    }

    var title: String {
        switch self {
        case .protein: String(localized: "Protéines")
        case .fiber: String(localized: "Fibres")
        case .sugars: String(localized: "Sucres")
        case .saturatedFat: String(localized: "Graisses saturées")
        case .salt: String(localized: "Sel")
        }
    }
}

/// Seuils d'un critère, en g pour 100 kcal.
struct CriterionThresholds: Codable, Hashable {
    var low: Double
    var high: Double

    var isValid: Bool { low > 0 && low < high }
}

/// Tous les seuils d'un profil. Persisté en UserDefaults via `ProfileStore`.
struct ProfileConfig: Codable, Hashable {
    var protein: CriterionThresholds
    var fiber: CriterionThresholds
    var sugars: CriterionThresholds
    var saturatedFat: CriterionThresholds
    var salt: CriterionThresholds

    subscript(criterion: Criterion) -> CriterionThresholds {
        get {
            switch criterion {
            case .protein: protein
            case .fiber: fiber
            case .sugars: sugars
            case .saturatedFat: saturatedFat
            case .salt: salt
            }
        }
        set {
            switch criterion {
            case .protein: protein = newValue
            case .fiber: fiber = newValue
            case .sugars: sugars = newValue
            case .saturatedFat: saturatedFat = newValue
            case .salt: salt = newValue
            }
        }
    }

    var isValid: Bool { Criterion.allCases.allSatisfy { self[$0].isValid } }
}

enum ProfileKind: String, CaseIterable, Codable, Hashable, Identifiable {
    case balanced, cutting, bulking, custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .balanced: String(localized: "Équilibré")
        case .cutting: String(localized: "Sèche")
        case .bulking: String(localized: "Prise de masse")
        case .custom: String(localized: "Personnalisé")
        }
    }

    /// Libellé court pour le sélecteur segmenté de l'écran résultat.
    var shortTitle: String {
        switch self {
        case .balanced: String(localized: "Équilibré")
        case .cutting: String(localized: "Sèche")
        case .bulking: String(localized: "Masse")
        case .custom: String(localized: "Perso")
        }
    }
}
