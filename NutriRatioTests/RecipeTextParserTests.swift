import XCTest
@testable import NutriRatio

final class RecipeTextParserTests: XCTestCase {
    private func line(_ text: String, requireQuantity: Bool = false, file: StaticString = #filePath, line lineNumber: UInt = #line) throws -> ParsedLine {
        try XCTUnwrap(RecipeTextParser.parseLine(text, requireQuantity: requireQuantity), file: file, line: lineNumber)
    }

    func testFrenchGrams() throws {
        let parsed = try line("200 g de farine")
        XCTAssertEqual(parsed.quantity, 200)
        XCTAssertEqual(parsed.unit, .gram)
        XCTAssertEqual(parsed.name, "farine")
        XCTAssertTrue(parsed.notes.isEmpty)
    }

    func testGluedUnitAndDecimalComma() throws {
        let parsed = try line("1,5kg pommes de terre")
        XCTAssertEqual(parsed.quantity, 1.5)
        XCTAssertEqual(parsed.unit, .kilogram)
        XCTAssertEqual(parsed.name, "pommes de terre")
    }

    func testFractionsAndMixedNumbers() throws {
        XCTAssertEqual(try line("1/2 l de lait").quantity, 0.5)
        XCTAssertEqual(try line("½ cuillère à café de sel").quantity, 0.5)
        XCTAssertEqual(try line("1 1/2 tasse de sucre").quantity, 1.5)
        XCTAssertEqual(try line("1½ cup flour").quantity, 1.5)
        XCTAssertEqual(try line("1½ cup flour").unit, .cup)
    }

    func testRangeTakesAverageAndIsFlagged() throws {
        for text in ["2 à 3 oeufs", "2-3 oeufs", "2 to 3 eggs"] {
            let parsed = try line(text)
            XCTAssertEqual(parsed.quantity, 2.5, text)
            XCTAssertTrue(parsed.notes.contains(.rangeAveraged), text)
        }
    }

    func testSpoonsAndTeaspoonsInManyForms() throws {
        for text in ["2 c. à soupe d'huile d'olive", "2 cuillères à soupe d'huile d'olive", "2 càs d'huile d'olive", "2 tbsp olive oil"] {
            let parsed = try line(text)
            XCTAssertEqual(parsed.unit, .tablespoon, text)
            XCTAssertEqual(parsed.quantity, 2, text)
        }
        for text in ["1 c. à café de sel", "1 cac de sel", "1 tsp salt", "1 cuillère à café de sel"] {
            XCTAssertEqual(try line(text).unit, .teaspoon, text)
        }
        XCTAssertEqual(try line("2 c. à soupe d'huile d'olive").name, "huile d'olive")
    }

    func testOtherUnits() throws {
        XCTAssertEqual(try line("25 cl de crème").unit, .centiliter)
        XCTAssertEqual(try line("1 dl de vin").unit, .deciliter)
        XCTAssertEqual(try line("1 verre de lait").unit, .glass)
        XCTAssertEqual(try line("2 tasses de farine").unit, .cup)
        XCTAssertEqual(try line("500 mg de safran").unit, .milligram)
        XCTAssertEqual(try line("2 l d'eau").unit, .liter)
    }

    func testPinchAndKnob() throws {
        let pinch = try line("une pincée de sel")
        XCTAssertEqual(pinch.unit, .pinch)
        XCTAssertEqual(pinch.quantity, 1)
        let knob = try line("1 noix de beurre")
        XCTAssertEqual(knob.unit, .knob)
        XCTAssertEqual(knob.name, "beurre")
        // « noix de coco » est un ingrédient, pas une noix de beurre.
        let coco = try line("2 noix de coco")
        XCTAssertEqual(coco.unit, .piece)
        XCTAssertEqual(coco.name, "noix de coco")
    }

    func testCountedPieces() throws {
        let eggs = try line("2 œufs")
        XCTAssertEqual(eggs.quantity, 2)
        XCTAssertEqual(eggs.unit, .piece)
        XCTAssertEqual(eggs.name, "œufs")
        let garlic = try line("3 gousses d'ail")
        XCTAssertEqual(garlic.unit, .piece)
        XCTAssertEqual(garlic.name, "gousses d'ail")
        XCTAssertEqual(try line("un oignon").quantity, 1)
        XCTAssertEqual(try line("deux carottes").quantity, 2)
    }

    func testVagueQuantitiesAreFlagged() throws {
        for text in ["un peu de poivre", "quelques feuilles de basilic", "a few basil leaves"] {
            let parsed = try line(text)
            XCTAssertNil(parsed.quantity, text)
            XCTAssertTrue(parsed.notes.contains(.vagueQuantity), text)
        }
        XCTAssertEqual(try line("un peu de poivre").name, "poivre")
    }

