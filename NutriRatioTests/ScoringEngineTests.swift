import XCTest
@testable import NutriRatio

final class ScoringEngineTests: XCTestCase {
    private let balanced = DefaultProfiles.balanced
    private let cutting = DefaultProfiles.cutting
    private let bulking = DefaultProfiles.bulking

    /// Blanc de poulet : 110 kcal, 23 g de protéines, pas de fibres.
    private let chicken = NutritionFacts(
        energyKcal: 110, fat: 1.5, saturatedFat: 0.3, carbohydrates: 0, sugars: 0,
        fiber: 0, protein: 23, salt: 0.15
    )

    private func titles(_ results: [CriterionResult]) -> [Criterion] {
        results.map(\.criterion)
    }

    // MARK: Niveaux

    func testLevels() {
        let protein = balanced.protein
        XCTAssertEqual(ScoringEngine.level(for: 2.99, thresholds: protein, direction: .moreIsBetter), .notInteresting)
        XCTAssertEqual(ScoringEngine.level(for: 3, thresholds: protein, direction: .moreIsBetter), .average)
        XCTAssertEqual(ScoringEngine.level(for: 5, thresholds: protein, direction: .moreIsBetter), .interesting)
        let salt = balanced.salt
        XCTAssertEqual(ScoringEngine.level(for: 0.25, thresholds: salt, direction: .lessIsBetter), .interesting)
        XCTAssertEqual(ScoringEngine.level(for: 0.33, thresholds: salt, direction: .lessIsBetter), .average)
        XCTAssertEqual(ScoringEngine.level(for: 0.34, thresholds: salt, direction: .lessIsBetter), .notInteresting)
    }

    func testPer100kcalNormalisation() throws {
        let evaluation = ScoringEngine.evaluate(chicken, config: balanced)
        let protein = try XCTUnwrap(evaluation.criteria.first { $0.criterion == .protein })
        XCTAssertEqual(protein.per100kcal, 23.0 / 110 * 100, accuracy: 1e-9)
        XCTAssertEqual(protein.per100g, 23)
    }

    // MARK: Profils

    func testChickenAcrossProfiles() {
        for config in [balanced, cutting, bulking] {
            let evaluation = ScoringEngine.evaluate(chicken, config: config)
            XCTAssertNil(evaluation.notApplicable)
            XCTAssertEqual(titles(evaluation.strengths), [.protein])
            XCTAssertTrue(evaluation.cautions.isEmpty)
        }
    }

    func testCuttingIsStricterOnProtein() throws {
        // 6 g de protéines pour 100 kcal : « riche » en Équilibré, seulement correct en Sèche.
        let facts = NutritionFacts(energyKcal: 100, protein: 6)
        let balancedResult = try XCTUnwrap(ScoringEngine.evaluate(facts, config: balanced).criteria.first)
        let cuttingResult = try XCTUnwrap(ScoringEngine.evaluate(facts, config: cutting).criteria.first)
        XCTAssertEqual(balancedResult.level, .interesting)
        XCTAssertEqual(cuttingResult.level, .average)
    }

    func testBulkingToleratesMoreSugar() throws {
        // 2,5 g de sucres pour 100 kcal : moyen en Équilibré, bas en Prise de masse.
        let facts = NutritionFacts(energyKcal: 400, sugars: 10)
        XCTAssertEqual(ScoringEngine.evaluate(facts, config: balanced).criteria.first?.level, .average)
        XCTAssertEqual(ScoringEngine.evaluate(facts, config: bulking).criteria.first?.level, .interesting)
    }

    func testSodaHasNoStrengthAndTooMuchSugar() {
        let soda = NutritionFacts(energyKcal: 42, fat: 0, saturatedFat: 0, carbohydrates: 10.6, sugars: 10.6, fiber: 0, protein: 0, salt: 0)
        for config in [balanced, cutting, bulking] {
            let evaluation = ScoringEngine.evaluate(soda, config: config)
            XCTAssertTrue(evaluation.strengths.isEmpty)
            XCTAssertEqual(titles(evaluation.cautions), [.sugars])
        }
    }

    /// Fromage blanc 0 % : l'absence de fibres et le lactose ne doivent pas masquer les protéines.
    func testFromageBlancIsInterestingForProtein() {
        let fromageBlanc = NutritionFacts(energyKcal: 46, fat: 0.2, saturatedFat: 0.1, carbohydrates: 4, sugars: 4, fiber: 0, protein: 7.5, salt: 0.1)
        let evaluation = ScoringEngine.evaluate(fromageBlanc, config: balanced)
        XCTAssertEqual(titles(evaluation.strengths), [.protein])
        XCTAssertEqual(titles(evaluation.cautions), [.sugars])
    }

