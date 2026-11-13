import SwiftUI

enum Route: Hashable {
    case scanner
    case photo
    case verify(VerificationInput)
    case result(Product)
    case settings
    case sources
}

struct HomeView: View {
    @Environment(ProfileStore.self) private var store
    @Environment(HistoryStore.self) private var history
    @State private var path: [Route] = []
    @State private var confirmClearHistory = false

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(spacing: 8) {
                        Image(systemName: "scalemass")
                            .font(.system(size: 44))
                            .foregroundStyle(.tint)
                            .accessibilityHidden(true)
                        Text("Ce produit vaut-il ses calories ?")
                            .font(.title2.bold())
                            .multilineTextAlignment(.center)
                        Text("Profil actif : \(store.selected.title)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 24)

                    entryButton("Scanner un code-barres", subtitle: "Recherche dans Open Food Facts", icon: "barcode.viewfinder", route: .scanner)
                    entryButton("Photographier le tableau", subtitle: "Lecture automatique des valeurs", icon: "camera.viewfinder", route: .photo)
                    entryButton("Saisie manuelle", subtitle: "Valeurs pour 100 g", icon: "square.and.pencil", route: .verify(VerificationInput(product: Product())))

                    if !history.entries.isEmpty {
                        historySection
                    }

                    NavigationLink(value: Route.sources) {
                        Label("Sources et méthode", systemImage: "book")
                            .font(.subheadline)
                    }
                    .padding(.top, 16)
                }
                .padding()
            }
            .navigationTitle("NutriRatio")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(value: Route.settings) {
                        Image(systemName: "slider.horizontal.3")
                    }
                    .accessibilityLabel("Réglages")
                }
            }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .scanner:
                    BarcodeScannerScreen { input in replaceTop(with: .verify(input)) }
                case .photo:
                    PhotoScreen { input in replaceTop(with: .verify(input)) }
                case .verify(let input):
                    VerificationView(input: input) { product in
                        history.record(product)
                        path.append(.result(product))
                    }
                case .result(let product):
                    ResultView(product: product)
                case .settings:
                    SettingsView()
                case .sources:
                    SourcesView()
                }
            }
        }
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Historique")
                    .font(.title3.bold())
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button("Effacer") { confirmClearHistory = true }
                    .font(.subheadline)
                    .confirmationDialog("Effacer tout l'historique ?", isPresented: $confirmClearHistory, titleVisibility: .visible) {
                        Button("Effacer l'historique", role: .destructive) { history.removeAll() }
                    }
            }
            VStack(spacing: 0) {
                ForEach(history.entries) { entry in
                    NavigationLink(value: Route.result(entry.product)) {
                        HistoryRow(entry: entry, config: store.activeConfig)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Supprimer de l'historique", systemImage: "trash", role: .destructive) {
                            history.remove(entry)
                        }
                    }
                    if entry.id != history.entries.last?.id {
                        Divider().padding(.leading)
                    }
                }
            }
            .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 16))
            Text("Appui long sur un produit pour le supprimer. L'historique reste sur cet appareil.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 16)
    }

    /// Remplace l'écran de capture par l'écran de vérification : « Retour » revient à l'accueil.
    private func replaceTop(with route: Route) {
        if !path.isEmpty { path.removeLast() }
        path.append(route)
    }

    private func entryButton(_ title: LocalizedStringKey, subtitle: LocalizedStringKey, icon: String, route: Route) -> some View {
        NavigationLink(value: route) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title)
                    .frame(width: 44)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline)
                    Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}

/// Produit de l'historique : nom, date et points forts selon le profil actif.
private struct HistoryRow: View {
    let entry: HistoryEntry
    let config: ProfileConfig

    var body: some View {
        let strengths = ScoringEngine.evaluate(entry.product.facts, config: config).strengths
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if !strengths.isEmpty {
                    Label(strengths.map(\.criterion.title).joined(separator: ", "), systemImage: "checkmark.circle.fill")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.green)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var title: String {
        let name = entry.product.name.trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? String(localized: "Produit sans nom") : name
    }

    private var subtitle: String {
        let date = entry.date.formatted(.relative(presentation: .named))
        guard let brand = entry.product.brand, !brand.isEmpty else { return date }
        return "\(brand) · \(date)"
    }

    private var icon: String {
        switch entry.product.source {
        case .barcode: "barcode"
        case .photo: "camera"
        case .manual: "square.and.pencil"
        }
    }
}
