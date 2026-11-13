import XCTest
@testable import NutriRatio

final class NutritionLabelParserTests: XCTestCase {
    private func assertFacts(
        _ facts: NutritionFacts, _ expected: [NutrientField: Double?],
        accuracy: Double = 0.01, file: StaticString = #filePath, line: UInt = #line
    ) {
        for field in NutrientField.allCases {
            let want = expected[field] ?? nil
            switch (facts[field], want) {
            case (nil, nil):
                continue
            case (let got?, let want?):
                XCTAssertEqual(got, want, accuracy: accuracy, "\(field)", file: file, line: line)
            case (let got, let want):
                XCTFail("\(field) : obtenu \(String(describing: got)), attendu \(String(describing: want))", file: file, line: line)
            }
        }
    }

    // 1. Étiquette française standard, une colonne « pour 100 g ».
    func testFrenchSingleColumn() {
        let text = """
        VALEURS NUTRITIONNELLES MOYENNES pour 100 g
        Énergie 1883 kJ / 450 kcal
        Matières grasses 18 g
        dont acides gras saturés 5,6 g
        Glucides 62 g
        dont sucres 24 g
        Fibres alimentaires 4,5 g
        Protéines 7,2 g
        Sel 0,83 g
        """
        let parsed = NutritionLabelParser.parse(text)
        XCTAssertEqual(parsed.basis, .per100)
        assertFacts(parsed.facts, [
            .energy: 450, .fat: 18, .saturatedFat: 5.6, .carbohydrates: 62,
            .sugars: 24, .fiber: 4.5, .protein: 7.2, .salt: 0.83,
        ])
        XCTAssertTrue(parsed.doubtful.isEmpty)
    }

    // 2. Deux colonnes (100 g puis portion) et pourcentages d'apports de référence.
    func testFrenchTwoColumnsWithReferenceIntake() {
        let text = """
        Valeurs nutritionnelles moyennes Pour 100 g Par portion (30 g) % AR*
        Énergie 1 590 kJ / 378 kcal 477 kJ / 113 kcal 6 %
        Matières grasses 6,5 g 2,0 g 3 %
        dont acides gras saturés 1,2 g 0,4 g 2 %
        Glucides 67 g 20 g 8 %
        dont sucres 21 g 6,3 g 7 %
        Fibres 7,9 g 2,4 g
        Protéines 9,0 g 2,7 g 5 %
        Sel 0,75 g 0,23 g 4 %
        *Apport de référence pour un adulte-type (8400 kJ / 2000 kcal)
        """
        let parsed = NutritionLabelParser.parse(text)
        XCTAssertEqual(parsed.basis, .per100)
        assertFacts(parsed.facts, [
            .energy: 378, .fat: 6.5, .saturatedFat: 1.2, .carbohydrates: 67,
            .sugars: 21, .fiber: 7.9, .protein: 9, .salt: 0.75,
        ])
        XCTAssertTrue(parsed.doubtful.isEmpty)
    }

    // 3. Étiquette anglaise : colonne « per serving » AVANT la colonne « per 100g ».
    func testEnglishServingColumnFirst() {
        let text = """
        Nutrition
        Typical values Per 30g serving Per 100g
        Energy 502kJ/120kcal 1674kJ/400kcal
        Fat 3.6g 12g
        of which saturates 1.5g 5.0g
        Carbohydrate 19g 63g
        of which sugars 6.6g 22g
        Fibre 1.8g 6.0g
        Protein 2.4g 8.0g
        Salt 0.15g 0.50g
        """
        let parsed = NutritionLabelParser.parse(text)
        XCTAssertEqual(parsed.basis, .per100)
        assertFacts(parsed.facts, [
            .energy: 400, .fat: 12, .saturatedFat: 5, .carbohydrates: 63,
            .sugars: 22, .fiber: 6, .protein: 8, .salt: 0.5,
        ])
    }

    // 4. Seule colonne « par portion » : conversion vers 100 g grâce à la taille de portion.
    func testFrenchPerServingOnlyIsConverted() {
        let text = """
        Valeurs nutritionnelles par portion de 25 g
        Énergie 523 kJ / 125 kcal
        Matières grasses 6 g
        dont acides gras saturés 3 g
        Glucides 16 g
        dont sucres 8 g
        Fibres 0,5 g
        Protéines 1,5 g
        Sel 0,1 g
        """
        let parsed = NutritionLabelParser.parse(text)
        XCTAssertEqual(parsed.basis, .perServingConverted(grams: 25))
        assertFacts(parsed.facts, [
            .energy: 500, .fat: 24, .saturatedFat: 12, .carbohydrates: 64,
            .sugars: 32, .fiber: 2, .protein: 6, .salt: 0.4,
        ])
        // Toute valeur convertie doit être confirmée par l'utilisateur.
        XCTAssertEqual(parsed.doubtful, Set(NutrientField.allCases))
    }

    // 5. kJ seul, sodium en mg, « < 0,5 g », « traces », fibres absentes.
    func testKilojoulesOnlySodiumAndTraces() {
        let text = """
        Pour 100 ml
        Energie 180 kJ
        Matières grasses <0,5 g
        dont acides gras saturés traces
        Glucides 10,5 g
        dont sucres 10,2 g
        Protéines 0 g
        Sodium 20 mg
        """
        let parsed = NutritionLabelParser.parse(text)
        assertFacts(parsed.facts, [
            .energy: 180 / 4.184, .fat: 0.5, .saturatedFat: 0, .carbohydrates: 10.5,
            .sugars: 10.2, .fiber: nil, .protein: 0, .salt: 0.05,
        ])
        XCTAssertNil(parsed.facts.fiber, "une valeur absente ne doit pas être inventée")
        XCTAssertEqual(parsed.doubtful, [.fat, .salt])
    }

