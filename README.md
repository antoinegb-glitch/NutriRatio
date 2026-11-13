# NutriRatio

App iOS (SwiftUI, iOS 17+) qui indique, nutriment par nutriment, **pour quoi un produit alimentaire est intéressant par rapport à ses calories** (protéines, fibres) et ce qu'il faut limiter (sucres, graisses saturées, sel), avec la part de l'apport quotidien que cela représente, selon un profil (Équilibré, Sèche, Prise de masse, Personnalisé). 100 % locale, sans compte, sans dépendance tierce.

## Lancer

```bash
xcodegen generate
```

```bash
open NutriRatio.xcodeproj
```

Le projet Xcode est généré à partir de `project.yml` : relancez `xcodegen generate` après avoir ajouté ou supprimé un fichier.

## Tests

Tests de la logique (moteur, parseur OCR, décodage Open Food Facts) sur le Mac, sans simulateur :

```bash
swift test
```

Dans Xcode : `Cmd+U` (nécessite un simulateur iOS, à installer via Xcode > Settings > Components).

## Installer sur iPhone

1. Brancher l'iPhone (ou le jumeler en Wi-Fi) et activer le **mode développeur** : Réglages > Confidentialité et sécurité > Mode développeur.
2. Dans Xcode : cible **NutriRatio** > *Signing & Capabilities* > choisir votre *Team* (un identifiant Apple gratuit suffit). Si l'identifiant de bundle est refusé, changez-le dans `project.yml` (`PRODUCT_BUNDLE_IDENTIFIER`).
3. Sélectionner l'iPhone comme destination, puis `Cmd+R`.
4. Au premier lancement : Réglages > Général > VPN et gestion de l'appareil > faire confiance au certificat de développeur.

Avec un compte gratuit, l'app doit être réinstallée tous les 7 jours. Pour cela, enregistrez une fois l'identifiant de l'iPhone (colonne « Identifier » de `xcrun devicectl list devices`) dans un fichier `.iphone-udid` à la racine (non versionné), puis, iPhone branché et déverrouillé :

```bash
./installer-iphone.sh
```

## Organisation

| Dossier | Contenu |
|---|---|
| `Models` | `NutritionFacts`, `Product`, `Evaluation`, `ProfileConfig`, `DailyIntake`, `ProfileStore` et `HistoryStore` (UserDefaults) |
| `Scoring` | `DefaultProfiles.swift` (seules valeurs par défaut : seuils des profils et apports quotidiens, commentées), `ScoringEngine` |
| `Parsing` | Assemblage des lignes OCR, parseur d'étiquette FR/EN |
| `Services` | Open Food Facts (API v2), OCR Vision |
| `ViewModels`, `Views` | Écrans SwiftUI |
| `Resources` | `Info.plist`, String Catalog (`Localizable.xcstrings`, langue source : français) |

`Package.swift` ne sert qu'à `swift test` : il compile les dossiers de logique pure pour macOS.

## Limites connues

- **OCR** : fiable sur un tableau net, à plat, cadré serré. Fragile sur les emballages courbes ou froissés, les reflets, les photos inclinées (les lignes sont reconstituées par alignement horizontal), les tableaux à plus de deux colonnes, l'énergie écrite « 1590 / 378 » sans unités, et la confusion « g » → « 9 ». L'écran de vérification sert à rattraper ces erreurs.
- **Portions** : la conversion vers 100 g n'est faite que si la taille de portion est lisible en g ou ml ; sinon les valeurs sont signalées comme non converties.
- **Open Food Facts** : données collaboratives, parfois incomplètes ou fausses.
- **Sucres** : l'étiquette ne distingue pas sucres naturels et ajoutés ; yaourts nature et fruits sont pénalisés.
- **String Catalog** : il se remplit à la première compilation dans Xcode ; l'anglais reste à traduire.
- Historique local des 50 derniers produits analysés (un même code-barres n'apparaît qu'une fois) ; pas de favoris ni de synchronisation.
- Aide à la décision, pas un avis médical.
