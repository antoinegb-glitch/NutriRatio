import SwiftUI

/// « Mes recettes » : liste, recherche, ouverture, modification, duplication, suppression.
struct RecipeListView: View {
    @Environment(RecipeStore.self) private var store
    @Environment(FoodLibrary.self) private var library
    let onEdit: (UUID) -> Void
    let onCreate: (Route) -> Void
    @State private var search = ""
    @State private var pendingDeletion: Recipe?

    private var results: [Recipe] {
        let query = TextNormalizer.fold(search).trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return store.recipes }
        return store.recipes.filter { TextNormalizer.fold($0.name).contains(query) }
    }

    var body: some View {
        List {
            ForEach(results) { recipe in
                NavigationLink(value: Route.recipeResult(recipe.id)) {
                    RecipeRow(recipe: recipe.refreshed(in: library.available), library: library.available)
                }
                .swipeActions(edge: .trailing) {
                    Button("Supprimer", systemImage: "trash", role: .destructive) { pendingDeletion = recipe }
                }
                .swipeActions(edge: .leading) {
                    Button("Dupliquer", systemImage: "plus.square.on.square") { store.duplicate(recipe) }.tint(.blue)
                }
                .contextMenu {
                    Button("Modifier", systemImage: "pencil") { onEdit(recipe.id) }
                    Button("Dupliquer", systemImage: "plus.square.on.square") { store.duplicate(recipe) }
                    Button("Supprimer", systemImage: "trash", role: .destructive) { pendingDeletion = recipe }
                }
            }
        }
        .overlay {
            if store.recipes.isEmpty {
                ContentUnavailableView(
                    "Aucune recette",
                    systemImage: "fork.knife",
                    description: Text("Saisissez ou collez une recette avec le bouton + pour connaître sa composition au 100 g.")
                )
            } else if results.isEmpty {
                ContentUnavailableView.search(text: search)
            }
        }
        .searchable(text: $search, prompt: "Rechercher une recette")
        .navigationTitle("Mes recettes")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Coller une recette", systemImage: "doc.on.clipboard") { onCreate(.pasteRecipe) }
                    Button("Saisie manuelle", systemImage: "square.and.pencil") { onCreate(.recipeEditor(RecipeEditorSeed())) }
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Nouvelle recette")
            }
        }
        .confirmationDialog(
            "Supprimer cette recette ?", isPresented: Binding(get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } }),
            titleVisibility: .visible, presenting: pendingDeletion
        ) { recipe in
            Button("Supprimer « \(recipe.name) »", role: .destructive) { store.remove(recipe) }
        }
    }
}

private struct RecipeRow: View {
    let recipe: Recipe
    let library: [FoodItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(recipe.name.isEmpty ? String(localized: "Recette sans nom") : recipe.name)
                .font(.body.weight(.medium))
            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private var subtitle: String {
        let count = String(localized: "\(recipe.lines.count) ingrédients")
        guard let calculation = RecipeCalculator.calculate(lines: recipe.lines, finalWeight: recipe.finalWeight,
                                                           servings: recipe.servings, library: library) else {
            return "\(count) · \(String(localized: "incomplète"))"
        }
        guard let kcal = calculation.per100g.energyKcal else { return count }
        return "\(count) · \(kcal.formatted(.number.precision(.fractionLength(0...0)))) kcal / 100 g"
    }
}
