import Foundation

/// Champs d'un tableau nutritionnel, tels qu'ils apparaissent sur l'étiquette.
enum NutrientField: String, CaseIterable, Codable, Hashable, Identifiable {
    case energy, fat, saturatedFat, carbohydrates, sugars, fiber, protein, salt

    var id: String { rawValue }

    var title: String {
        switch self {
        case .energy: String(localized: "Énergie")
        case .fat: String(localized: "Matières grasses")
        case .saturatedFat: String(localized: "dont acides gras saturés")
        case .carbohydrates: String(localized: "Glucides")
        case .sugars: String(localized: "dont sucres")
        case .fiber: String(localized: "Fibres")
        case .protein: String(localized: "Protéines")
        case .salt: String(localized: "Sel")
        }
    }

    var unit: String { self == .energy ? "kcal" : "g" }

    /// Vrai si le champ entre dans le calcul de la note (énergie + les six critères).
    var isUsedForScoring: Bool {
        switch self {
        case .energy, .saturatedFat, .carbohydrates, .sugars, .fiber, .protein, .salt: true
        case .fat: false
        }
    }
}

/// Valeurs nutritionnelles pour 100 g (ou 100 ml). `nil` = valeur inconnue :
/// on ne remplace jamais une valeur manquante par zéro.
struct NutritionFacts: Codable, Hashable {
    var energyKcal: Double?
    var fat: Double?
    var saturatedFat: Double?
    var carbohydrates: Double?
    var sugars: Double?
    var fiber: Double?
    var protein: Double?
    var salt: Double?

    subscript(field: NutrientField) -> Double? {
        get {
            switch field {
            case .energy: energyKcal
            case .fat: fat
            case .saturatedFat: saturatedFat
            case .carbohydrates: carbohydrates
            case .sugars: sugars
            case .fiber: fiber
            case .protein: protein
            case .salt: salt
            }
        }
        set {
            switch field {
            case .energy: energyKcal = newValue
            case .fat: fat = newValue
            case .saturatedFat: saturatedFat = newValue
            case .carbohydrates: carbohydrates = newValue
            case .sugars: sugars = newValue
            case .fiber: fiber = newValue
            case .protein: protein = newValue
            case .salt: salt = newValue
            }
        }
    }

    var isEmpty: Bool { NutrientField.allCases.allSatisfy { self[$0] == nil } }
}

/// Incohérence détectée dans un tableau nutritionnel (erreur de saisie, d'OCR ou de base de données).
enum ConsistencyWarning: Codable, Hashable {
    case sugarsExceedCarbohydrates
    case saturatedExceedsFat
    case macrosExceed100g
    case energyMismatch(declared: Double, estimated: Double)
    case negativeValue(NutrientField)

    var message: String {
        switch self {
        case .sugarsExceedCarbohydrates:
            String(localized: "Les sucres dépassent les glucides : vérifiez ces deux valeurs.")
        case .saturatedExceedsFat:
            String(localized: "Les acides gras saturés dépassent les matières grasses : vérifiez ces deux valeurs.")
        case .macrosExceed100g:
            String(localized: "La somme des nutriments dépasse 100 g pour 100 g : au moins une valeur est fausse.")
        case .energyMismatch(let declared, let estimated):
            String(localized: "Énergie déclarée (\(Int(declared.rounded())) kcal) éloignée de l'énergie estimée à partir des nutriments (\(Int(estimated.rounded())) kcal).")
        case .negativeValue(let field):
            String(localized: "Valeur négative ignorée : \(field.title).")
        }
    }

    /// Champs à re-vérifier pour cette alerte.
    var fields: [NutrientField] {
        switch self {
        case .sugarsExceedCarbohydrates: [.sugars, .carbohydrates]
        case .saturatedExceedsFat: [.saturatedFat, .fat]
        case .macrosExceed100g: [.fat, .carbohydrates, .fiber, .protein, .salt]
        case .energyMismatch: [.energy]
        case .negativeValue(let field): [field]
        }
    }
}

extension NutritionFacts {
    /// Contrôles de cohérence interne. Ne corrige rien : signale seulement.
    var consistencyWarnings: [ConsistencyWarning] {
        var warnings: [ConsistencyWarning] = []
        let tolerance = 0.05 // arrondis d'étiquette

        for field in NutrientField.allCases {
            if let value = self[field], value < 0 { warnings.append(.negativeValue(field)) }
        }
        if let sugars, let carbohydrates, sugars > carbohydrates + tolerance {
            warnings.append(.sugarsExceedCarbohydrates)
        }
        if let saturatedFat, let fat, saturatedFat > fat + tolerance {
            warnings.append(.saturatedExceedsFat)
        }
        let macroSum = [fat, carbohydrates, fiber, protein, salt].compactMap { $0 }.reduce(0, +)
        if macroSum > 100 + 1 {
            warnings.append(.macrosExceed100g)
        }
        // Facteurs d'Atwater (règlement UE 1169/2011) : 4 kcal/g pour protéines et glucides,
        // 9 kcal/g pour les lipides, 2 kcal/g pour les fibres. Polyols et alcool ne figurent
        // pas dans nos champs, d'où une tolérance large (30 % et au moins 25 kcal).
        if let energyKcal, let fat, let carbohydrates, let protein {
            let estimated = 9 * fat + 4 * carbohydrates + 4 * protein + 2 * (fiber ?? 0)
            let gap = abs(energyKcal - estimated)
            if gap > 25, gap > 0.3 * max(energyKcal, estimated) {
                warnings.append(.energyMismatch(declared: energyKcal, estimated: estimated))
            }
        }
        return warnings
    }
}
