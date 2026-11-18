import XCTest
@testable import NutriRatio

final class BuiltInFoodsTests: XCTestCase {
    private func library() -> FoodLibrary {
        let defaults = UserDefaults(suiteName: "builtin-\(UUID().uuidString)")!
        return FoodLibrary(defaults: defaults)
    }

    func testIdsAreUniqueAndNamesDoNotCollide() {
        XCTAssertEqual(BuiltInFoods.ids.count, BuiltInFoods.all.count)
        var seen = Set<Set<String>>()
        for food in BuiltInFoods.all {
            for key in food.keys { XCTAssertTrue(seen.insert(key).inserted, "clé en double : \(food.name)") }
        }
    }

    func testEveryBuiltInHasCompleteFacts() {
        for food in BuiltInFoods.all {
            XCTAssertFalse(food.facts.isEmpty, food.name)
            for field in NutrientField.allCases { XCTAssertNotNil(food.facts[field], "\(food.name) : \(field)") }
        }
    }

    func testIngredientWithoutLibraryGetsBuiltInAndNoReview() throws {
        let lib = library()
        let line = RecipeLine(name: "farine").autoAssociated(in: lib.available)
        let food = try XCTUnwrap(line.food?.resolve(in: lib.available))
        XCTAssertEqual(food.name, "Farine")
        XCTAssertTrue(food.isBuiltIn)
        XCTAssertFalse(line.foodNeedsReview)
    }

    func testPartialNameNeedsReview() throws {
        let lib = library()
        let line = RecipeLine(name: "farine de sarrasin").autoAssociated(in: lib.available)
        XCTAssertNotNil(line.food)
        XCTAssertTrue(line.foodNeedsReview)
    }

    func testSpecificBuiltInBeatsGeneric() {
        let names = ["jaune d'oeuf": "Jaune d'œuf", "huile d'olive": "Huile d'olive", "lait de coco": "Lait de coco",
                     "pommes de terre": "Pomme de terre", "sucre vanillé": "Sucre vanillé", "pâte brisée": "Pâte brisée",
                     "noix de cajou": "Noix de cajou", "levure chimique": "Levure chimique", "bicarbonate de soude": "Bicarbonate de soude",
                     "extrait de vanille": "Extrait de vanille", "cream cheese": "Cream cheese", "Philadelphia": "Cream cheese",
                     "sachet de levure chimique": "Levure chimique", "oeufs": "Œuf", "pâtes": "Pâtes"]
        let lib = library()
        for (ingredient, expected) in names {
            XCTAssertEqual(lib.matches(for: ingredient).first?.food.name, expected, ingredient)
        }
    }

    func testUserFoodShadowsBuiltIn() throws {
        let lib = library()
        lib.save(FoodItem(name: "Chocolat", facts: NutritionFacts(energyKcal: 500)))
        XCTAssertEqual(lib.available.filter { $0.name == "Chocolat noir" }.count, 0)
        let match = try XCTUnwrap(lib.matches(for: "chocolat").first)
        XCTAssertFalse(match.food.isBuiltIn)
        XCTAssertEqual(match.food.facts.energyKcal, 500)
        XCTAssertTrue(lib.foods.allSatisfy { !$0.isBuiltIn })
    }

    func testRecipeCalculatesWithBuiltInsOnly() throws {
        let lib = library()
        var lines = [RecipeLine(name: "farine", quantity: 200, unit: .gram), RecipeLine(name: "sucre", quantity: 100, unit: .gram),
                     RecipeLine(name: "oeufs", quantity: 2, unit: .piece)]
        lines = lines.map { $0.autoAssociated(in: lib.available).refreshed(in: lib.available) }
        let result = try XCTUnwrap(RecipeCalculator.calculate(lines: lines, finalWeight: nil, servings: nil, library: lib.available))
        XCTAssertFalse(result.isPartial)
        XCTAssertNotNil(result.per100g.energyKcal)
        XCTAssertTrue(lib.foods.isEmpty, "les valeurs intégrées ne sont pas copiées dans Mon aliment")
    }
}

final class BuiltInRefreshTests: XCTestCase {
    func testSavedRecipeWithUnassociatedLinesGetsBuiltInsOnRefresh() throws {
        let lib = FoodLibrary(defaults: UserDefaults(suiteName: "refresh-\(UUID().uuidString)")!)
        let recipe = Recipe(name: "Piadina", lines: [RecipeLine(name: "farine", quantity: 250, unit: .gram),
                                                     RecipeLine(name: "huile d'olive", quantity: 2, unit: .tablespoon)])
        let refreshed = recipe.refreshed(in: lib.available)
        XCTAssertTrue(refreshed.lines.allSatisfy { $0.food != nil })
        XCTAssertNotNil(RecipeCalculator.calculate(lines: refreshed.lines, finalWeight: nil, servings: nil, library: lib.available))
    }
}
