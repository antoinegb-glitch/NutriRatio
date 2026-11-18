import Foundation

/// Aliment de la bibliothèque « Mon aliment » : valeurs pour 100 g, alias, poids d'une pièce.
struct FoodItem: Codable, Hashable, Identifiable {
    var id = UUID()
    var name: String
    var brand: String?
    var facts = NutritionFacts()
    /// Autres noms sous lesquels reconnaître l'aliment dans une recette (« chocolat », « chocolat noir »).
    var aliases: [String] = []
    /// Poids d'une pièce en g (1 œuf = 55 g) ; prime sur la table par défaut.
    var unitWeightGrams: Double?
    /// Utilisé automatiquement quand plusieurs aliments correspondent au même nom.
    var isDefault = false

    /// Un ensemble de mots par nom ou alias.
    var keys: [Set<String>] {
        ([name] + aliases).map(TextNormalizer.key).filter { !$0.isEmpty }
    }

    /// Aliment intégré à l'app (valeurs moyennes), par opposition à ceux de « Mon aliment ».
    var isBuiltIn: Bool { BuiltInFoods.ids.contains(id) }

    var asProduct: Product {
        Product(id: id, name: name, brand: brand, facts: facts, source: .manual)
    }
}

/// Aliment utilisé par une ligne de recette : de la bibliothèque (référence, donc à jour si
/// l'aliment change) ou propre à cette recette (copie, non enregistrée dans « Mon aliment »).
enum FoodRef: Codable, Hashable {
    case library(UUID)
    case custom(FoodItem)

    func resolve(in library: [FoodItem]) -> FoodItem? {
        switch self {
        case .library(let id): library.first { $0.id == id }
        case .custom(let food): food
        }
    }
}

/// Recherche d'un aliment pour un nom d'ingrédient.
enum FoodMatcher {
    struct Match: Hashable {
        let food: FoodItem
        /// 3 = nom identique, 2 = le nom de l'aliment est contenu dans la ligne, 1 = l'inverse (proposition seulement).
        let score: Int
    }

    /// Score minimal pour une association automatique.
    static let automaticScore = 2

    /// Correspondances triées : meilleur score, nom le plus spécifique, puis aliment par défaut.
    static func matches(for ingredient: String, in foods: [FoodItem]) -> [Match] {
        let line = TextNormalizer.key(ingredient)
        guard !line.isEmpty else { return [] }
        var ranked: [(match: Match, size: Int)] = []
        for food in foods {
            var best: (score: Int, size: Int)?
            for key in food.keys {
                let score: Int
                if key == line { score = 3 }
                else if key.isSubset(of: line) { score = 2 }
                else if line.isSubset(of: key) { score = 1 }
                else { continue }
                if best == nil || (score, key.count) > (best!.score, best!.size) { best = (score, key.count) }
            }
            if let best { ranked.append((Match(food: food, score: best.score), best.size)) }
        }
        return ranked.sorted {
            if $0.match.score != $1.match.score { return $0.match.score > $1.match.score }
            if $0.size != $1.size { return $0.size > $1.size }
            if $0.match.food.isDefault != $1.match.food.isDefault { return $0.match.food.isDefault }
            return $0.match.food.name.localizedCaseInsensitiveCompare($1.match.food.name) == .orderedAscending
        }.map(\.match)
    }

    /// Aliment à associer automatiquement, s'il y en a un.
    static func automaticMatch(for ingredient: String, in foods: [FoodItem]) -> FoodItem? {
        matches(for: ingredient, in: foods).first.flatMap { $0.score >= automaticScore ? $0.food : nil }
    }
}
