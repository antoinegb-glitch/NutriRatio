import Foundation
import Observation

/// Point d'entrée de l'éditeur de recette : une recette enregistrée, un texte analysé, ou rien (saisie manuelle).
struct RecipeEditorSeed: Hashable {
    var recipeID: UUID?
    var parsed: ParsedRecipe?
}

/// État éditable de l'écran de vérification des ingrédients. Les nombres restent du texte
/// tant qu'ils sont en cours de saisie ; la logique de conversion et d'association est dans `Recipes/`.
@Observable
final class RecipeEditorModel {
    var recipe = Recipe()
    var servingsText = ""
    var finalWeightText = ""
    private(set) var quantityTexts: [UUID: String] = [:]
    private(set) var gramsTexts: [UUID: String] = [:]
    private(set) var notice: String?
    private var isLoaded = false

    /// Charge la recette une seule fois (l'écran peut réapparaître après un retour de sous-écran).
    func load(seed: RecipeEditorSeed, recipes: RecipeStore, library: FoodLibrary) {
        guard !isLoaded else { return }
        isLoaded = true
        if let id = seed.recipeID, let saved = recipes.recipe(id: id) {
            recipe = saved.refreshed(in: library.available)
        } else if let parsed = seed.parsed {
            recipe.name = parsed.title ?? ""
            recipe.servings = parsed.servings
            recipe.lines = parsed.lines.map {
                RecipeLine(parsed: $0).autoAssociated(in: library.available).refreshed(in: library.available)
            }
            notice = parsed.lines.isEmpty
                ? String(localized: "Aucun ingrédient détecté dans ce texte : ajoutez les lignes à la main.")
                : String(localized: "\(parsed.lines.count) ingrédients détectés. Vérifiez les lignes surlignées avant de calculer.")
        }
        servingsText = recipe.servings.map(String.init) ?? ""
        finalWeightText = recipe.finalWeight.map(Self.format) ?? ""
        for line in recipe.lines { syncTexts(of: line) }
    }

    static func format(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1)).grouping(.never))
    }

    private func syncTexts(of line: RecipeLine) {
        quantityTexts[line.id] = line.quantity.map(Self.format) ?? ""
        gramsTexts[line.id] = line.grams.map(Self.format) ?? ""
    }

    private func index(of id: UUID) -> Int? { recipe.lines.firstIndex { $0.id == id } }

    private func unitWeight(of line: RecipeLine, library: FoodLibrary) -> Double? {
        line.food?.resolve(in: library.available)?.unitWeightGrams
    }

    // MARK: - Lignes

    func addLine() {
        let line = RecipeLine(unit: .gram)
        recipe.lines.append(line)
        syncTexts(of: line)
    }

    func removeLines(at offsets: IndexSet) {
        recipe.lines.remove(atOffsets: offsets)
    }

    func setName(_ name: String, of id: UUID, library: FoodLibrary) {
        guard let i = index(of: id) else { return }
        // Un aliment choisi automatiquement pour le nom précédent suit la frappe (« lait » → « lait de coco »).
        let previous = FoodMatcher.automaticMatch(for: recipe.lines[i].name, in: library.available)
        if let food = recipe.lines[i].food, case .library(let id) = food, id == previous?.id {
            recipe.lines[i].food = nil
        }
        recipe.lines[i].name = name
        recipe.lines[i] = recipe.lines[i].autoAssociated(in: library.available)
        reconvert(i, library: library)
    }

    func setQuantityText(_ text: String, of id: UUID, library: FoodLibrary) {
        guard let i = index(of: id) else { return }
        quantityTexts[id] = text
        recipe.lines[i].quantity = VerificationViewModel.parse(text)
        recipe.lines[i].notes.removeAll { $0 == .noQuantity || $0 == .vagueQuantity || $0 == .rangeAveraged }
        reconvert(i, library: library)
    }

    func setUnit(_ unit: RecipeUnit, of id: UUID, library: FoodLibrary) {
        guard let i = index(of: id) else { return }
        recipe.lines[i].unit = unit
        reconvert(i, library: library)
    }

    /// Saisir un poids le fige ; le vider rend la main à la conversion.
    func setGramsText(_ text: String, of id: UUID, library: FoodLibrary) {
        guard let i = index(of: id) else { return }
        gramsTexts[id] = text
        if let grams = VerificationViewModel.parse(text) {
            recipe.lines[i].grams = grams
            recipe.lines[i].gramsIsManual = true
        } else {
            recipe.lines[i].gramsIsManual = false
            reconvert(i, library: library)
        }
    }

    func setFood(_ food: FoodRef?, of id: UUID, library: FoodLibrary) {
        guard let i = index(of: id) else { return }
        recipe.lines[i].food = food
        recipe.lines[i].foodNeedsReview = false
        reconvert(i, library: library)
    }

    func confirmFood(of id: UUID) {
        guard let i = index(of: id) else { return }
        recipe.lines[i].foodNeedsReview = false
    }

    private func reconvert(_ i: Int, library: FoodLibrary) {
        recipe.lines[i].reconvert(unitWeight: unitWeight(of: recipe.lines[i], library: library))
        if !recipe.lines[i].gramsIsManual {
            gramsTexts[recipe.lines[i].id] = recipe.lines[i].grams.map(Self.format) ?? ""
        }
    }

    // MARK: - Calcul

    var servings: Int? { Int(servingsText.trimmingCharacters(in: .whitespaces)).flatMap { $0 > 0 ? $0 : nil } }
    var finalWeight: Double? { VerificationViewModel.parse(finalWeightText).flatMap { $0 > 0 ? $0 : nil } }

    var blockers: [(line: RecipeLine, blocker: RecipeCalculator.Blocker)] {
        RecipeCalculator.blockers(in: recipe.lines)
    }

    var canCalculate: Bool {
        !recipe.lines.isEmpty && blockers.isEmpty && !recipe.name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Recette prête à être enregistrée, avec les champs texte reportés.
    func makeRecipe() -> Recipe {
        var result = recipe
        result.name = recipe.name.trimmingCharacters(in: .whitespaces)
        result.servings = servings
        result.finalWeight = finalWeight
        return result
    }
}
