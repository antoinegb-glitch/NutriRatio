import SwiftUI

/// Écran de vérification des ingrédients : toujours affiché après une saisie ou un collage.
/// Les lignes douteuses ou incomplètes sont surlignées (couleur + icône + texte).
struct RecipeEditorView: View {
    private struct CaptureRequest: Identifiable {
        let id = UUID()
        let lineID: UUID
        let mode: FoodCaptureFlow.Mode
        let lineName: String
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(RecipeStore.self) private var recipes
    @Environment(FoodLibrary.self) private var library
    let seed: RecipeEditorSeed
    let onCalculate: (UUID) -> Void

    @State private var model = RecipeEditorModel()
    @State private var capture: CaptureRequest?
    @State private var pickingLine: UUID?
    @FocusState private var focused: Bool

    var body: some View {
        @Bindable var model = model
        Form {
            if let notice = model.notice {
                Section { Label(notice, systemImage: "info.circle").font(.subheadline) }
            }

            Section("Recette") {
                TextField("Nom de la recette", text: $model.recipe.name)
                    .focused($focused)
                HStack {
                    Text("Portions (facultatif)")
                    Spacer()
                    TextField("—", text: $model.servingsText)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 70)
                        .focused($focused)
                        .accessibilityLabel("Nombre de portions")
                }
            }

            Section {
                ForEach(model.recipe.lines) { line in
                    RecipeLineRow(
                        model: model, line: line, matches: library.matches(for: line.name).map(\.food),
                        foodName: line.food?.resolve(in: library.available).map { $0.isBuiltIn ? "\($0.name) (valeur moyenne)" : $0.name },
                        focused: $focused,
                        onPick: { pickingLine = line.id },
                        onCapture: { mode in capture = CaptureRequest(lineID: line.id, mode: mode, lineName: line.name) }
                    )
                }
                .onDelete { model.removeLines(at: $0) }
                Button("Ajouter un ingrédient", systemImage: "plus.circle") { model.addLine() }
            } header: {
                Text("Ingrédients")
            } footer: {
                if model.recipe.lines.contains(where: \.needsAttention) {
                    Label("Lignes surlignées : poids ou aliment à préciser, ou valeur à vérifier. Glissez une ligne vers la gauche pour la supprimer.", systemImage: "exclamationmark.triangle")
                }
            }

            Section {
                HStack {
                    Text("Poids final")
                    Spacer()
                    TextField("—", text: $model.finalWeightText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 90)
                        .focused($focused)
                        .accessibilityLabel("Poids final du plat cuit, en grammes")
                    Text("g").foregroundStyle(.secondary)
                }
            } header: {
                Text("Poids du plat (facultatif)")
            } footer: {
                Text("Vide : le calcul au 100 g utilise la somme des poids crus (\(rawWeight.formatted(.number.precision(.fractionLength(0...0)))) g). Renseigné : il remplace le poids cru, les totaux restent inchangés.")
            }

            Section {
                Button {
                    focused = false
                    let recipe = model.makeRecipe()
                    recipes.save(recipe)
                    onCalculate(recipe.id)
                } label: {
                    Text("Calculer").font(.headline).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!model.canCalculate)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            } footer: {
                if let reason = blockerSummary { Text(reason) }
            }
        }
        .navigationTitle("Ingrédients")
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Enregistrer") {
                    recipes.save(model.makeRecipe())
                    dismiss()
                }
                .disabled(model.recipe.name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("OK") { focused = false }
            }
        }
        .onAppear { model.load(seed: seed, recipes: recipes, library: library) }
        .sheet(item: $capture) { request in
            FoodCaptureFlow(mode: request.mode, lineName: request.lineName, offersSaveToggle: true) { food, saved in
                model.setFood(saved ? .library(food.id) : .custom(food), of: request.lineID, library: library)
            }
        }
        .sheet(isPresented: Binding(get: { pickingLine != nil }, set: { if !$0 { pickingLine = nil } })) {
            if let id = pickingLine {
                FoodPickerView(ingredient: model.recipe.lines.first { $0.id == id }?.name ?? "") { food in
                    model.setFood(.library(food.id), of: id, library: library)
                }
            }
        }
    }

    private var rawWeight: Double { model.recipe.lines.compactMap(\.grams).reduce(0, +) }

    private var blockerSummary: String? {
        if model.recipe.lines.isEmpty { return String(localized: "Ajoutez au moins un ingrédient.") }
        let blockers = model.blockers
        let weights = blockers.filter { $0.blocker == .missingWeight }.count
        let foods = blockers.filter { $0.blocker == .missingFood }.count
        var parts: [String] = []
        if weights > 0 { parts.append(String(localized: "\(weights) ligne(s) sans poids en grammes")) }
        if foods > 0 { parts.append(String(localized: "\(foods) ligne(s) sans aliment associé")) }
        if parts.isEmpty, model.recipe.name.trimmingCharacters(in: .whitespaces).isEmpty {
            return String(localized: "Donnez un nom à la recette.")
        }
        return parts.isEmpty ? nil : String(localized: "Calcul impossible : \(parts.joined(separator: ", ")).")
    }
}

