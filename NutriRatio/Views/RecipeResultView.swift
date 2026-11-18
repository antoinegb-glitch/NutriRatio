import SwiftUI

/// Résultat d'une recette : recalculé à chaque ouverture depuis les aliments actuels de Mon aliment.
struct RecipeResultView: View {
    @Environment(RecipeStore.self) private var store
    @Environment(FoodLibrary.self) private var library
    let recipeID: UUID

    var body: some View {
        if let saved = store.recipe(id: recipeID) {
            let recipe = saved.refreshed(in: library.available)
            Group {
                if let calculation = RecipeCalculator.calculate(
                    lines: recipe.lines, finalWeight: recipe.finalWeight, servings: recipe.servings, library: library.available
                ) {
                    ResultView(product: calculation.product(named: recipe.name), recipe: calculation)
                } else {
                    incomplete(recipe)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(value: Route.recipeEditor(RecipeEditorSeed(recipeID: recipeID))) {
                        Text("Modifier")
                    }
                }
            }
        } else {
            ContentUnavailableView("Recette introuvable", systemImage: "questionmark.folder")
        }
    }

    private func incomplete(_ recipe: Recipe) -> some View {
        let blockers = RecipeCalculator.blockers(in: recipe.lines)
        return List {
            Section {
                Label("Recette incomplète : le calcul demande un poids en grammes et un aliment pour chaque ligne.", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            }
            Section("Lignes à compléter") {
                ForEach(blockers, id: \.line.id) { item in
                    Label(
                        item.blocker == .missingWeight
                            ? String(localized: "\(item.line.name) : poids à préciser")
                            : String(localized: "\(item.line.name) : aliment à associer"),
                        systemImage: item.blocker == .missingWeight ? "scalemass" : "link"
                    )
                    .font(.subheadline)
                }
            }
            if recipe.lines.isEmpty {
                Section { Text("Cette recette n'a pas d'ingrédient.").foregroundStyle(.secondary) }
            }
        }
        .navigationTitle(recipe.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Bandeau « résultat partiel » : nutriments absents de certains aliments.
struct RecipePartialBanner: View {
    let calculation: RecipeCalculation

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Résultat partiel", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
            Text("Certains aliments n'ont pas toutes leurs valeurs. Ces nutriments ne sont pas comptés comme zéro : ils sont ignorés dans la note.")
                .font(.subheadline)
            ForEach(calculation.incomplete.keys.sorted { $0.rawValue < $1.rawValue }, id: \.self) { field in
                Text("\(field.title) : manquant pour \(calculation.incomplete[field, default: []].joined(separator: ", "))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .foregroundStyle(.orange)
        .accessibilityElement(children: .combine)
    }
}

/// Totaux de la recette, poids utilisé pour le calcul, valeurs par portion.
struct RecipeTotalsSections: View {
    let calculation: RecipeCalculation

    var body: some View {
        Section {
            LabeledContent("Poids utilisé pour le 100 g") {
                Text("\(format(calculation.referenceWeight)) g").monospacedDigit()
            }
            Text(calculation.usesFinalWeight
                 ? String(localized: "Poids final saisi (plat cuit). Poids cru des ingrédients : \(format(calculation.rawWeight)) g.")
                 : String(localized: "Somme des poids crus des ingrédients. Saisissez un poids final pour un plat cuit."))
                .font(.footnote)
                .foregroundStyle(.secondary)
            ForEach(NutrientField.allCases) { field in
                factRow(field, calculation.totals[field])
            }
        } header: {
            Text("Total de la recette")
        }

        if let perServing = calculation.perServing, let servings = calculation.servings {
            Section("Par portion (\(servings) portions)") {
                ForEach(NutrientField.allCases) { field in
                    factRow(field, perServing[field], partial: false)
                }
            }
        }
    }

    private func factRow(_ field: NutrientField, _ value: Double?, partial: Bool? = nil) -> some View {
        let isPartial = partial ?? (calculation.incomplete[field] != nil)
        return LabeledContent(field.title) {
            if let value {
                Text("\(isPartial ? "≥ " : "")\(format(value)) \(field.unit)\(isPartial ? " " + String(localized: "(partiel)") : "")")
                    .monospacedDigit()
            } else {
                Text("—").foregroundStyle(.secondary)
            }
        }
    }

    private func format(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1)))
    }
}
