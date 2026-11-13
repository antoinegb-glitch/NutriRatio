import SwiftUI

struct SettingsView: View {
    @Environment(ProfileStore.self) private var store

    var body: some View {
        @Bindable var store = store
        Form {
            Section {
                Picker("Profil actif", selection: $store.selected) {
                    ForEach(ProfileKind.allCases) { kind in
                        Text(kind.title).tag(kind)
                    }
                }
            } footer: {
                Text("Le profil actif fixe les seuils de chaque critère. Il se change aussi depuis l'écran résultat.")
            }

            Section {
                ForEach(ProfileKind.allCases) { kind in
                    NavigationLink {
                        ProfileEditorView(kind: kind)
                    } label: {
                        HStack {
                            Text(kind.title)
                            Spacer()
                            if store.isModified(kind) {
                                Text("modifié").font(.footnote).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            } header: {
                Text("Seuils")
            } footer: {
                Text("Chaque profil est modifiable et peut être réinitialisé.")
            }

            Section {
                NavigationLink {
                    DailyIntakeEditorView()
                } label: {
                    HStack {
                        Text("Apports quotidiens")
                        Spacer()
                        if store.isDailyIntakeModified {
                            Text("modifié").font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                }
            } footer: {
                Text("Sert à afficher la part de l'apport quotidien couverte par le produit.")
            }

            Section {
                NavigationLink("Sources et méthode") { SourcesView() }
            }
        }
        .navigationTitle("Réglages")
    }
}

/// Édition des seuils (g pour 100 kcal) d'un profil.
struct ProfileEditorView: View {
    private enum FocusedField: Hashable {
        case low(Criterion), high(Criterion)
    }

    @Environment(ProfileStore.self) private var store
    let kind: ProfileKind
    @State private var draft: ProfileConfig?
    @State private var confirmReset = false
    @FocusState private var focused: FocusedField?

    var body: some View {
        // Le brouillon peut être temporairement invalide (bas ≥ haut) pendant la frappe :
        // seules les configurations valides sont enregistrées.
        let config = Binding(
            get: { draft ?? store.config(for: kind) },
            set: { newValue in
                draft = newValue
                store.setConfig(newValue, for: kind)
            }
        )

        Form {
            ForEach(Criterion.allCases) { criterion in
                Section {
                    thresholdRow("Seuil bas", value: config[criterion].low, focus: .low(criterion))
                    thresholdRow("Seuil haut", value: config[criterion].high, focus: .high(criterion))
                    if !config.wrappedValue[criterion].isValid {
                        Label("Non enregistré : il faut 0 < seuil bas < seuil haut.", systemImage: "xmark.octagon")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                } header: {
                    Text(criterion.title)
                } footer: {
                    Text(criterion.direction == .moreIsBetter
                         ? "Plus = mieux. Sous le seuil bas : pas intéressant ; à partir du seuil haut : intéressant."
                         : "Moins = mieux. Jusqu'au seuil bas : intéressant ; au-delà du seuil haut : pas intéressant.")
                }
            }

            Section {
                Button("Réinitialiser ce profil", role: .destructive) { confirmReset = true }
                    .disabled(!store.isModified(kind) && draft == nil)
                    // Attachée au bouton pour que la confirmation s'affiche à côté de lui.
                    .confirmationDialog("Restaurer les valeurs par défaut de ce profil ?", isPresented: $confirmReset, titleVisibility: .visible) {
                        Button("Réinitialiser", role: .destructive) {
                            focused = nil
                            store.reset(kind)
                            draft = nil
                        }
                    }
            } footer: {
                Text("Seuils en grammes pour 100 kcal.")
            }
        }
        .navigationTitle(kind.title)
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("OK") { focused = nil }
            }
        }
    }

    private func thresholdRow(_ title: LocalizedStringKey, value: Binding<Double>, focus: FocusedField) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField(title, value: value, format: .number.precision(.fractionLength(0...2)))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 90)
                .focused($focused, equals: focus)
            Text("g").foregroundStyle(.secondary)
        }
    }
}

/// Édition des apports quotidiens de référence, communs à tous les profils.
struct DailyIntakeEditorView: View {
    private enum Field: Hashable {
        case energy, criterion(Criterion)
    }

    @Environment(ProfileStore.self) private var store
    @State private var draft: DailyIntake?
    @State private var confirmReset = false
    @FocusState private var focused: Field?

    var body: some View {
        // Comme pour les profils : seules les valeurs valides (toutes > 0) sont enregistrées.
        let intake = Binding(
            get: { draft ?? store.dailyIntake },
            set: { newValue in
                draft = newValue
                store.setDailyIntake(newValue)
            }
        )

        Form {
            Section {
                row(String(localized: "Énergie"), value: intake.energyKcal, unit: "kcal", field: .energy)
                ForEach(Criterion.allCases) { criterion in
                    row(criterion.title, value: intake[criterion], unit: "g", field: .criterion(criterion))
                }
                if !intake.wrappedValue.isValid {
                    Label("Non enregistré : chaque valeur doit être supérieure à 0.", systemImage: "xmark.octagon")
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            } header: {
                Text("Par jour")
            } footer: {
                Text("Valeurs par défaut pour un adulte : apports de référence européens (énergie, protéines, sucres, graisses saturées), ANSES pour les fibres, OMS pour le sel. Détail dans « Sources et méthode ».")
            }

            Section {
                Button("Réinitialiser les apports", role: .destructive) { confirmReset = true }
                    .disabled(!store.isDailyIntakeModified && draft == nil)
                    .confirmationDialog("Restaurer les apports quotidiens par défaut ?", isPresented: $confirmReset, titleVisibility: .visible) {
                        Button("Réinitialiser", role: .destructive) {
                            focused = nil
                            store.resetDailyIntake()
                            draft = nil
                        }
                    }
            }
        }
        .navigationTitle("Apports quotidiens")
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("OK") { focused = nil }
            }
        }
    }

    private func row(_ title: String, value: Binding<Double>, unit: String, field: Field) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField(title, value: value, format: .number.precision(.fractionLength(0...1)))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 90)
                .focused($focused, equals: field)
            Text(unit)
                .foregroundStyle(.secondary)
                .frame(width: 36, alignment: .leading)
        }
    }
}
