import SwiftUI

/// Écran de vérification éditable, commun aux trois modes d'entrée.
/// Les champs manquants ou douteux sont surlignés (couleur + icône).
/// `extra` ajoute des sections propres à l'appelant (alias d'un aliment…) sous le nom du produit.
struct VerificationView<Extra: View>: View {
    @State private var model: VerificationViewModel
    @FocusState private var focused: NutrientField?
    private let confirmTitle: LocalizedStringKey
    private let extra: Extra
    private let onEvaluate: (Product) -> Void

    init(input: VerificationInput, confirmTitle: LocalizedStringKey = "Analyser",
         @ViewBuilder extra: () -> Extra, onEvaluate: @escaping (Product) -> Void) {
        _model = State(initialValue: VerificationViewModel(input: input))
        self.confirmTitle = confirmTitle
        self.extra = extra()
        self.onEvaluate = onEvaluate
    }

    var body: some View {
        ScrollViewReader { proxy in
            form
                .onChange(of: focused) { _, field in
                    guard let field else { return }
                    // Le clavier numérique recouvre le bas du formulaire : une fois qu'il est
                    // affiché, on ramène le champ en cours de saisie dans la zone visible.
                    Task {
                        try? await Task.sleep(for: .milliseconds(400))
                        withAnimation { proxy.scrollTo(field, anchor: .center) }
                    }
                }
        }
    }

    private var form: some View {
        Form {
            if let notice = model.notice {
                Section {
                    Label(notice, systemImage: "info.circle")
                        .font(.subheadline)
                }
            }

            Section("Produit") {
                TextField("Nom (facultatif)", text: $model.name)
                if let subtitle = model.subtitle {
                    Text(subtitle).font(.footnote).foregroundStyle(.secondary)
                }
            }

            extra

            Section {
                ForEach(NutrientField.allCases) { field in
                    row(for: field)
                }
            } header: {
                Text("Valeurs pour 100 g ou 100 ml")
            } footer: {
                if model.hasHighlightedFields {
                    Label("Champs surlignés : valeur manquante ou à vérifier sur l'emballage. Un critère sans valeur est ignoré.", systemImage: "exclamationmark.triangle")
                }
            }

            Section {
                Button {
                    focused = nil
                    onEvaluate(model.makeProduct())
                } label: {
                    Text(confirmTitle)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!model.canEvaluate)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            } footer: {
                if !model.canEvaluate {
                    Text("Corrigez les valeurs en rouge (nombres positifs uniquement).")
                }
            }
        }
        .navigationTitle("Vérification")
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("OK") { focused = nil }
            }
        }
    }

    private func row(for field: NutrientField) -> some View {
        let state = model.state(of: field)
        let text = Binding(
            get: { model.texts[field] ?? "" },
            set: { newValue in
                if newValue != model.texts[field] ?? "" { model.userEdited(field) }
                model.texts[field] = newValue
            }
        )
        return HStack {
            if let icon = icon(for: state) {
                Image(systemName: icon)
                    .foregroundStyle(color(for: state))
                    .accessibilityHidden(true)
            }
            Text(field.title)
            Spacer()
            TextField("—", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 84)
                .focused($focused, equals: field)
                .accessibilityLabel(field.title)
                .accessibilityValue(accessibilityValue(for: field, state: state))
            Text(field.unit)
                .foregroundStyle(.secondary)
                .frame(width: 38, alignment: .leading)
        }
        .listRowBackground(state == .ok ? nil : color(for: state).opacity(0.15))
        .id(field)
    }

    private func icon(for state: VerificationViewModel.FieldState) -> String? {
        switch state {
        case .ok: nil
        case .missing: "questionmark.circle"
        case .doubtful: "exclamationmark.triangle"
        case .invalid: "xmark.octagon"
        }
    }

    private func color(for state: VerificationViewModel.FieldState) -> Color {
        switch state {
        case .ok: .primary
        case .missing: .yellow
        case .doubtful: .orange
        case .invalid: .red
        }
    }

    private func accessibilityValue(for field: NutrientField, state: VerificationViewModel.FieldState) -> String {
        let value = model.texts[field] ?? ""
        switch state {
        case .ok: return "\(value) \(field.unit)"
        case .missing: return String(localized: "valeur manquante")
        case .doubtful: return String(localized: "\(value) \(field.unit), à vérifier")
        case .invalid: return String(localized: "valeur invalide")
        }
    }
}

extension VerificationView where Extra == EmptyView {
    init(input: VerificationInput, onEvaluate: @escaping (Product) -> Void) {
        self.init(input: input, extra: { EmptyView() }, onEvaluate: onEvaluate)
    }
}