    func testStrengthsAndCautionsFollowDirection() {
        // Protéines et fibres excellentes, mais 20 g de sucres pour 100 kcal.
        let facts = NutritionFacts(energyKcal: 100, saturatedFat: 0, sugars: 20, fiber: 5, protein: 10, salt: 0)
        let evaluation = ScoringEngine.evaluate(facts, config: balanced)
        XCTAssertEqual(titles(evaluation.strengths), [.protein, .fiber])
        XCTAssertEqual(titles(evaluation.cautions), [.sugars])
    }

    func testCustomStartsAsBalancedCopy() {
        XCTAssertEqual(DefaultProfiles.config(for: .custom), DefaultProfiles.balanced)
    }

    func testDefaultProfilesAreValid() {
        for kind in ProfileKind.allCases {
            XCTAssertTrue(DefaultProfiles.config(for: kind).isValid, kind.rawValue)
        }
    }

    // MARK: Données manquantes et cas limites

    func testMissingCriterionIsIgnored() {
        var facts = chicken
        facts.fiber = nil
        let evaluation = ScoringEngine.evaluate(facts, config: balanced)
        XCTAssertEqual(evaluation.missing, [.fiber])
        XCTAssertEqual(evaluation.criteria.count, 4)
    }

    func testVeryLowEnergyIsNotApplicable() {
        let coffee = NutritionFacts(energyKcal: 2, sugars: 0, protein: 0.1, salt: 0)
        XCTAssertEqual(ScoringEngine.evaluate(coffee, config: balanced).notApplicable, .energyTooLow)
        let water = NutritionFacts(energyKcal: 0, sugars: 0, protein: 0, salt: 0)
        XCTAssertEqual(ScoringEngine.evaluate(water, config: balanced).notApplicable, .energyTooLow)
    }

    func testEnergyThresholdIsInclusive() {
        let facts = NutritionFacts(energyKcal: 5, protein: 1)
        XCTAssertNil(ScoringEngine.evaluate(facts, config: balanced).notApplicable)
    }

    func testMissingEnergyIsNotApplicable() {
        let facts = NutritionFacts(sugars: 5, protein: 10)
        XCTAssertEqual(ScoringEngine.evaluate(facts, config: balanced).notApplicable, .missingEnergy)
    }

    func testNoCriteriaIsNotApplicable() {
        let facts = NutritionFacts(energyKcal: 200, fat: 10, carbohydrates: 20)
        let evaluation = ScoringEngine.evaluate(facts, config: balanced)
        XCTAssertEqual(evaluation.notApplicable, .noCriteria)
        XCTAssertEqual(evaluation.missing.count, Criterion.allCases.count)
    }

    func testNegativeValueIsIgnoredAndReported() {
        let facts = NutritionFacts(energyKcal: 100, sugars: -3, protein: 5)
        let evaluation = ScoringEngine.evaluate(facts, config: balanced)
        XCTAssertTrue(evaluation.missing.contains(.sugars))
        XCTAssertTrue(evaluation.warnings.contains(.negativeValue(.sugars)))
    }

    // MARK: Incohérences

    func testSugarsAboveCarbohydratesWarning() {
        let facts = NutritionFacts(energyKcal: 200, fat: 5, saturatedFat: 6, carbohydrates: 10, sugars: 15, protein: 5)
        let warnings = ScoringEngine.evaluate(facts, config: balanced).warnings
        XCTAssertTrue(warnings.contains(.sugarsExceedCarbohydrates))
        XCTAssertTrue(warnings.contains(.saturatedExceedsFat))
    }

    func testEnergyMismatchWarning() {
        // 9×30 + 4×50 + 4×10 = 510 kcal estimées, 150 déclarées.
        let facts = NutritionFacts(energyKcal: 150, fat: 30, carbohydrates: 50, protein: 10)
        let warnings = facts.consistencyWarnings
        XCTAssertTrue(warnings.contains { if case .energyMismatch = $0 { true } else { false } })
    }

    func testConsistentProductHasNoWarning() {
        XCTAssertTrue(chicken.consistencyWarnings.isEmpty)
    }

    // MARK: Explications

