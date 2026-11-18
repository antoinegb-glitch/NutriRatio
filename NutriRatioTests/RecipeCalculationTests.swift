import XCTest
@testable import NutriRatio

final class WeightConverterTests: XCTestCase {
    private func grams(_ quantity: Double?, _ unit: RecipeUnit, _ name: String, unitWeight: Double? = nil) -> WeightConverter.Result? {
        WeightConverter.grams(quantity: quantity, unit: unit, ingredient: name, unitWeight: unitWeight)
    }

    func testMassUnits() {
        XCTAssertEqual(grams(200, .gram, "farine")?.grams, 200)
        XCTAssertEqual(grams(1.5, .kilogram, "farine")?.grams, 1500)
        XCTAssertEqual(grams(500, .milligram, "safran")?.grams ?? 0, 0.5, accuracy: 1e-9)
    }

    func testTablespoonOfOilIsAbout13Grams() throws {
        let result = try XCTUnwrap(grams(1, .tablespoon, "huile d'olive"))
        XCTAssertEqual(result.grams, 13.5, accuracy: 1)
        XCTAssertFalse(result.assumed)
    }

    func testTeaspoonAndSaltDensity() throws {
        XCTAssertEqual(try XCTUnwrap(grams(1, .teaspoon, "sel")).grams, 6, accuracy: 0.5)
    }

    func testWaterAndMilkVolumes() throws {
        XCTAssertEqual(try XCTUnwrap(grams(25, .centiliter, "eau")).grams, 250)
        XCTAssertEqual(try XCTUnwrap(grams(50, .centiliter, "lait demi-écrémé")).grams, 515, accuracy: 1)
        XCTAssertEqual(try XCTUnwrap(grams(1, .liter, "lait")).grams, 1030, accuracy: 1)
    }

    func testMetricVolumeOfUnknownIngredientIsAssumedAndFlagged() throws {
        let result = try XCTUnwrap(grams(10, .centiliter, "pastis"))
        XCTAssertEqual(result.grams, 100)
        XCTAssertTrue(result.assumed)
    }

    func testSpoonOfUnknownIngredientNeedsWeight() {
        XCTAssertNil(grams(2, .tablespoon, "poudre mystère"))
        XCTAssertNil(grams(1, .cup, "poudre mystère"))
    }

    func testPieceWeightsAndPlurals() throws {
        XCTAssertEqual(try XCTUnwrap(grams(2, .piece, "œufs")).grams, 110)
        XCTAssertEqual(try XCTUnwrap(grams(3, .piece, "gousses d'ail")).grams, 15)
        // L'entrée la plus spécifique l'emporte.
        XCTAssertEqual(try XCTUnwrap(grams(2, .piece, "blancs d'œufs")).grams, 66)
        XCTAssertEqual(try XCTUnwrap(grams(1, .piece, "pomme de terre")).grams, 150)
    }

    func testUnknownPieceNeedsWeightAndFoodUnitWeightWins() throws {
        XCTAssertNil(grams(1, .piece, "boîte de thon"))
        XCTAssertEqual(try XCTUnwrap(grams(2, .piece, "œufs", unitWeight: 60)).grams, 120)
        XCTAssertEqual(try XCTUnwrap(grams(1, .piece, "boîte de thon", unitWeight: 140)).grams, 140)
    }

    func testMissingQuantityNeedsWeight() {
        XCTAssertNil(grams(nil, .gram, "sel"))
    }

    func testLineReconvertKeepsManualWeight() {
        var line = RecipeLine(name: "œufs", quantity: 2, unit: .piece, grams: 999, gramsIsManual: true)
        line.reconvert(unitWeight: nil)
        XCTAssertEqual(line.grams, 999)
        line.gramsIsManual = false
        line.reconvert(unitWeight: nil)
        XCTAssertEqual(line.grams, 110)
    }
}

