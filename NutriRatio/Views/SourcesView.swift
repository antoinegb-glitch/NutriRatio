import SwiftUI

/// Explique d'où viennent les valeurs par défaut et ce qui relève d'un choix de conception.
struct SourcesView: View {
    var body: some View {
        List {
            Section("Principe") {
                Text("Chaque nutriment est rapporté aux calories du produit : valeur pour 100 kcal = valeur pour 100 g ÷ kcal pour 100 g × 100. On compare ainsi ce que le produit apporte pour l'énergie qu'il coûte.")
            }

            Section("Origine des seuils par défaut") {
                source("Protéines", "Allégations nutritionnelles européennes (règlement CE 1924/2006) : « source de protéines » à 12 % de l'énergie (3 g pour 100 kcal), « riche en protéines » à 20 % (5 g). Profil Sèche : 20 à 30 % de l'énergie, fourchette associée à une meilleure satiété (5 et 7,5 g).")
                source("Fibres", "Allégations européennes : « source de fibres » à 1,5 g pour 100 kcal, « riche en fibres » à 3 g pour 100 kcal.")
                source("Sucres", "OMS : moins de 10 % de l'énergie (2,5 g pour 100 kcal), idéalement moins de 5 % (1,25 g).")
                source("Graisses saturées", "EFSA et repères nutritionnels : moins de 10 % de l'énergie, soit environ 1,1 g pour 100 kcal.")
                source("Sel", "OMS : moins de 5 g par jour, ramené à un apport de 2000 kcal, soit 0,25 g pour 100 kcal.")
                source("Glucides", "ANSES (2016) : 40 à 55 % de l'énergie, soit environ 14 g pour 100 kcal au plus (seuil bas) ; OMS : jusqu'à 75 % de l'énergie, soit environ 19 g (seuil haut). Profil Sèche : 10 et 14 g. Les repères valent pour la journée entière : un féculent complet comme le pain peut sortir « moyen », ce qui n'est pas un défaut. Privilégiez les glucides riches en fibres.")
                source("Seuil « moyen »", "Pour les graisses saturées et le sel : recommandation + 30 % (1,45 g et 0,33 g).")
            }

            Section("Apports quotidiens par défaut") {
                source("Énergie, protéines, glucides, sucres, graisses saturées", "Apports de référence du règlement (UE) 1169/2011 pour un adulte, ceux des « % AR » des emballages : 2000 kcal, 50 g de protéines, 260 g de glucides, 90 g de sucres (repère pour les sucres totaux, pas un objectif), 20 g de graisses saturées.")
                source("Fibres", "ANSES (2016) : 30 g par jour pour un adulte.")
                source("Sel", "OMS : moins de 5 g par jour (le règlement européen retient 6 g).")
                source("Lecture", "Deux pourcentages sont affichés : la part de l'apport quotidien couverte par 100 kcal du produit (celui qui sert au jugement), et celle couverte par 100 g du produit (information). Repère pour le premier : 100 kcal représentent 5 % de 2000 kcal ; un nutriment au-delà de ce repère est apporté plus que proportionnellement. Ces valeurs sont modifiables dans les réglages.")
            }

            Section("Lecture du résultat") {
                Text("Chaque critère est jugé séparément, sans note globale : un défaut (pas de fibres) ne masque pas une qualité (beaucoup de protéines).")
                Text("Protéines, fibres (plus = mieux) : sous le seuil bas, faible ; à partir du seuil haut, le produit est « intéressant pour » ce nutriment.")
                Text("Glucides, sucres, graisses saturées, sel (moins = mieux) : jusqu'au seuil bas, bas ; au-delà du seuil haut, le nutriment est « à limiter ».")
                Text("Un critère sans donnée est ignoré et signalé. Sous 5 kcal pour 100 g (eau, café, thé), l'évaluation est « non applicable ».")
            }

            Section("Limites") {
                Label("Le passage au « par kcal », les ajustements du profil Prise de masse et le jugement des glucides (bas = peu de glucides pour les calories) sont des choix de conception, pas des recommandations officielles.", systemImage: "slider.horizontal.3")
                Label("NutriRatio est une aide à la décision, pas un avis médical ou diététique.", systemImage: "cross.case")
                Label("Les « sucres » de l'étiquette incluent les sucres naturels (fruits, lait), pas seulement les sucres ajoutés : un yaourt nature ou un fruit peut être pénalisé.", systemImage: "leaf")
                Label("Les données Open Food Facts sont collaboratives et la lecture de photo peut se tromper : vérifiez toujours les valeurs.", systemImage: "exclamationmark.triangle")
            }

            Section("Confidentialité") {
                Text("Aucun compte, aucune collecte, aucune statistique. Seule la recherche par code-barres interroge Open Food Facts (le code-barres est envoyé, rien d'autre). Les photos sont analysées sur l'appareil, et l'historique y reste.")
            }
        }
        .navigationTitle("Sources et méthode")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func source(_ title: LocalizedStringKey, _ detail: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.headline)
            Text(detail).font(.subheadline).foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}