    func testLineWithoutQuantityIsKeptWhenAllowed() throws {
        let parsed = try line("Sel")
        XCTAssertNil(parsed.quantity)
        XCTAssertTrue(parsed.notes.contains(.noQuantity))
        XCTAssertNil(RecipeTextParser.parseLine("Sel", requireQuantity: true))
    }

    func testNameCleaningKeepsOriginalText() throws {
        let parsed = try line("- 1 oignon haché finement, pour la sauce")
        XCTAssertEqual(parsed.name, "oignon")
        XCTAssertEqual(parsed.originalText, "1 oignon haché finement, pour la sauce")
        XCTAssertEqual(try line("200 g de carottes coupées en dés").name, "carottes")
        XCTAssertEqual(try line("100 g de fromage râpé").name, "fromage")
        XCTAssertEqual(try line("2 tbsp chopped parsley").name, "parsley")
        XCTAssertEqual(try line("1 tomate (bien mûre)").name, "tomate")
        // « crème fraîche » est un produit : « fraîche » n'est pas retiré.
        XCTAssertEqual(try line("20 cl de crème fraîche").name, "crème fraîche")
    }

    func testBulletsAndNumbering() throws {
        XCTAssertEqual(try line("• 100 g de sucre").quantity, 100)
        XCTAssertEqual(try line("1) 100 g de sucre").quantity, 100)
        XCTAssertEqual(try line("✓ 100 g de sucre").name, "sucre")
    }

    func testApproximation() throws {
        let parsed = try line("environ 200 g de farine")
        XCTAssertEqual(parsed.quantity, 200)
        XCTAssertEqual(parsed.name, "farine")
    }

    func testDurationsAreNotIngredients() {
        XCTAssertNil(RecipeTextParser.parseLine("20 minutes de cuisson", requireQuantity: true))
        XCTAssertNil(RecipeTextParser.parseLine("4 personnes", requireQuantity: true))
    }

    // MARK: - Recettes complètes

    func testRecipeWithIngredientSectionIgnoresSteps() {
        let text = """
        Crêpes maison

        Ingrédients (pour 4 personnes) :
        - 250 g de farine
        - 3 œufs
        - ½ litre de lait
        - 1 pincée de sel
        Sel et poivre

        Préparation :
        1. Mélanger la farine et les œufs dans un saladier.
        2. Ajouter 50 cl de lait petit à petit.
        3. Cuire 2 minutes de chaque côté.
        """
        let recipe = RecipeTextParser.parse(text)
        XCTAssertEqual(recipe.title, "Crêpes maison")
        XCTAssertEqual(recipe.servings, 4)
        XCTAssertEqual(recipe.lines.map(\.name), ["farine", "œufs", "lait", "sel", "Sel et poivre"])
    }

    func testEnglishRecipe() {
        let text = """
        Ingredients
        1 cup flour
        2 eggs
        1/2 tsp salt
        a pinch of pepper

        Directions
        1. Preheat the oven to 180°C.
        2. Mix 2 cups of everything.
        """
        let recipe = RecipeTextParser.parse(text)
        XCTAssertEqual(recipe.lines.count, 4)
        XCTAssertEqual(recipe.lines[0].unit, .cup)
        XCTAssertEqual(recipe.lines[3].unit, .pinch)
    }

    func testTextWithoutHeadingKeepsOnlyQuantityLines() {
        let text = """
        200 g de farine
        3 œufs
        Mélanger le tout.
        Préchauffer le four à 180°C pendant 20 minutes.
        1. Verser dans un moule.
        """
        let recipe = RecipeTextParser.parse(text)
        XCTAssertEqual(recipe.lines.map(\.name), ["farine", "œufs"])
    }

    func testSubheadingsInsideIngredientSectionAreSkipped() {
        let text = """
        Ingrédients
        Pour la pâte :
        200 g de farine
        Pour la garniture
        3 pommes
        """
        XCTAssertEqual(RecipeTextParser.parse(text).lines.map(\.name), ["farine", "pommes"])
    }

    func testTwoIngredientSectionsAreMerged() {
        let text = """
        Ingrédients de la pâte
        200 g de farine
        Préparation de la pâte
        Mélanger.
        Ingrédients de la crème
        20 cl de lait
        """
        XCTAssertEqual(RecipeTextParser.parse(text).lines.map(\.name), ["farine", "lait"])
    }

    func testEmptyText() {
        XCTAssertTrue(RecipeTextParser.parse("").lines.isEmpty)
        XCTAssertTrue(RecipeTextParser.parse("   \n  ").lines.isEmpty)
    }
}
