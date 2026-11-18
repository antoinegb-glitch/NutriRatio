import SwiftUI

/// Gestion de « Mon aliment » : liste, recherche, ajout par les trois modes, modification, suppression.
struct FoodLibraryView: View {
    @Environment(FoodLibrary.self) private var library
    @State private var search = ""
    @State private var creation: FoodCaptureFlow.Mode?
    @State private var editing: FoodItem?
    @State private var pendingDeletion: FoodItem?

    private var results: [FoodItem] {
        let sorted = library.foods.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        let query = TextNormalizer.fold(search).trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return sorted }
        return sorted.filter { food in
            ([food.name, food.brand ?? ""] + food.aliases).contains { TextNormalizer.fold($0).contains(query) }
        }
    }

    var body: some View {
        List {
            ForEach(results) { food in
                Button { editing = food } label: { FoodRow(food: food) }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing) {
                        Button("Supprimer", systemImage: "trash", role: .destructive) { pendingDeletion = food }
                    }
                    .swipeActions(edge: .leading) {
                        if !food.isDefault {
                            Button("Par défaut", systemImage: "star") { library.setDefault(food) }.tint(.yellow)
                        }
                    }
                    .contextMenu {
                        if !food.isDefault {
                            Button("Définir comme défaut", systemImage: "star") { library.setDefault(food) }
                        }
                        Button("Supprimer", systemImage: "trash", role: .destructive) { pendingDeletion = food }
                    }
            }
        }
        .overlay {
            if library.foods.isEmpty {
                ContentUnavailableView(
                    "Aucun aliment enregistré",
                    systemImage: "tray",
                    description: Text("Ajoutez vos produits habituels avec le bouton +, ou depuis le résultat d'une analyse. Ils seront reconnus automatiquement dans vos recettes.")
                )
            } else if results.isEmpty {
                ContentUnavailableView.search(text: search)
            }
        }
        .searchable(text: $search, prompt: "Rechercher un aliment")
        .navigationTitle("Mon aliment")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Scanner un code-barres", systemImage: "barcode.viewfinder") { creation = .barcode }
                    Button("Photographier le tableau", systemImage: "camera.viewfinder") { creation = .photo }
                    Button("Saisie manuelle", systemImage: "square.and.pencil") { creation = .manual }
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Ajouter un aliment")
            }
        }
        .sheet(item: $creation) { mode in
            FoodCaptureFlow(mode: mode) { _, _ in }
        }
        .sheet(item: $editing) { food in
            FoodEditSheet(input: VerificationInput(product: food.asProduct), existing: food) { library.save($0) }
        }
        .confirmationDialog(
            "Supprimer cet aliment ?", isPresented: Binding(get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } }),
            titleVisibility: .visible, presenting: pendingDeletion
        ) { food in
            Button("Supprimer « \(food.name) »", role: .destructive) { library.remove(food) }
        } message: { _ in
            Text("Dans les recettes qui l'utilisent, la ligne redeviendra « à associer ».")
        }
    }
}

private struct FoodRow: View {
    let food: FoodItem

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(food.name).font(.body.weight(.medium))
                if let detail { Text(detail).font(.footnote).foregroundStyle(.secondary).lineLimit(2) }
                if food.isDefault {
                    Label("Par défaut", systemImage: "star.fill")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.orange)
                }
            }
            Spacer()
            if let kcal = food.facts.energyKcal {
                Text("\(kcal.formatted(.number.precision(.fractionLength(0...0)))) kcal")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Image(systemName: "chevron.right").foregroundStyle(.tertiary).accessibilityHidden(true)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var detail: String? {
        let parts = [food.brand, food.aliases.isEmpty ? nil : food.aliases.joined(separator: ", ")]
            .compactMap { $0 }.filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

/// Choix d'un aliment de la bibliothèque pour une ligne de recette : correspondances d'abord.
struct FoodPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(FoodLibrary.self) private var library
    let ingredient: String
    let onSelect: (FoodItem) -> Void
    @State private var search = ""

    var body: some View {
        NavigationStack {
            List {
                let matches = library.matches(for: ingredient).map(\.food)
                if search.isEmpty, !matches.isEmpty {
                    Section("Correspondances pour « \(ingredient) »") { rows(matches) }
                }
                Section("Tous les aliments") { rows(others) }
            }
            .searchable(text: $search, prompt: "Rechercher un aliment")
            .navigationTitle("Choisir un aliment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
            }
        }
    }

    private var others: [FoodItem] {
        let sorted = library.available.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        let query = TextNormalizer.fold(search).trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return sorted }
        return sorted.filter { food in ([food.name] + food.aliases).contains { TextNormalizer.fold($0).contains(query) } }
    }

    private func rows(_ foods: [FoodItem]) -> some View {
        ForEach(foods) { food in
            Button {
                onSelect(food)
                dismiss()
            } label: {
                HStack {
                    Text(food.isBuiltIn ? "\(food.name) (valeur moyenne)" : food.name)
                    if food.isDefault { Image(systemName: "star.fill").foregroundStyle(.orange).accessibilityLabel("Par défaut") }
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}