private struct RecipeLineRow: View {
    let model: RecipeEditorModel
    let line: RecipeLine
    let matches: [FoodItem]
    let foodName: String?
    var focused: FocusState<Bool>.Binding
    let onPick: () -> Void
    let onCapture: (FoodCaptureFlow.Mode) -> Void
    @Environment(FoodLibrary.self) private var library

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Ingrédient", text: Binding(
                get: { line.name },
                set: { model.setName($0, of: line.id, library: library) }
            ))
            .font(.headline)
            .focused(focused)

            if !line.originalText.isEmpty, line.originalText != line.name {
                Text("« \(line.originalText) »")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                TextField("Qté", text: Binding(
                    get: { model.quantityTexts[line.id] ?? "" },
                    set: { model.setQuantityText($0, of: line.id, library: library) }
                ))
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
                .frame(minWidth: 56, maxWidth: 80)
                .focused(focused)
                .accessibilityLabel("Quantité")

                Picker("Unité", selection: Binding(
                    get: { line.unit },
                    set: { model.setUnit($0, of: line.id, library: library) }
                )) {
                    ForEach(RecipeUnit.allCases) { Text($0.label).tag($0) }
                }
                .labelsHidden()

                Spacer(minLength: 4)

                Text("=").accessibilityHidden(true)
                TextField("?", text: Binding(
                    get: { model.gramsTexts[line.id] ?? "" },
                    set: { model.setGramsText($0, of: line.id, library: library) }
                ))
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .frame(minWidth: 56, maxWidth: 80)
                .focused(focused)
                .accessibilityLabel("Poids en grammes")
                Text("g").foregroundStyle(.secondary)
            }

            foodMenu

            ForEach(line.notes, id: \.self) { note in
                Label(note.message, systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
            if line.needsWeight {
                Label("Poids à préciser : saisissez l'équivalent en grammes.", systemImage: "scalemass")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.orange)
            } else if line.gramsIsManual {
                Text("Poids saisi à la main.").font(.footnote).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .listRowBackground(background)
    }

    private var foodMenu: some View {
        Menu {
            if !matches.isEmpty {
                ForEach(matches) { food in
                    Button(food.name, systemImage: food.isDefault ? "star.fill" : "fork.knife") {
                        model.setFood(.library(food.id), of: line.id, library: library)
                    }
                }
                Divider()
            }
            if line.food != nil, line.foodNeedsReview {
                Button("Confirmer l'association", systemImage: "checkmark") { model.confirmFood(of: line.id) }
            }
            Button("Choisir dans Mon aliment…", systemImage: "tray.full", action: onPick)
            Button("Scanner un code-barres", systemImage: "barcode.viewfinder") { onCapture(.barcode) }
            Button("Photo + OCR", systemImage: "camera.viewfinder") { onCapture(.photo) }
            Button("Saisie manuelle", systemImage: "square.and.pencil") { onCapture(.manual) }
            if line.food != nil {
                Divider()
                Button("Dissocier", systemImage: "link.badge.plus", role: .destructive) {
                    model.setFood(nil, of: line.id, library: library)
                }
            }
        } label: {
            HStack {
                Image(systemName: line.food == nil ? "questionmark.circle" : (line.foodNeedsReview ? "exclamationmark.triangle" : "checkmark.circle"))
                    .accessibilityHidden(true)
                Text(foodLabel)
                    .multilineTextAlignment(.leading)
                Spacer()
                Image(systemName: "chevron.up.chevron.down").font(.footnote).accessibilityHidden(true)
            }
            .font(.subheadline)
        }
        .accessibilityLabel(foodLabel)
        .accessibilityHint("Change l'aliment associé")
    }

    private var foodLabel: String {
        guard line.food != nil else { return String(localized: "Aliment à associer") }
        let name = foodName ?? String(localized: "Aliment")
        return line.foodNeedsReview ? String(localized: "\(name) · à vérifier") : name
    }

    private var background: Color? {
        if line.needsWeight || line.needsFood { return .yellow.opacity(0.18) }
        if line.foodNeedsReview || !line.notes.isEmpty { return .orange.opacity(0.14) }
        return nil
    }
}