    // 6. Étiquette américaine « Nutrition Facts » : par portion, calories sans unité, % DV.
    func testUSNutritionFacts() {
        let text = """
        Nutrition Facts
        8 servings per container
        Serving size 2/3 cup (55g)
        Amount per serving
        Calories 230
        % Daily Value*
        Total Fat 8g 10%
        Saturated Fat 1g 5%
        Trans Fat 0g
        Cholesterol 0mg 0%
        Sodium 160mg 7%
        Total Carbohydrate 37g 13%
        Dietary Fiber 4g 14%
        Total Sugars 12g
        Includes 10g Added Sugars 20%
        Protein 3g
        """
        let parsed = NutritionLabelParser.parse(text)
        XCTAssertEqual(parsed.basis, .perServingConverted(grams: 55))
        let factor = 100.0 / 55
        assertFacts(parsed.facts, [
            .energy: 230 * factor, .fat: 8 * factor, .saturatedFat: 1 * factor,
            .carbohydrates: 37 * factor, .sugars: 12 * factor, .fiber: 4 * factor,
            .protein: 3 * factor, .salt: 0.16 * 2.5 * factor,
        ])
    }

    // 7. Valeurs nutritionnelles en ligne (paragraphe), fréquent sur les petits emballages.
    func testInlineParagraph() {
        let text = "Valeurs nutritionnelles moyennes pour 100 g : Énergie 1500 kJ (357 kcal), Matières grasses 12 g dont acides gras saturés 5 g, Glucides 50 g dont sucres 20 g, Fibres 3 g, Protéines 10 g, Sel 1,2 g (sodium x 2,5)."
        let parsed = NutritionLabelParser.parse(text)
        assertFacts(parsed.facts, [
            .energy: 357, .fat: 12, .saturatedFat: 5, .carbohydrates: 50,
            .sugars: 20, .fiber: 3, .protein: 10, .salt: 1.2,
        ])
    }

    // 8. OCR bruité : accents perdus, énergie sur deux lignes, libellé et valeur séparés,
    //    acides gras insaturés à ne pas confondre avec les saturés.
    func testNoisyOCR() {
        let text = """
        VALEURS NUTRITIONNELLES MOYENNES POUR 1OO g
        Energie 1046 kJ
        250 kcal
        Matieres grasses 9,5g
        dont acides gras satures 1,1g
        dont acides gras mono-insaturés 5,9g
        dont acides gras polyinsaturés 2,0g
        Glucides 30g
        dont sucres 2,4g
        Fibres alimentaires
        6,1 g
        Proteines 8,5g
        Sel (sodium x 2,5) 1,05g
        """
        let parsed = NutritionLabelParser.parse(text)
        XCTAssertEqual(parsed.basis, .per100)
        assertFacts(parsed.facts, [
            .energy: 250, .fat: 9.5, .saturatedFat: 1.1, .carbohydrates: 30,
            .sugars: 2.4, .fiber: 6.1, .protein: 8.5, .salt: 1.05,
        ])
    }

    // 9. Portion sans taille lisible : valeurs gardées telles quelles mais toutes douteuses.
    func testPerServingWithoutSizeIsFlagged() {
        let parsed = NutritionLabelParser.parse("Par portion\nÉnergie 120 kcal\nProtéines 4 g")
        XCTAssertEqual(parsed.basis, .perServingUnknown)
        assertFacts(parsed.facts, [.energy: 120, .protein: 4])
        XCTAssertEqual(parsed.doubtful, [.energy, .protein])
    }

    // 10. Incohérence (sucres > glucides) : les deux champs sont signalés.
    func testInconsistentValuesAreFlagged() {
        let parsed = NutritionLabelParser.parse("Pour 100 g\nÉnergie 200 kcal\nGlucides 10 g\ndont sucres 18 g")
        XCTAssertTrue(parsed.doubtful.isSuperset(of: [.sugars, .carbohydrates]))
    }

    // 11. Texte sans tableau : rien n'est inventé.
    func testUnrelatedTextYieldsNothing() {
        let parsed = NutritionLabelParser.parse("Ingrédients : farine de blé, sucre, huile de colza, sel.\nÀ conserver au sec. 250 g")
        XCTAssertTrue(parsed.facts.isEmpty)
    }

    // Assemblage des fragments OCR en lignes de tableau.
    func testOCRFragmentsAreAssembledIntoRows() {
        let fragments = [
            OCRFragment(text: "0,83 g", box: CGRect(x: 0.62, y: 0.401, width: 0.1, height: 0.03)),
            OCRFragment(text: "Protéines", box: CGRect(x: 0.1, y: 0.45, width: 0.2, height: 0.03)),
            OCRFragment(text: "Sel", box: CGRect(x: 0.1, y: 0.40, width: 0.06, height: 0.03)),
            OCRFragment(text: "7,2 g", box: CGRect(x: 0.62, y: 0.452, width: 0.1, height: 0.03)),
            OCRFragment(text: "Pour 100 g", box: CGRect(x: 0.6, y: 0.5, width: 0.2, height: 0.03)),
        ]
        let lines = OCRLineAssembler.lines(from: fragments)
        XCTAssertEqual(lines, ["Pour 100 g", "Protéines 7,2 g", "Sel 0,83 g"])
        let parsed = NutritionLabelParser.parse(lines: lines)
        assertFacts(parsed.facts, [.protein: 7.2, .salt: 0.83])
    }
}