final class FoodMatcherTests: XCTestCase {
    private func food(_ name: String, aliases: [String] = [], isDefault: Bool = false, facts: NutritionFacts = NutritionFacts()) -> FoodItem {
        FoodItem(name: name, facts: facts, aliases: aliases, isDefault: isDefault)
    }

    func testMatchIgnoresCaseAccentsAndPlural() {
        let eggs = food("Œuf", aliases: ["oeufs"])
        for name in ["OEUFS", "œufs", "oeuf", "Œuf"] {
            XCTAssertEqual(FoodMatcher.automaticMatch(for: name, in: [eggs])?.id, eggs.id, name)
        }
    }

    func testAliasMatch() {
        let chocolate = food("Excellence 70 %", aliases: ["chocolat noir", "chocolat"])
        XCTAssertEqual(FoodMatcher.automaticMatch(for: "chocolat", in: [chocolate])?.id, chocolate.id)
        XCTAssertEqual(FoodMatcher.automaticMatch(for: "Chocolat noir", in: [chocolate])?.id, chocolate.id)
    }

    func testDefaultFoodWinsAmongSameAlias() {
        let other = food("Chocolat A", aliases: ["chocolat"])
        let preferred = food("Chocolat B", aliases: ["chocolat"], isDefault: true)
        XCTAssertEqual(FoodMatcher.automaticMatch(for: "chocolat", in: [other, preferred])?.id, preferred.id)
        XCTAssertEqual(FoodMatcher.matches(for: "chocolat", in: [other, preferred]).map(\.food.id), [preferred.id, other.id])
    }

    func testMoreSpecificNameBeatsDefaultOfGenericAlias() {
        let generic = food("Chocolat A", aliases: ["chocolat"], isDefault: true)
        let dark = food("Chocolat B", aliases: ["chocolat noir"])
        XCTAssertEqual(FoodMatcher.automaticMatch(for: "chocolat noir pâtissier", in: [generic, dark])?.id, dark.id)
        XCTAssertEqual(FoodMatcher.automaticMatch(for: "chocolat", in: [generic, dark])?.id, generic.id)
    }

    func testPartialOverlapIsOnlyASuggestion() {
        let dark = food("Chocolat noir")
        XCTAssertNil(FoodMatcher.automaticMatch(for: "chocolat", in: [dark]))
        XCTAssertEqual(FoodMatcher.matches(for: "chocolat", in: [dark]).map(\.score), [1])
    }

    func testNoMatch() {
        XCTAssertNil(FoodMatcher.automaticMatch(for: "farine", in: [food("Lait")]))
        XCTAssertTrue(FoodMatcher.matches(for: "", in: [food("Lait")]).isEmpty)
    }

    func testLibrarySetDefaultMovesTheDefault() {
        let library = FoodLibrary(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        let first = food("Chocolat A", aliases: ["chocolat"])
        let second = food("Chocolat B", aliases: ["chocolat"])
        library.save(first)
        library.save(second)
        // Le premier aliment d'un nom en devient le défaut ; le second ne le prend pas.
        XCTAssertEqual(library.foods.filter(\.isDefault).map(\.id), [first.id])
        library.setDefault(second)
        XCTAssertEqual(library.foods.filter(\.isDefault).map(\.id), [second.id])
        XCTAssertEqual(library.matches(for: "chocolat").first?.food.id, second.id)
    }

    func testLibraryPersistsAndRemoves() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let library = FoodLibrary(defaults: defaults)
        let milk = food("Lait", aliases: ["lait demi-écrémé"])
        library.save(milk)
        XCTAssertEqual(FoodLibrary(defaults: defaults).foods.map(\.name), ["Lait"])
        library.remove(milk)
        XCTAssertTrue(FoodLibrary(defaults: defaults).foods.isEmpty)
    }

