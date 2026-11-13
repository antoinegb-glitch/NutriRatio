import Foundation

/// Verdict à trois niveaux, donné pour chaque critère.
enum Verdict: String, Codable, Hashable {
    case interesting, average, notInteresting

    var title: String {
        switch self {
        case .interesting: String(localized: "Intéressant")
        case .average: String(localized: "Moyen")
        case .notInteresting: String(localized: "Pas intéressant")
        }
    }
}

/// Résultat d'un critère pour un produit et un profil donnés.
struct CriterionResult: Codable, Hashable, Identifiable {
    let criterion: Criterion
    let per100g: Double
    let per100kcal: Double
    let level: Verdict

    var id: Criterion { criterion }

    /// Phrase lisible, ex. « Protéines : 9 g pour 100 kcal, très bon ».
    var explanation: String {
        String(localized: "\(criterion.title) : \(formattedPer100kcal) g pour 100 kcal, \(qualifier)")
    }

    /// Deux décimales sous 1 g (le sel se joue au centième), une au-delà.
    var formattedPer100kcal: String {
        per100kcal.formatted(.number.precision(.fractionLength(0...(per100kcal < 1 ? 2 : 1))))
    }

    /// Point fort du produit : beaucoup de protéines ou de fibres pour ses calories.
    var isStrength: Bool { criterion.direction == .moreIsBetter && level == .interesting }

    /// À surveiller : trop de sucres, de graisses saturées ou de sel pour ses calories.
    var isCaution: Bool { criterion.direction == .lessIsBetter && level == .notInteresting }

    private var qualifier: String {
        switch (criterion.direction, level) {
        case (.moreIsBetter, .interesting): String(localized: "très bon")
        case (.moreIsBetter, .average): String(localized: "correct")
        case (.moreIsBetter, .notInteresting): String(localized: "faible")
        case (.lessIsBetter, .interesting): String(localized: "bas")
        case (.lessIsBetter, .average): String(localized: "modéré")
        case (.lessIsBetter, .notInteresting): String(localized: "élevé")
        }
    }
}

/// Évaluation d'un tableau nutritionnel selon un profil. Indépendante de l'UI.
struct Evaluation: Codable, Hashable {
    enum NotApplicableReason: String, Codable, Hashable {
        /// Énergie absente : impossible de normaliser par kcal.
        case missingEnergy
        /// Moins de 5 kcal pour 100 g (eau, café, thé) : les ratios par kcal n'ont pas de sens.
        case energyTooLow
        /// Aucun critère exploitable : tous les nutriments évalués sont manquants.
        case noCriteria

        var message: String {
            switch self {
            case .missingEnergy:
                String(localized: "Énergie manquante : impossible de rapporter les nutriments aux calories.")
            case .energyTooLow:
                String(localized: "Produit quasi sans calories (moins de 5 kcal pour 100 g) : le rapport aux calories n'a pas de sens.")
            case .noCriteria:
                String(localized: "Aucun critère exploitable : renseignez au moins un nutriment évalué.")
            }
        }
    }

    /// `nil` quand le produit a pu être évalué.
    let notApplicable: NotApplicableReason?
    let criteria: [CriterionResult]
    /// Critères ignorés faute de donnée (jamais remplacés par une valeur inventée).
    let missing: [Criterion]
    let warnings: [ConsistencyWarning]

    var strengths: [CriterionResult] { criteria.filter(\.isStrength) }
    var cautions: [CriterionResult] { criteria.filter(\.isCaution) }
}