    func testExplanationSentence() throws {
        let facts = NutritionFacts(energyKcal: 100, sugars: 14, protein: 9)
        let evaluation = ScoringEngine.evaluate(facts, config: balanced)
        let protein = try XCTUnwrap(evaluation.criteria.first { $0.criterion == .protein })
        let sugars = try XCTUnwrap(evaluation.criteria.first { $0.criterion == .sugars })
        XCTAssertEqual(protein.explanation, "Protéines : 9 g pour 100 kcal, très bon")
        XCTAssertEqual(sugars.explanation, "Sucres : 14 g pour 100 kcal, élevé")
    }

    // MARK: Persistance des profils

    func testProfileStorePersistsAndResets() throws {
        let suiteName = "NutriRatioTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = ProfileStore(defaults: defaults)
        var config = store.config(for: .cutting)
        config.protein.low = 6
        store.setConfig(config, for: .cutting)
        store.selected = .cutting

        let reloaded = ProfileStore(defaults: defaults)
        XCTAssertEqual(reloaded.selected, .cutting)
        XCTAssertEqual(reloaded.config(for: .cutting).protein.low, 6)
        XCTAssertEqual(reloaded.config(for: .balanced), DefaultProfiles.balanced)

        // Une configuration invalide (bas ≥ haut) est refusée.
        config.protein.low = 9
        reloaded.setConfig(config, for: .cutting)
        XCTAssertEqual(reloaded.config(for: .cutting).protein.low, 6)

        reloaded.reset(.cutting)
        XCTAssertEqual(ProfileStore(defaults: defaults).config(for: .cutting), DefaultProfiles.cutting)
    }

    // MARK: Apports quotidiens

    func testDailyIntakeDefaultsAreValid() {
        XCTAssertTrue(DefaultProfiles.dailyIntake.isValid)
        XCTAssertEqual(DefaultProfiles.dailyIntake.percentOfEnergyPer100kcal, 5, accuracy: 1e-9)
    }

    func testDailyIntakePercent() throws {
        // Fromage blanc 0 % : 16,3 g de protéines pour 100 kcal = 32,6 % des 50 g quotidiens.
        let facts = NutritionFacts(energyKcal: 46, sugars: 4, protein: 7.5)
        let evaluation = ScoringEngine.evaluate(facts, config: balanced)
        let protein = try XCTUnwrap(evaluation.criteria.first { $0.criterion == .protein })
        let sugars = try XCTUnwrap(evaluation.criteria.first { $0.criterion == .sugars })
        let intake = DefaultProfiles.dailyIntake
        XCTAssertEqual(intake.percent(of: protein), 7.5 / 46 * 100 / 50 * 100, accuracy: 1e-9)
        XCTAssertEqual(intake.percent(of: sugars), 4 / 46 * 100 / 90 * 100, accuracy: 1e-9)
        XCTAssertEqual(intake.percentPer100g(of: sugars), 4 / 90 * 100, accuracy: 1e-9)
    }

    func testDailyIntakePersistsAndResets() throws {
        let suiteName = "NutriRatioTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = ProfileStore(defaults: defaults)
        XCTAssertEqual(store.dailyIntake, DefaultProfiles.dailyIntake)
        var intake = store.dailyIntake
        intake.protein = 120
        store.setDailyIntake(intake)

        let reloaded = ProfileStore(defaults: defaults)
        XCTAssertEqual(reloaded.dailyIntake.protein, 120)
        XCTAssertTrue(reloaded.isDailyIntakeModified)

        // Une valeur nulle est refusée.
        intake.salt = 0
        reloaded.setDailyIntake(intake)
        XCTAssertEqual(reloaded.dailyIntake.salt, DefaultProfiles.dailyIntake.salt)

        reloaded.resetDailyIntake()
        XCTAssertEqual(ProfileStore(defaults: defaults).dailyIntake, DefaultProfiles.dailyIntake)
    }

    /// Les réglages enregistrés avant l'ajout des apports quotidiens restent lisibles.
    func testOldStoredDataWithoutDailyIntakeStillLoads() throws {
        let suiteName = "NutriRatioTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let old = #"{"selected":"bulking","configs":{"cutting":{"protein":{"low":6,"high":8,"weight":35},"fiber":{"low":1.5,"high":3,"weight":25},"sugars":{"low":1.25,"high":2.5,"weight":15},"saturatedFat":{"low":1.1,"high":1.45,"weight":15},"salt":{"low":0.25,"high":0.33,"weight":10}}}}"#
        defaults.set(Data(old.utf8), forKey: "profileStore.v1")

        let store = ProfileStore(defaults: defaults)
        XCTAssertEqual(store.selected, .bulking)
        XCTAssertEqual(store.config(for: .cutting).protein.low, 6)
        XCTAssertEqual(store.dailyIntake, DefaultProfiles.dailyIntake)
    }
}