    func testHasFoodMatching() {
        let library = FoodLibrary(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        let milk = food("Lait", aliases: ["lait entier"])
        library.save(milk)
        XCTAssertTrue(library.hasFood(matching: ["lait"]))
        XCTAssertFalse(library.hasFood(matching: ["lait"], excluding: milk.id))
        XCTAssertFalse(library.hasFood(matching: ["farine"]))
    }
}

final class RecipeCalculatorTests: XCTestCase {
    private let flour = FoodItem(name: "Farine", facts: NutritionFacts(
        energyKcal: 350, fat: 1, saturatedFat: 0.2, carbohydrates: 73, sugars: 1, fiber: 3, protein: 10, salt: 0.01))
    private let sugar = FoodItem(name: "Sucre", facts: NutritionFacts(
        energyKcal: 400, fat: 0, saturatedFat: 0, carbohydrates: 100, sugars: 100, fiber: 0, protein: 0, salt: 0))

    private func line(_ name: String, grams: Double, food: FoodItem?) -> RecipeLine {
        RecipeLine(name: name, quantity: grams, unit: .gram, grams: grams, food: food.map { .library($0.id) })
    }

    func testPer100gWithoutFinalWeight() throws {
        let lines = [line("farine", grams: 200, food: flour), line("sucre", grams: 100, food: sugar)]
        let result = try XCTUnwrap(RecipeCalculator.calculate(lines: lines, finalWeight: nil, servings: nil, library: [flour, sugar]))
        // Total : 200 g de farine (700 kcal) + 100 g de sucre (400 kcal) = 1100 kcal pour 300 g.
        XCTAssertEqual(result.totals.energyKcal ?? 0, 1100, accuracy: 1e-9)
        XCTAssertEqual(result.referenceWeight, 300)
        XCTAssertFalse(result.usesFinalWeight)
        XCTAssertEqual(result.per100g.energyKcal ?? 0, 1100.0 / 3, accuracy: 1e-9)
        XCTAssertEqual(result.per100g.sugars ?? 0, 102.0 / 3, accuracy: 1e-9)
        XCTAssertFalse(result.isPartial)
        XCTAssertNil(result.perServing)
    }

    func testFinalWeightReplacesRawWeightForPer100gOnly() throws {
        let lines = [line("farine", grams: 200, food: flour), line("sucre", grams: 100, food: sugar)]
        let result = try XCTUnwrap(RecipeCalculator.calculate(lines: lines, finalWeight: 250, servings: nil, library: [flour, sugar]))
        XCTAssertEqual(result.totals.energyKcal ?? 0, 1100, accuracy: 1e-9)
        XCTAssertEqual(result.rawWeight, 300)
        XCTAssertEqual(result.referenceWeight, 250)
        XCTAssertTrue(result.usesFinalWeight)
        XCTAssertEqual(result.per100g.energyKcal ?? 0, 440, accuracy: 1e-9)
    }

    func testZeroFinalWeightFallsBackToRawWeight() throws {
        let result = try XCTUnwrap(RecipeCalculator.calculate(lines: [line("farine", grams: 100, food: flour)], finalWeight: 0, servings: nil, library: [flour]))
        XCTAssertFalse(result.usesFinalWeight)
    }

    func testPerServing() throws {
        let lines = [line("farine", grams: 200, food: flour), line("sucre", grams: 100, food: sugar)]
        let result = try XCTUnwrap(RecipeCalculator.calculate(lines: lines, finalWeight: nil, servings: 4, library: [flour, sugar]))
        XCTAssertEqual(result.perServing?.energyKcal ?? 0, 275, accuracy: 1e-9)
        XCTAssertEqual(result.servings, 4)
        XCTAssertNil(try XCTUnwrap(RecipeCalculator.calculate(lines: lines, finalWeight: nil, servings: 0, library: [flour, sugar])).perServing)
    }

