import Foundation
import Observation

/// Bibliothèque locale « Mon aliment », persistée en UserDefaults (JSON) comme l'historique.
@Observable
final class FoodLibrary {
    private static let storageKey = "foods.v1"

    @ObservationIgnored private let defaults: UserDefaults

    private(set) var foods: [FoodItem] {
        didSet { persist() }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        foods = defaults.data(forKey: Self.storageKey)
            .flatMap { try? JSONDecoder().decode([FoodItem].self, from: $0) } ?? []
    }

    func food(id: UUID) -> FoodItem? { foods.first { $0.id == id } }

    /// Ajoute (ou remplace, à identifiant égal) un aliment. Un aliment qui ne partage aucun nom
    /// avec un autre est d'office le défaut de ses noms ; un aliment marqué par défaut le retire aux autres.
    func save(_ food: FoodItem) {
        var food = food
        food.name = food.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let others = foods.filter { $0.id != food.id }
        if !others.contains(where: { $0.sharesKey(with: food) }) { food.isDefault = true }
        var updated = others.map { other in
            var other = other
            if food.isDefault, other.isDefault, other.sharesKey(with: food) { other.isDefault = false }
            return other
        }
        if let index = foods.firstIndex(where: { $0.id == food.id }) {
            updated.insert(food, at: min(index, updated.count))
        } else {
            updated.append(food)
        }
        foods = updated
    }

    func remove(_ food: FoodItem) {
        foods.removeAll { $0.id == food.id }
    }

    func setDefault(_ food: FoodItem) {
        guard var current = self.food(id: food.id) else { return }
        current.isDefault = true
        save(current)
    }

    /// Vrai si un autre aliment répond déjà à l'un de ces noms.
    func hasFood(matching names: [String], excluding id: UUID? = nil) -> Bool {
        let probe = FoodItem(name: names.first ?? "", aliases: Array(names.dropFirst()))
        return foods.contains { $0.id != id && $0.sharesKey(with: probe) }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(foods) {
            defaults.set(data, forKey: Self.storageKey)
        }
    }

    /// Aliments utilisables dans une recette : les vôtres, puis les valeurs moyennes intégrées,
    /// sauf celles qu'un de vos aliments remplace (même nom ou alias).
    var available: [FoodItem] {
        foods + BuiltInFoods.all.filter { builtIn in !foods.contains { $0.sharesKey(with: builtIn) } }
    }

    func matches(for ingredient: String) -> [FoodMatcher.Match] {
        FoodMatcher.matches(for: ingredient, in: available)
    }
}

private extension FoodItem {
    func sharesKey(with other: FoodItem) -> Bool {
        let theirs = other.keys
        return keys.contains { theirs.contains($0) }
    }
}
