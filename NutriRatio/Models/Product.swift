import Foundation

/// Produit alimentaire, indépendant de l'UI. Persisté tel quel dans l'historique.
struct Product: Codable, Hashable, Identifiable {
    enum Source: String, Codable {
        case manual, barcode, photo, recipe
    }

    var id = UUID()
    var name: String = ""
    var brand: String?
    var barcode: String?
    var servingSize: String?
    var facts = NutritionFacts()
    var source: Source = .manual
}