    func testMissingNutrientIsPartialNeverZero() throws {
        var noFiber = sugar
        noFiber.facts.fiber = nil
        let lines = [line("farine", grams: 100, food: flour), line("sucre", grams: 100, food: noFiber)]
        let result = try XCTUnwrap(RecipeCalculator.calculate(lines: lines, finalWeight: nil, servings: nil, library: [flour, noFiber]))
        XCTAssertTrue(result.isPartial)
        XCTAssertEqual(result.incomplete[.fiber], ["sucre"])
        XCTAssertNil(result.per100g.fiber)
        XCTAssertEqual(result.totals.fiber ?? 0, 3, accuracy: 1e-9) // somme des valeurs connues, affichée comme partielle
        XCTAssertNotNil(result.per100g.protein)
    }

    func testCalculationBlockedByMissingWeightOrFood() {
        let noWeight = RecipeLine(name: "sel", quantity: nil, unit: .gram, grams: nil, food: .library(flour.id))
        let noFood = line("farine", grams: 100, food: nil)
        XCTAssertNil(RecipeCalculator.calculate(lines: [noWeight], finalWeight: nil, servings: nil, library: [flour]))
        XCTAssertNil(RecipeCalculator.calculate(lines: [noFood], finalWeight: nil, servings: nil, library: [flour]))
        XCTAssertEqual(RecipeCalculator.blockers(in: [noWeight, noFood]).map(\.blocker), [.missingWeight, .missingFood])
        XCTAssertNil(RecipeCalculator.calculate(lines: [], finalWeight: nil, servings: nil, library: []))
    }

    func testDeletedFoodBecomesToAssociate() {
        let recipe = Recipe(name: "Gâteau", lines: [line("farine", grams: 100, food: flour)])
        let refreshed = recipe.refreshed(in: [])
        XCTAssertNil(refreshed.lines[0].food)
        XCTAssertNotNil(RecipeCalculator.blockers(in: refreshed.lines).first)
    }

    func testRecipeRecalculatesWhenFoodChanges() throws {
        let recipe = Recipe(name: "Gâteau", lines: [line("farine", grams: 100, food: flour)])
        var richer = flour
        richer.facts.energyKcal = 500
        let before = try XCTUnwrap(RecipeCalculator.calculate(lines: recipe.refreshed(in: [flour]).lines, finalWeight: nil, servings: nil, library: [flour]))
        let after = try XCTUnwrap(RecipeCalculator.calculate(lines: recipe.refreshed(in: [richer]).lines, finalWeight: nil, servings: nil, library: [richer]))
        XCTAssertEqual(before.per100g.energyKcal, 350)
        XCTAssertEqual(after.per100g.energyKcal, 500)
    }

    func testFoodUnitWeightChangeUpdatesPieceWeight() {
        var egg = FoodItem(name: "Œuf", unitWeightGrams: 60)
        let line = RecipeLine(name: "œufs", quantity: 2, unit: .piece, food: nil).autoAssociated(in: [egg])
        XCTAssertEqual(line.grams, 120)
        XCTAssertTrue(line.foodNeedsReview)
        egg.unitWeightGrams = 50
        XCTAssertEqual(line.refreshed(in: [egg]).grams, 100)
    }

    func testCustomFoodNeedsNoLibrary() throws {
        let custom = FoodItem(name: "Mon pain", facts: NutritionFacts(energyKcal: 250, protein: 8))
        let line = RecipeLine(name: "pain", quantity: 100, unit: .gram, grams: 100, food: .custom(custom))
        let result = try XCTUnwrap(RecipeCalculator.calculate(lines: [line], finalWeight: nil, servings: nil, library: []))
        XCTAssertEqual(result.per100g.energyKcal, 250)
    }

    // MARK: - Intégration avec le moteur de scoring

