import SwiftUI

extension Verdict {
    var color: Color {
        switch self {
        case .interesting: .green
        case .average: .orange
        case .notInteresting: .red
        }
    }

    /// Icône distincte par verdict : l'information ne repose pas sur la seule couleur.
    var iconName: String {
        switch self {
        case .interesting: "checkmark.circle.fill"
        case .average: "minus.circle.fill"
        case .notInteresting: "xmark.circle.fill"
        }
    }
}

struct ResultView: View {
    @Environment(ProfileStore.self) private var store
    let product: Product

    var body: some View {
        @Bindable var store = store
        let evaluation = ScoringEngine.evaluate(product.facts, config: store.activeConfig)

        List {
            Section {
                Picker("Profil", selection: $store.selected) {
                    ForEach(ProfileKind.allCases) { kind in
                        Text(kind.shortTitle).tag(kind)
                            .accessibilityLabel(kind.title)
                    }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            } footer: {
                Text("Changez de profil pour comparer le même produit.")
            }

            if let reason = evaluation.notApplicable {
                Section { notApplicableView(reason) }
            } else {
                summary(evaluation)
                Section("Détail, pour 100 kcal") {
                    ForEach(evaluation.criteria) { result in
                        CriterionRow(result: result, intake: store.dailyIntake)
                    }
                }
            }

            Section {
                ForEach(NutrientField.allCases) { field in
                    factRow(field.title, product.facts[field], unit: field.unit)
                }
            } header: {
                Text("Valeurs pour 100 g")
            }

            if !evaluation.missing.isEmpty {
                Section("Critères ignorés") {
                    ForEach(evaluation.missing) { criterion in
                        Label("\(criterion.title) : donnée manquante, critère non pris en compte", systemImage: "questionmark.circle")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if !evaluation.warnings.isEmpty {
                Section("Alertes de cohérence") {
                    ForEach(evaluation.warnings, id: \.self) { warning in
                        Label(warning.message, systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline)
                            .foregroundStyle(.orange)
                    }
                }
            }

            Section {
                Text("Aide à la décision, pas un avis médical. Les « sucres » de l'étiquette incluent les sucres naturels (fruits, lait).")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(product.name.isEmpty ? String(localized: "Résultat") : product.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Points forts et points à surveiller, rapportés aux calories : pas de note globale.
    @ViewBuilder
    private func summary(_ evaluation: Evaluation) -> some View {
        Section {
            if evaluation.strengths.isEmpty {
                Label("Ni riche en protéines ni en fibres pour ses calories.", systemImage: "minus.circle")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(evaluation.strengths) { result in
                    SummaryRow(result: result, intake: store.dailyIntake)
                }
            }
        } header: {
            Text("Intéressant pour")
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                if let energy = product.facts.energyKcal {
                    Text("\(energy.formatted(.number.precision(.fractionLength(0...1)))) kcal pour 100 g · profil \(store.selected.title)")
                }
                Text("Les % sont la part de l'apport quotidien couverte par 100 kcal du produit (ou par 100 g, quand c'est précisé). 100 kcal représentent \(formattedPercent(store.dailyIntake.percentOfEnergyPer100kcal)) de vos \(store.dailyIntake.energyKcal.formatted()) kcal par jour. Au-delà de ce repère, le nutriment est apporté plus que proportionnellement.")
            }
        }

        if !evaluation.cautions.isEmpty {
            Section("À limiter") {
                ForEach(evaluation.cautions) { result in
                    SummaryRow(result: result, intake: store.dailyIntake)
                }
            }
        }
    }

    private func factRow(_ title: String, _ value: Double?, unit: String) -> some View {
        LabeledContent(title) {
            if let value {
                Text("\(value.formatted(.number.precision(.fractionLength(0...2)))) \(unit)")
                    .monospacedDigit()
            } else {
                Text("—").foregroundStyle(.secondary)
            }
        }
    }

    private func notApplicableView(_ reason: Evaluation.NotApplicableReason) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "nosign")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text("Non applicable")
                .font(.title.bold())
            Text(reason.message)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }
}

/// « 33 % », avec une décimale sous 10 % pour ne pas afficher « 0 % » pour le sel.
private func formattedPercent(_ value: Double) -> String {
    let digits = value < 10 ? 1 : 0
    return (value / 100).formatted(.percent.precision(.fractionLength(0...digits)))
}

/// Ligne mise en avant : « Protéines — 16 g / 100 kcal — 33 % par jour ».
private struct SummaryRow: View {
    let result: CriterionResult
    let intake: DailyIntake

    var body: some View {
        let percent = formattedPercent(intake.percent(of: result))
        let percentPer100g = formattedPercent(intake.percentPer100g(of: result))
        HStack(spacing: 12) {
            Image(systemName: result.level.iconName)
                .font(.title2)
                .foregroundStyle(result.level.color)
                .accessibilityHidden(true)
            Text(result.criterion.title)
                .font(.title3.bold())
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(result.formattedPer100kcal) g / 100 kcal")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
                Text("\(percent) de l'apport / 100 kcal")
                    .font(.footnote.monospacedDigit().weight(.semibold))
                    .foregroundStyle(result.level.color)
                Text("\(percentPer100g) de l'apport / 100 g")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "\(result.explanation). \(percent) de l'apport quotidien pour 100 kcal, \(percentPer100g) pour 100 g."))
    }
}

private struct CriterionRow: View {
    let result: CriterionResult
    let intake: DailyIntake

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Image(systemName: result.level.iconName)
                .foregroundStyle(result.level.color)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(result.explanation)
                    .font(.subheadline)
                Text("\(formattedPercent(intake.percent(of: result))) de l'apport quotidien pour 100 kcal, \(formattedPercent(intake.percentPer100g(of: result))) pour 100 g (\(intake[result.criterion].formatted()) g par jour)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
