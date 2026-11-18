import SwiftUI

/// Écran de vérification éditable (le même que pour une analyse) complété par les champs
/// propres à un aliment : alias, poids d'une pièce, aliment par défaut.
struct FoodVerificationScreen: View {
    let input: VerificationInput
    /// Aliment modifié, ou `nil` pour une création.
    let existing: FoodItem?
    /// Nom de la ligne de recette à l'origine de la création : proposé comme alias.
    let lineName: String?
    /// Vrai depuis une recette : « Ajouter à Mon aliment » peut être décoché pour un usage unique.
    let offersSaveToggle: Bool
    let onConfirm: (FoodItem, Bool) -> Void

    @State private var aliasesText: String
    @State private var unitWeightText: String
    @State private var isDefault: Bool
    @State private var saveToLibrary = true

    init(input: VerificationInput, existing: FoodItem? = nil, lineName: String? = nil,
         offersSaveToggle: Bool = false, onConfirm: @escaping (FoodItem, Bool) -> Void) {
        self.input = input
        self.existing = existing
        self.lineName = lineName
        self.offersSaveToggle = offersSaveToggle
        self.onConfirm = onConfirm
        _aliasesText = State(initialValue: existing?.aliases.joined(separator: ", ") ?? lineName ?? "")
        _unitWeightText = State(initialValue: existing?.unitWeightGrams.map(RecipeEditorModel.format) ?? "")
        _isDefault = State(initialValue: existing?.isDefault ?? false)
    }

    var body: some View {
        VerificationView(input: input, confirmTitle: confirmTitle) {
            Section {
                if !offersSaveToggle || saveToLibrary {
                    TextField("Alias, séparés par des virgules", text: $aliasesText)
                        .textInputAutocapitalization(.never)
                }
                HStack {
                    Text("Poids d'une pièce")
                    Spacer()
                    TextField("—", text: $unitWeightText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 84)
                        .accessibilityLabel("Poids d'une pièce, en grammes")
                    Text("g").foregroundStyle(.secondary)
                }
                if offersSaveToggle {
                    Toggle("Ajouter à Mon aliment", isOn: $saveToLibrary)
                }
                if !offersSaveToggle || saveToLibrary {
                    Toggle("Aliment par défaut pour ces noms", isOn: $isDefault)
                }
            } header: {
                Text("Mon aliment")
            } footer: {
                Text("Les alias (« chocolat », « chocolat noir »…) servent à reconnaître cet aliment dans vos recettes. Le poids d'une pièce (1 œuf = 55 g) convertit « 2 œufs » en grammes.")
            }
        } onEvaluate: { product in
            onConfirm(makeFood(from: product), offersSaveToggle ? saveToLibrary : true)
        }
    }

    private var confirmTitle: LocalizedStringKey {
        offersSaveToggle ? "Utiliser dans la recette" : "Enregistrer"
    }

    private func makeFood(from product: Product) -> FoodItem {
        let aliases = aliasesText
            .components(separatedBy: CharacterSet(charactersIn: ",;\n"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let weight = VerificationViewModel.parse(unitWeightText).flatMap { $0 > 0 ? $0 : nil }
        let name = product.name.isEmpty ? (lineName ?? String(localized: "Aliment sans nom")) : product.name
        return FoodItem(
            id: existing?.id ?? UUID(), name: name, brand: product.brand, facts: product.facts,
            aliases: aliases, unitWeightGrams: weight, isDefault: isDefault
        )
    }
}

/// Feuille d'édition d'un aliment existant, ou d'enregistrement d'un produit déjà analysé.
struct FoodEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    let input: VerificationInput
    var existing: FoodItem?
    let onConfirm: (FoodItem) -> Void

    var body: some View {
        NavigationStack {
            FoodVerificationScreen(input: input, existing: existing) { food, _ in
                onConfirm(food)
                dismiss()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
            }
        }
    }
}

/// Création d'un aliment par l'un des trois modes d'entrée, dans une feuille : capture,
/// puis écran de vérification obligatoire.
struct FoodCaptureFlow: View {
    enum Mode: String, Identifiable {
        case barcode, photo, manual
        var id: String { rawValue }
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(FoodLibrary.self) private var library
    let mode: Mode
    var lineName: String?
    var offersSaveToggle = false
    /// Aliment créé, et vrai s'il a été ajouté à Mon aliment.
    let onSave: (FoodItem, Bool) -> Void

    @State private var path: [VerificationInput] = []

    var body: some View {
        NavigationStack(path: $path) {
            root
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
                }
                .navigationDestination(for: VerificationInput.self) { input in
                    verification(input)
                }
        }
    }

    @ViewBuilder
    private var root: some View {
        switch mode {
        case .barcode: BarcodeScannerScreen { path.append($0) }
        case .photo: PhotoScreen { path.append($0) }
        case .manual: verification(VerificationInput(product: Product(name: lineName ?? "")))
        }
    }

    private func verification(_ input: VerificationInput) -> some View {
        FoodVerificationScreen(input: input, lineName: lineName, offersSaveToggle: offersSaveToggle) { food, save in
            if save { library.save(food) }
            onSave(food, save)
            dismiss()
        }
    }
}
