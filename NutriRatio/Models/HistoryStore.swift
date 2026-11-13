import Foundation
import Observation

/// Produit analysé, avec la date de sa dernière analyse.
struct HistoryEntry: Codable, Hashable, Identifiable {
    var product: Product
    var date: Date

    var id: UUID { product.id }
}

/// Historique local des produits analysés, du plus récent au plus ancien, persisté en
/// UserDefaults. Rien ne quitte l'appareil.
@Observable
final class HistoryStore {
    static let maximumCount = 50
    private static let storageKey = "history.v1"

    @ObservationIgnored private let defaults: UserDefaults

    private(set) var entries: [HistoryEntry] {
        didSet { save() }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // Données illisibles (format futur, fichier corrompu) : historique vide plutôt qu'un plantage.
        entries = defaults.data(forKey: Self.storageKey)
            .flatMap { try? JSONDecoder().decode([HistoryEntry].self, from: $0) } ?? []
    }

    /// Ajoute le produit en tête. Un produit déjà présent (même analyse, ou même code-barres)
    /// est remplacé plutôt que dupliqué.
    func record(_ product: Product, at date: Date = .now) {
        var updated = entries.filter { !$0.matches(product) }
        updated.insert(HistoryEntry(product: product, date: date), at: 0)
        entries = Array(updated.prefix(Self.maximumCount))
    }

    func remove(_ entry: HistoryEntry) {
        entries.removeAll { $0.id == entry.id }
    }

    func removeAll() {
        entries = []
    }

    private func save() {
        if let data = try? JSONEncoder().encode(entries) {
            defaults.set(data, forKey: Self.storageKey)
        }
    }
}

private extension HistoryEntry {
    func matches(_ other: Product) -> Bool {
        if product.id == other.id { return true }
        guard let barcode = product.barcode, !barcode.isEmpty else { return false }
        return barcode == other.barcode
    }
}
