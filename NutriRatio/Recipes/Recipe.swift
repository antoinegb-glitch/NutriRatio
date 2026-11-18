import Foundation

/// Point d'attention sur une ligne, affiché à l'écran de vérification.
enum LineNote: String, Codable, Hashable {
    case rangeAveraged, vagueQuantity, noQuantity, assumedDensity

    var message: String {
        switch self {
        case .rangeAveraged: String(localized: "Plage de quantités : la moyenne a été retenue.")
        case .vagueQuantity: String(localized: "Quantité imprécise : à compléter.")
        case .noQuantity: String(localized: "Aucune quantité détectée : à compléter.")
        case .assumedDensity: String(localized: "Densité supposée égale à celle de l'eau : à vérifier.")
        }
    }
}

struct RecipeLine: Codable, Hashable, Identifiable {
    var id = UUID()
    /// Texte tel qu'écrit dans la recette, toujours conservé pour l'affichage.
    var originalText = ""
    /// Nom nettoyé, utilisé pour la recherche d'un aliment.
    var name = ""
    var quantity: Double?
    var unit: RecipeUnit = .gram
    /// Poids en g : converti depuis la quantité, ou saisi (`gramsIsManual`).
    var grams: Double?
    var gramsIsManual = false
    var food: FoodRef?
    /// Association automatique non encore confirmée par l'utilisateur.
    var foodNeedsReview = false
    var notes: [LineNote] = []

    init(id: UUID = UUID(), originalText: String = "", name: String = "", quantity: Double? = nil,
         unit: RecipeUnit = .gram, grams: Double? = nil, gramsIsManual: Bool = false,
         food: FoodRef? = nil, foodNeedsReview: Bool = false, notes: [LineNote] = []) {
        self.id = id
        self.originalText = originalText
        self.name = name
        self.quantity = quantity
        self.unit = unit
        self.grams = grams
        self.gramsIsManual = gramsIsManual
        self.food = food
        self.foodNeedsReview = foodNeedsReview
        self.notes = notes
    }

    init(parsed: ParsedLine) {
        self.init(originalText: parsed.originalText, name: parsed.name, quantity: parsed.quantity,
                  unit: parsed.unit, notes: parsed.notes)
    }

    /// Recalcule le poids en g depuis la quantité, sauf s'il a été saisi à la main.
    /// Le poids d'une pièce de l'aliment associé prime sur la table par défaut.
    mutating func reconvert(unitWeight: Double?) {
        notes.removeAll { $0 == .assumedDensity }
        guard !gramsIsManual else { return }
        if let result = WeightConverter.grams(quantity: quantity, unit: unit, ingredient: name, unitWeight: unitWeight) {
            grams = result.grams
            if result.assumed { notes.append(.assumedDensity) }
        } else {
            grams = nil
        }
    }

    var needsWeight: Bool { grams == nil }
    var needsFood: Bool { food == nil }
    var needsAttention: Bool { needsWeight || needsFood || foodNeedsReview || !notes.isEmpty }
}

struct Recipe: Codable, Hashable, Identifiable {
    var id = UUID()
    var name = ""
    var lines: [RecipeLine] = []
    /// Poids du plat cuit en g : remplace le poids cru pour le calcul au 100 g.
    var finalWeight: Double?
    var servings: Int?
    var date = Date.now
}

extension RecipeLine {
    /// Rattache la ligne à la bibliothèque : aliment supprimé ou jamais associé → aliment par défaut
    /// correspondant, sinon « à associer » ; poids unitaire et poids converti remis à jour.
    func refreshed(in library: [FoodItem]) -> RecipeLine {
        var line = self
        if let ref = line.food, ref.resolve(in: library) == nil {
            line.food = nil
            line.foodNeedsReview = false
        }
        line = line.autoAssociated(in: library)
        line.reconvert(unitWeight: line.food?.resolve(in: library)?.unitWeightGrams)
        return line
    }

    /// Associe automatiquement l'aliment par défaut correspondant, s'il n'y a pas déjà d'aliment.
    /// Une valeur moyenne intégrée de même nom que la ligne n'a pas besoin d'être vérifiée.
    func autoAssociated(in library: [FoodItem]) -> RecipeLine {
        guard food == nil, let best = FoodMatcher.matches(for: name, in: library).first,
              best.score >= FoodMatcher.automaticScore else { return self }
        let match = best.food
        var line = self
        line.food = .library(match.id)
        line.foodNeedsReview = !(match.isBuiltIn && best.score == 3)
        line.reconvert(unitWeight: match.unitWeightGrams)
        return line
    }
}

extension Recipe {
    func refreshed(in library: [FoodItem]) -> Recipe {
        var recipe = self
        recipe.lines = lines.map { $0.refreshed(in: library) }
        return recipe
    }
}
