import Foundation

/// Composition calculée d'une recette.
struct RecipeCalculation {
    /// Somme des valeurs connues de chaque nutriment ; `nil` si aucun ingrédient ne la fournit.
    let totals: NutritionFacts
    /// Nutriments dont au moins un ingrédient n'a pas la valeur → ingrédients concernés.
    /// Ces nutriments sont `nil` au 100 g : jamais comptés comme 0 en silence.
    let incomplete: [NutrientField: [String]]
    let rawWeight: Double
    let referenceWeight: Double
    let usesFinalWeight: Bool
    let per100g: NutritionFacts
    let perServing: NutritionFacts?
    let servings: Int?

    var isPartial: Bool { !incomplete.isEmpty }

    /// La recette vue comme un produit au 100 g : le moteur de scoring s'applique tel quel.
    func product(named name: String) -> Product {
        Product(name: name, facts: per100g, source: .recipe)
    }
}

enum RecipeCalculator {
    enum Blocker: Hashable {
        case missingWeight, missingFood
    }

    /// Lignes qui empêchent le calcul : poids en g ou aliment manquant.
    static func blockers(in lines: [RecipeLine]) -> [(line: RecipeLine, blocker: Blocker)] {
        lines.compactMap { line in
            if line.grams == nil { return (line, .missingWeight) }
            if line.food == nil { return (line, .missingFood) }
            return nil
        }
    }

    /// `nil` tant que toutes les lignes n'ont pas un poids et un aliment, ou si le poids de référence est nul.
    static func calculate(lines: [RecipeLine], finalWeight: Double?, servings: Int?, library: [FoodItem]) -> RecipeCalculation? {
        guard !lines.isEmpty, blockers(in: lines).isEmpty else { return nil }
        let resolved = lines.compactMap { line in
            line.food?.resolve(in: library).map { (line: line, food: $0, grams: line.grams ?? 0) }
        }
        guard resolved.count == lines.count else { return nil }

        let rawWeight = resolved.reduce(0) { $0 + $1.grams }
        let usesFinalWeight = (finalWeight ?? 0) > 0
        let reference = usesFinalWeight ? finalWeight! : rawWeight
        guard reference > 0 else { return nil }

        var totals = NutritionFacts()
        var incomplete: [NutrientField: [String]] = [:]
        for field in NutrientField.allCases {
            var sum = 0.0
            var known = false
            for item in resolved {
                if let value = item.food.facts[field] {
                    sum += item.grams / 100 * value
                    known = true
                } else {
                    incomplete[field, default: []].append(item.line.name)
                }
            }
            totals[field] = known ? sum : nil
        }

        var per100g = NutritionFacts()
        var perServing: NutritionFacts?
        let servingCount = servings.flatMap { $0 > 0 ? $0 : nil }
        if servingCount != nil { perServing = NutritionFacts() }
        for field in NutrientField.allCases where incomplete[field] == nil {
            guard let total = totals[field] else { continue }
            per100g[field] = total / reference * 100
            if let servingCount { perServing?[field] = total / Double(servingCount) }
        }

        return RecipeCalculation(
            totals: totals, incomplete: incomplete, rawWeight: rawWeight, referenceWeight: reference,
            usesFinalWeight: usesFinalWeight, per100g: per100g, perServing: perServing, servings: servingCount
        )
    }
}
