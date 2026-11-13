import XCTest
@testable import NutriRatio

final class HistoryStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName = ""

    override func setUpWithError() throws {
        suiteName = "NutriRatioTests.History.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
    }

    private func product(_ name: String, barcode: String? = nil) -> Product {
        Product(name: name, barcode: barcode, facts: NutritionFacts(energyKcal: 100, protein: 5))
    }

    func testNewestFirstAndPersisted() {
        let store = HistoryStore(defaults: defaults)
        store.record(product("A"), at: Date(timeIntervalSince1970: 1))
        store.record(product("B"), at: Date(timeIntervalSince1970: 2))

        let reloaded = HistoryStore(defaults: defaults)
        XCTAssertEqual(reloaded.entries.map(\.product.name), ["B", "A"])
        XCTAssertEqual(reloaded.entries.first?.product.facts.protein, 5)
    }

    func testSameBarcodeReplacesOlderEntry() {
        let store = HistoryStore(defaults: defaults)
        store.record(product("Ancien", barcode: "3017620422003"))
        store.record(product("Autre"))
        store.record(product("Nouveau", barcode: "3017620422003"))
        XCTAssertEqual(store.entries.map(\.product.name), ["Nouveau", "Autre"])
    }

    func testSameAnalysisIsNotDuplicated() {
        let store = HistoryStore(defaults: defaults)
        var item = product("Yaourt")
        store.record(item)
        item.name = "Yaourt nature"
        store.record(item)
        XCTAssertEqual(store.entries.map(\.product.name), ["Yaourt nature"])
    }

    func testManualEntriesWithoutBarcodeAreKeptSeparately() {
        let store = HistoryStore(defaults: defaults)
        store.record(product(""))
        store.record(product(""))
        XCTAssertEqual(store.entries.count, 2)
    }

    func testCountIsCapped() {
        let store = HistoryStore(defaults: defaults)
        for index in 0..<(HistoryStore.maximumCount + 5) {
            store.record(product("P\(index)"))
        }
        XCTAssertEqual(store.entries.count, HistoryStore.maximumCount)
        XCTAssertEqual(store.entries.first?.product.name, "P\(HistoryStore.maximumCount + 4)")
    }

    func testRemoveAndClear() {
        let store = HistoryStore(defaults: defaults)
        store.record(product("A"))
        store.record(product("B"))
        let first = try? XCTUnwrap(store.entries.first)
        if let first { store.remove(first) }
        XCTAssertEqual(store.entries.map(\.product.name), ["A"])
        store.removeAll()
        XCTAssertTrue(HistoryStore(defaults: defaults).entries.isEmpty)
    }

    func testCorruptedDataGivesEmptyHistory() {
        defaults.set(Data("pas du json".utf8), forKey: "history.v1")
        XCTAssertTrue(HistoryStore(defaults: defaults).entries.isEmpty)
    }
}
