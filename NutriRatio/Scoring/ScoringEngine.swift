import Foundation

/// Moteur d'évaluation : logique pure, sans état ni UI.
///
/// Principe : chaque nutriment est rapporté aux calories (g pour 100 kcal) plutôt qu'au
/// poids, afin de comparer ce que le produit « apporte » pour l'énergie qu'il coûte.
/// Chaque critère reçoit son propre verdict ; il n'y a pas de note globale, pour qu'un
/// défaut (pas de fibres) ne masque pas une qualité (beaucoup de protéines).
enum ScoringEngine {
    /// En dessous de 5 kcal pour 100 g, diviser par l'énergie gonfle artificiellement les ratios.
    static let minimumEnergyKcal = 5.0

    static func evaluate(_ facts: NutritionFacts, config: ProfileConfig) -> Evaluation {
        let warnings = facts.consistencyWarnings

        func notApplicable(_ reason: Evaluation.NotApplicableReason) -> Evaluation {
            Evaluation(notApplicable: reason, criteria: [], missing: [], warnings: warnings)
        }

        guard let kcal = facts.energyKcal, kcal >= 0 else { return notApplicable(.missingEnergy) }
        guard kcal >= minimumEnergyKcal else { return notApplicable(.energyTooLow) }

        var results: [CriterionResult] = []
        var missing: [Criterion] = []
        for criterion in Criterion.allCases {
            // Valeur absente ou négative : critère ignoré et signalé, jamais remplacé par 0.
            guard let per100g = facts[criterion.field], per100g >= 0 else {
                missing.append(criterion)
                continue
            }
            let per100kcal = per100g / kcal * 100
            results.append(CriterionResult(
                criterion: criterion,
                per100g: per100g,
                per100kcal: per100kcal,
                level: level(for: per100kcal, thresholds: config[criterion], direction: criterion.direction)
            ))
        }

        return Evaluation(
            notApplicable: results.isEmpty ? .noCriteria : nil,
            criteria: results,
            missing: missing,
            warnings: warnings
        )
    }

    /// Verdict d'un critère d'après les seuils du profil.
    static func level(for value: Double, thresholds: CriterionThresholds, direction: Criterion.Direction) -> Verdict {
        switch direction {
        case .moreIsBetter:
            if value >= thresholds.high { return .interesting }
            return value >= thresholds.low ? .average : .notInteresting
        case .lessIsBetter:
            if value <= thresholds.low { return .interesting }
            return value <= thresholds.high ? .average : .notInteresting
        }
    }
}
