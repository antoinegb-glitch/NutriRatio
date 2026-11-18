# NutriRatio

App iOS (SwiftUI, iOS 17+) qui indique, nutriment par nutriment, **pour quoi un produit alimentaire est intéressant par rapport à ses calories** (protéines, fibres) et ce qu'il faut limiter (sucres, graisses saturées, sel), avec la part de l'apport quotidien que cela représente, selon un profil (Équilibré, Sèche, Prise de masse, Personnalisé). 100 % locale, sans compte, sans dépendance tierce.

## Recettes et Mon aliment

- **Mon aliment** : bibliothèque locale d'aliments (valeurs pour 100 g, alias, poids d'une pièce, aliment « par défaut » d'un nom). Création par scan de code-barres, photo + OCR ou saisie manuelle, toujours via l'écran de vérification ; un produit déjà analysé s'enregistre depuis son résultat (bouton en haut à droite).
- **Valeurs par défaut** : ~85 aliments courants (farine, sucre, beurre, œuf, lait, légumes…) sont intégrés avec des valeurs moyennes (`Recipes/BuiltInFoods.swift`). Une ligne de recette s'y associe d'elle-même, « (valeur moyenne) », sans rien créer dans Mon aliment ; un aliment de Mon aliment de même nom ou alias les remplace toujours. Nom exact : aucune vérification demandée ; nom partiel (« farine de sarrasin ») : « à vérifier ». L'association se refait à l'ouverture pour les lignes sans aliment (recettes enregistrées avant, aliment supprimé) et suit la frappe du nom.
- **Recettes** : saisie manuelle ou texte collé (section « Ingrédients » détectée, étapes ignorées ; FR et EN, fractions, plages, « une pincée », « quelques »…). L'écran de vérification surligne les lignes douteuses. Chaque ligne est associée automatiquement à l'aliment par défaut correspondant (nom ou alias, sans casse, accents ni pluriel), « à vérifier » ; sans correspondance : scanner, photo + OCR, saisie manuelle ou choix dans Mon aliment, avec « Ajouter à Mon aliment » activé par défaut.
- **Calcul** : total = Σ poids / 100 × valeurs de l'aliment ; composition au 100 g = total / poids de référence × 100, où le poids de référence est la somme des poids crus, ou le poids final saisi (les totaux ne changent pas). Valeurs par portion si le nombre de portions est renseigné. La recette est convertie en produit au 100 g puis évaluée par le moteur de scoring existant, sans changement.
- **Valeurs manquantes** : un nutriment absent d'un aliment n'est jamais compté comme 0. Il est ignoré dans la note (comme pour un produit), affiché « partiel » dans les totaux, et un bandeau l'indique.
- **Stockage** : JSON en UserDefaults (`foods.v1`, `recipes.v1`), comme l'historique, plutôt que SwiftData : faibles volumes, modèles `Codable` testables avec `swift test`, aucun schéma à migrer. Les recettes stockent une *référence* vers l'aliment : modifier un aliment recalcule les recettes à l'ouverture ; supprimer un aliment remet la ligne à « associer ».

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
| `Recipes` | Logique pure des recettes : `FoodItem`/`FoodLibrary`/`FoodMatcher` (Mon aliment), `Recipe`/`RecipeStore`, `RecipeTextParser`, `WeightConverter` (unités → grammes), `RecipeCalculator` |
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
- **Recettes, conversions** : les poids de pièces (1 œuf = 55 g) et densités (1 c. à soupe d'huile ≈ 13,5 g) sont des moyennes, modifiables ligne par ligne ; le poids d'une pièce défini dans Mon aliment prime. Une cuillère, une tasse ou une pièce inconnue reste « poids à préciser » ; un volume métrique (cl, ml) d'un ingrédient inconnu est compté à 1 g/ml et signalé.
- **Recettes, texte collé** : heuristiques locales, pas d'IA. Les sous-titres (« Pour la pâte ») sont ignorés, les lignes sans quantité (« Sel ») sont gardées à compléter ; les phrases d'étapes mêlées à la liste sans titre « Ingrédients » peuvent être prises à tort ou manquées, d'où l'écran de vérification systématique. Pas de poids lu entre parenthèses (« boîte (400 g) »).
- **Recettes, association** : un nom plus général que l'aliment (« chocolat » pour « chocolat noir ») n'est proposé qu'au choix, jamais associé automatiquement. Après suppression d'un aliment, la ligne n'est pas ré-associée toute seule.
- Un résultat de recette n'entre pas dans l'historique : « Mes recettes » en tient lieu.
- Historique local des 50 derniers produits analysés (un même code-barres n'apparaît qu'une fois) ; pas de favoris ni de synchronisation.
- Aide à la décision, pas un avis médical.