    func testScoringEngineIsAppliedToTheRecipeAsAProduct() throws {
        let chicken = FoodItem(name: "Poulet", facts: NutritionFacts(
            energyKcal: 110, fat: 1.5, saturatedFat: 0.3, carbohydrates: 0, sugars: 0, fiber: 0, protein: 23, salt: 0.15))
        let calculation = try XCTUnwrap(RecipeCalculator.calculate(
            lines: [line("poulet", grams: 200, food: chicken)], finalWeight: nil, servings: nil, library: [chicken]))
        let product = calculation.product(named: "Poulet rôti")
        XCTAssertEqual(product.source, .recipe)
        let direct = ScoringEngine.evaluate(chicken.facts, config: DefaultProfiles.balanced)
        let evaluation = ScoringEngine.evaluate(product.facts, config: DefaultProfiles.balanced)
        XCTAssertEqual(evaluation.criteria.map(\.level), direct.criteria.map(\.level))
        XCTAssertEqual(evaluation.criteria.first { $0.criterion == .protein }?.per100kcal ?? 0, 23.0 / 110 * 100, accuracy: 1e-9)
    }

    func testPartialRecipeIgnoresIncompleteCriterionInScoring() throws {
        var noSalt = flour
        noSalt.facts.salt = nil
        let calculation = try XCTUnwrap(RecipeCalculator.calculate(
            lines: [line("farine", grams: 100, food: noSalt)], finalWeight: nil, servings: nil, library: [noSalt]))
        let evaluation = ScoringEngine.evaluate(calculation.per100g, config: DefaultProfiles.balanced)
        XCTAssertTrue(evaluation.missing.contains(.salt))
    }

    // MARK: - Stockage des recettes

    func testRecipeStorePersistsDuplicatesAndRemoves() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let store = RecipeStore(defaults: defaults)
        let recipe = Recipe(name: "Gâteau", lines: [line("farine", grams: 100, food: flour)], finalWeight: 90, servings: 6)
        store.save(recipe)
        let copy = store.duplicate(recipe)
        XCTAssertNotEqual(copy.id, recipe.id)
        XCTAssertNotEqual(copy.lines[0].id, recipe.lines[0].id)

        let reloaded = RecipeStore(defaults: defaults)
        XCTAssertEqual(reloaded.recipes.count, 2)
        XCTAssertEqual(reloaded.recipe(id: recipe.id)?.finalWeight, 90)
        XCTAssertEqual(reloaded.recipe(id: recipe.id)?.lines.first?.food, .library(flour.id))
        reloaded.remove(recipe)
        XCTAssertEqual(RecipeStore(defaults: defaults).recipes.map(\.id), [copy.id])
    }

    func testEndToEndPastedRecipe() throws {
        let milk = FoodItem(name: "Lait", facts: NutritionFacts(energyKcal: 46, fat: 1.6, saturatedFat: 1, carbohydrates: 4.8, sugars: 4.8, fiber: 0, protein: 3.2, salt: 0.1), aliases: ["lait demi-écrémé"])
        let egg = FoodItem(name: "Œuf", facts: NutritionFacts(energyKcal: 140, fat: 10, saturatedFat: 3, carbohydrates: 1, sugars: 0.5, fiber: 0, protein: 12.5, salt: 0.35))
        let library = [milk, egg, flour]
        let parsed = RecipeTextParser.parse("""
        Ingrédients
        250 g de farine
        3 œufs
        50 cl de lait
        """)
        let lines = parsed.lines.map { RecipeLine(parsed: $0).autoAssociated(in: library).refreshed(in: library) }
        XCTAssertEqual(lines.compactMap(\.grams), [250, 165, 515])
        XCTAssertTrue(lines.allSatisfy { (line: RecipeLine) in line.foodNeedsReview })
        let result = try XCTUnwrap(RecipeCalculator.calculate(lines: lines, finalWeight: nil, servings: nil, library: library))
        XCTAssertEqual(result.referenceWeight, 930)
        let expectedKcal = (250 * 3.5 + 165 * 1.4 + 515 * 0.46) / 930 * 100
        XCTAssertEqual(result.per100g.energyKcal ?? 0, expectedKcal, accuracy: 0.01)
    }
}
