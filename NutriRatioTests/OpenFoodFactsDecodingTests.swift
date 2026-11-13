import XCTest
@testable import NutriRatio

final class OpenFoodFactsDecodingTests: XCTestCase {
    private func fixture(_ name: String) throws -> Data {
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = Bundle(for: Self.self)
        #endif
        let url = try XCTUnwrap(bundle.url(forResource: name, withExtension: "json"))
        return try Data(contentsOf: url)
    }

    func testDecodesCompleteProduct() throws {
        let fetched = try OpenFoodFactsService.decodeProduct(from: fixture("off_product"), barcode: "3000000000017")
        let product = fetched.product
        XCTAssertEqual(product.name, "Pâte à tartiner aux noisettes")
        XCTAssertEqual(product.brand, "Marque Exemple")
        XCTAssertEqual(product.barcode, "3000000000017")
        XCTAssertEqual(product.servingSize, "15 g")
        XCTAssertEqual(product.source, .barcode)
        XCTAssertEqual(product.facts, NutritionFacts(
            energyKcal: 539, fat: 30.9, saturatedFat: 10.6, carbohydrates: 57.5,
            sugars: 56.3, // fourni sous forme de texte dans la fixture
            fiber: 0, protein: 6.3, salt: 0.107
        ))
        XCTAssertTrue(fetched.doubtful.isEmpty)
    }

    func testIncompleteNutrimentsStayMissing() throws {
        let fetched = try OpenFoodFactsService.decodeProduct(from: fixture("off_incomplete"), barcode: "3000000000024")
        let facts = fetched.product.facts
        XCTAssertEqual(fetched.product.name, "Soupe de légumes")
        XCTAssertNil(fetched.product.brand)
        // Énergie en kJ seulement → conversion ; sel déduit du sodium.
        XCTAssertEqual(try XCTUnwrap(facts.energyKcal), 150 / 4.184, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(facts.salt), 0.75, accuracy: 1e-9)
        XCTAssertEqual(fetched.doubtful, [.energy, .salt])
        // Les valeurs absentes ne sont jamais inventées.
        XCTAssertNil(facts.saturatedFat)
        XCTAssertNil(facts.sugars)
        XCTAssertNil(facts.fiber)
    }

    func testUnknownProductThrowsNotFound() {
        let json = Data(#"{"code":"00000000","status":0,"status_verbose":"product not found"}"#.utf8)
        XCTAssertThrowsError(try OpenFoodFactsService.decodeProduct(from: json, barcode: "00000000")) { error in
            XCTAssertEqual(error as? OpenFoodFactsService.ServiceError, .productNotFound)
        }
    }

    func testProductWithoutNutrimentsIsEmptyNotAnError() throws {
        let json = Data(#"{"status":1,"product":{"product_name":"Mystère"}}"#.utf8)
        let fetched = try OpenFoodFactsService.decodeProduct(from: json, barcode: "12345678")
        XCTAssertTrue(fetched.product.facts.isEmpty)
    }

    func testGarbageThrowsInvalidResponse() {
        XCTAssertThrowsError(try OpenFoodFactsService.decodeProduct(from: Data("<html>".utf8), barcode: "12345678")) { error in
            XCTAssertEqual(error as? OpenFoodFactsService.ServiceError, .invalidResponse)
        }
    }

    func testBarcodeValidation() {
        XCTAssertTrue(OpenFoodFactsService.isValidBarcode("3017620422003"))
        XCTAssertTrue(OpenFoodFactsService.isValidBarcode("96385074"))
        XCTAssertFalse(OpenFoodFactsService.isValidBarcode("12345"))
        XCTAssertFalse(OpenFoodFactsService.isValidBarcode("30176204220/3"))
        XCTAssertFalse(OpenFoodFactsService.isValidBarcode(""))
    }
}
