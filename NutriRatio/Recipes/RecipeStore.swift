import Foundation
import Observation

/// Recettes enregistrées, persistées en UserDefaults (JSON).
///
/// Choix de stockage : comme l'historique et les profils, des valeurs `Codable` en JSON plutôt
/// que SwiftData. Les volumes sont faibles, les modèles restent de simples structures testables
/// sans simulateur (`swift test`), et aucun nouveau framework ni schéma à migrer.
@Observable
final class RecipeStore {
    private static let storageKey = "recipes.v1"

    @ObservationIgnored private let defaults: UserDefaults

    /// Plus récentes d'abord.
    private(set) var recipes: [Recipe] {
        didSet { persist() }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        recipes = defaults.data(forKey: Self.storageKey)
            .flatMap { try? JSONDecoder().decode([Recipe].self, from: $0) } ?? []
    }

    func recipe(id: UUID) -> Recipe? { recipes.first { $0.id == id } }

    func save(_ recipe: Recipe, at date: Date = .now) {
        var recipe = recipe
        recipe.date = date
        var updated = recipes.filter { $0.id != recipe.id }
        updated.insert(recipe, at: 0)
        recipes = updated
    }

    @discardableResult
    func duplicate(_ recipe: Recipe, at date: Date = .now) -> Recipe {
        var copy = recipe
        copy.id = UUID()
        copy.name = String(localized: "\(recipe.name) (copie)")
        copy.lines = recipe.lines.map { line in
            var line = line
            line.id = UUID()
            return line
        }
        save(copy, at: date)
        return copy
    }

    func remove(_ recipe: Recipe) {
        recipes.removeAll { $0.id == recipe.id }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(recipes) {
            defaults.set(data, forKey: Self.storageKey)
        }
    }
}
