import Foundation

/// Conversion d'une quantité en grammes. Logique pure.
///
/// Les valeurs sont des ordres de grandeur courants (une pièce ou une cuillère varie d'un
/// produit à l'autre) : elles sont modifiables à l'écran de vérification, et le poids
/// unitaire d'un aliment de « Mon aliment » prime sur cette table.
enum WeightConverter {
    struct Result: Equatable {
        var grams: Double
        /// Densité supposée à 1 g/ml faute de mieux : la ligne est à vérifier.
        var assumed = false
    }

    /// `nil` = « poids à préciser » (unité ou ingrédient ambigu, quantité absente).
    static func grams(quantity: Double?, unit: RecipeUnit, ingredient: String, unitWeight: Double?) -> Result? {
        guard let quantity, quantity >= 0 else { return nil }
        let key = TextNormalizer.key(ingredient)

        if let perUnit = unit.gramsPerUnit {
            return Result(grams: quantity * perUnit)
        }
        switch unit {
        case .piece:
            guard let weight = unitWeight ?? lookup(pieceWeights, key) else { return nil }
            return Result(grams: quantity * weight)
        case .pinch:
            return Result(grams: quantity * 0.5)
        case .knob:
            return Result(grams: quantity * 10)
        default:
            guard let milliliters = unit.milliliters else { return nil }
            if let density = lookup(densities, key) {
                return Result(grams: quantity * milliliters * density)
            }
            // Une cuillère ou une tasse de « on ne sait quoi » est ambiguë ; un volume métrique
            // reste raisonnablement proche de 1 g/ml.
            guard unit.isMetricVolume else { return nil }
            return Result(grams: quantity * milliliters, assumed: true)
        }
    }

    /// Entrée la plus spécifique (le plus de mots en commun) dont tous les mots figurent dans le nom.
    private static func lookup(_ table: [(words: Set<String>, value: Double)], _ key: Set<String>) -> Double? {
        table.filter { $0.words.isSubset(of: key) }
            .max { $0.words.count < $1.words.count }?
            .value
    }

    private static func entry(_ words: String, _ value: Double) -> (words: Set<String>, value: Double) {
        (TextNormalizer.key(words), value)
    }

    /// Poids moyen d'une pièce, en g.
    static let pieceWeights: [(words: Set<String>, value: Double)] = [
        entry("œuf", 55), entry("egg", 55), entry("blanc d'œuf", 33), entry("jaune d'œuf", 18),
        entry("oignon", 110), entry("onion", 110), entry("échalote", 30),
        entry("gousse d'ail", 5), entry("clove garlic", 5), entry("tête d'ail", 50),
        entry("carotte", 80), entry("carrot", 80),
        entry("pomme de terre", 150), entry("potato", 150), entry("pomme", 150), entry("apple", 150),
        entry("poire", 160), entry("banane", 120), entry("banana", 120),
        entry("tomate", 120), entry("tomato", 120),
        entry("citron", 100), entry("lemon", 100), entry("orange", 150),
        entry("courgette", 200), entry("zucchini", 200), entry("aubergine", 250),
        entry("poivron", 150), entry("concombre", 300), entry("avocat", 150), entry("avocado", 150),
        entry("champignon", 20), entry("yaourt", 125), entry("yogurt", 125),
        entry("tranche de jambon", 45), entry("tranche de pain", 30), entry("slice bread", 30),
        entry("branche de céleri", 40), entry("cube", 10), entry("sachet de levure", 11),
        entry("sachet de sucre vanillé", 7.5),
    ]

    /// Masse volumique approximative, en g/ml.
    static let densities: [(words: Set<String>, value: Double)] = [
        entry("eau", 1), entry("water", 1), entry("lait", 1.03), entry("milk", 1.03),
        entry("lait de coco", 0.97), entry("crème", 1), entry("cream", 1),
        entry("huile", 0.9), entry("oil", 0.9), entry("vinaigre", 1.01), entry("vinegar", 1.01),
        entry("miel", 1.4), entry("honey", 1.4), entry("sirop", 1.3), entry("confiture", 1.3),
        entry("sucre", 0.85), entry("sugar", 0.85), entry("sucre glace", 0.56), entry("cassonade", 0.8),
        entry("farine", 0.55), entry("flour", 0.55), entry("fécule", 0.6), entry("maïzena", 0.6),
        entry("cacao", 0.5), entry("sel", 1.2), entry("salt", 1.2), entry("poivre", 0.5),
        entry("beurre", 0.95), entry("butter", 0.95), entry("moutarde", 1.05),
        entry("sauce soja", 1.15), entry("ketchup", 1.1), entry("concentré de tomate", 1.1),
        entry("levure", 0.9), entry("yaourt", 1.03), entry("riz", 0.85), entry("rice", 0.85),
        entry("flocons d'avoine", 0.35), entry("amande poudre", 0.45), entry("parmesan", 0.4),
        entry("bicarbonate", 0.9), entry("extrait de vanille", 0.95), entry("cream cheese", 1),
        entry("philadelphia", 1), entry("cannelle", 0.4), entry("jus", 1.04), entry("vin", 0.99), entry("bouillon", 1),
    ]
}
