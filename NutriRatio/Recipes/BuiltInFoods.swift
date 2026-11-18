import Foundation

/// Aliments courants avec des valeurs moyennes pour 100 g, intégrés à l'app : une recette peut
/// être calculée sans rien avoir enregistré dans « Mon aliment ». Ordres de grandeur issus de
/// tables nutritionnelles usuelles (produits crus, sauf mention) : à remplacer par ses propres
/// produits dans « Mon aliment », qui priment toujours sur ceux-ci.
enum BuiltInFoods {
    /// Identifiants stables (jamais réutilisés ni renumérotés) : les recettes enregistrées s'y réfèrent.
    static let all: [FoodItem] = rows.map { row in
        FoodItem(
            id: UUID(uuidString: String(format: "00000000-0000-4000-8000-%012d", row.id))!,
            name: row.name,
            facts: NutritionFacts(energyKcal: row.v[0], fat: row.v[1], saturatedFat: row.v[2], carbohydrates: row.v[3],
                                  sugars: row.v[4], fiber: row.v[5], protein: row.v[6], salt: row.v[7]),
            aliases: row.aliases
        )
    }

    static let ids = Set(all.map(\.id))

    // v = [kcal, lipides, dont saturés, glucides, dont sucres, fibres, protéines, sel]
    private static let rows: [(id: Int, name: String, aliases: [String], v: [Double])] = [
        // Farines, féculents, céréales
        (1, "Farine", ["farine de blé", "farine T55", "farine T45"], [340, 1.2, 0.2, 72, 1.5, 3.5, 10, 0.01]),
        (2, "Maïzena", ["fécule", "fécule de maïs", "amidon de maïs"], [350, 0, 0, 86, 0, 0, 0.3, 0.02]),
        (3, "Riz", ["riz blanc", "riz basmati", "riz long"], [350, 1, 0.3, 78, 0.2, 1, 7, 0.01]),
        (4, "Pâtes", ["pâtes alimentaires", "spaghetti", "tagliatelles", "macaronis", "penne", "coquillettes"], [360, 1.5, 0.3, 72, 3, 3, 12.5, 0.02]),
        (5, "Semoule", ["semoule de blé", "couscous"], [360, 1.5, 0.2, 73, 1, 3, 12, 0.01]),
        (6, "Flocons d'avoine", ["avoine"], [370, 7, 1.3, 60, 1, 10, 13, 0.02]),
        (7, "Pain", ["pain de mie", "baguette"], [270, 1.5, 0.3, 52, 3, 3, 9, 1.2]),
        (8, "Pâte brisée", ["pâte sablée"], [420, 24, 12, 45, 1, 2, 6, 1.0]),
        (9, "Pâte feuilletée", [], [450, 28, 15, 41, 1, 2, 6, 1.0]),
        // Sucres, sucrants
        (10, "Sucre", ["sucre en poudre", "sucre semoule", "sucre glace", "cassonade", "sucre roux", "sucre de canne"], [400, 0, 0, 100, 100, 0, 0, 0]),
        (11, "Sucre vanillé", [], [390, 0, 0, 97, 97, 0, 0, 0]),
        (12, "Miel", [], [320, 0, 0, 80, 79, 0, 0.4, 0]),
        (13, "Sirop d'érable", [], [260, 0, 0, 67, 60, 0, 0, 0]),
        (14, "Confiture", [], [250, 0.1, 0, 60, 55, 1, 0.5, 0.01]),
        // Chocolat, cacao
        (15, "Chocolat noir", ["chocolat", "chocolat pâtissier", "chocolat noir pâtissier", "pépites de chocolat"], [550, 36, 22, 40, 32, 11, 7, 0.02]),
        (16, "Chocolat au lait", [], [540, 32, 19, 56, 55, 2, 7, 0.2]),
        (17, "Chocolat blanc", [], [560, 33, 20, 58, 58, 0, 6, 0.2]),
        (18, "Cacao en poudre", ["cacao", "cacao maigre"], [355, 21, 12, 12, 1, 29, 22, 0.05]),
        // Matières grasses
        (19, "Beurre", ["beurre doux"], [750, 82, 52, 0.6, 0.6, 0, 0.7, 0.04]),
        (20, "Beurre demi-sel", [], [750, 82, 52, 0.6, 0.6, 0, 0.7, 1.5]),
        (21, "Huile", ["huile de tournesol", "huile végétale", "huile de colza"], [900, 100, 10, 0, 0, 0, 0, 0]),
        (22, "Huile d'olive", [], [900, 100, 14, 0, 0, 0, 0, 0]),
        (23, "Beurre de cacahuète", ["purée de cacahuète"], [620, 50, 10, 13, 8, 6, 25, 0.5]),
        // Produits laitiers, œufs
        (24, "Œuf", ["œufs entiers"], [140, 9.5, 2.6, 0.3, 0.3, 0, 12.5, 0.35]),
        (25, "Jaune d'œuf", [], [350, 31, 9.5, 0.3, 0.3, 0, 16, 0.1]),
        (26, "Blanc d'œuf", [], [45, 0.1, 0, 0.7, 0.7, 0, 10, 0.4]),
        (27, "Lait", ["lait demi-écrémé"], [46, 1.6, 1, 4.8, 4.8, 0, 3.2, 0.1]),
        (28, "Lait entier", [], [65, 3.7, 2.4, 4.7, 4.7, 0, 3.3, 0.1]),
        (29, "Lait écrémé", [], [33, 0.1, 0.1, 4.8, 4.8, 0, 3.4, 0.1]),
        (30, "Lait de coco", [], [190, 19, 17, 3, 2.5, 0, 2, 0.05]),
        (31, "Crème liquide", ["crème", "crème fleurette", "crème entière"], [300, 30, 20, 3, 3, 0, 2.2, 0.07]),
        (32, "Crème fraîche", ["crème épaisse"], [300, 30, 20, 3, 3, 0, 2.2, 0.07]),
        (33, "Yaourt nature", ["yaourt", "yogourt"], [60, 3, 2, 4.5, 4.5, 0, 4, 0.1]),
        (34, "Fromage blanc", [], [75, 3, 2, 4, 4, 0, 8, 0.1]),
        (35, "Fromage râpé", ["emmental", "gruyère", "emmental râpé"], [380, 28, 18, 1, 0.5, 0, 28, 1.0]),
        (36, "Mozzarella", [], [250, 18, 11, 1, 1, 0, 18, 0.6]),
        (37, "Parmesan", [], [400, 28, 18, 0, 0, 0, 36, 1.6]),
        (38, "Mascarpone", [], [430, 44, 28, 3, 3, 0, 4, 0.1]),
        // Fruits et oléagineux
        (39, "Pomme", [], [52, 0.2, 0, 11.4, 10.4, 2.4, 0.3, 0]),
        (40, "Banane", [], [90, 0.3, 0.1, 20, 17, 2, 1.1, 0]),
        (41, "Citron", [], [29, 0.3, 0, 6.5, 2.5, 2.8, 1.1, 0]),
        (42, "Jus de citron", [], [22, 0.1, 0, 6.5, 2.5, 0, 0.4, 0]),
        (43, "Orange", [], [47, 0.1, 0, 9.4, 8.4, 2.4, 0.9, 0]),
        (44, "Fraise", [], [33, 0.3, 0, 5.5, 5, 2, 0.7, 0]),
        (45, "Framboise", [], [43, 0.5, 0, 5.1, 4.5, 6.5, 1.2, 0]),
        (46, "Myrtille", [], [50, 0.3, 0, 10, 7, 3, 0.7, 0]),
        (47, "Amande", ["poudre d'amande", "amandes effilées"], [620, 53, 4, 6, 4, 12, 22, 0.01]),
        (48, "Noisette", ["poudre de noisette"], [650, 62, 5, 7, 4, 10, 15, 0]),
        (49, "Noix", [], [690, 65, 6, 7, 3, 7, 15, 0.01]),
        (50, "Noix de cajou", [], [590, 46, 8, 27, 6, 3, 18, 0.02]),
        (51, "Noix de pécan", [], [690, 72, 6, 4, 4, 9, 9, 0]),
        (52, "Noix de coco", ["noix de coco râpée", "coco râpée"], [600, 60, 53, 7, 6, 13, 6, 0.05]),
        // Légumes, légumineuses
        (53, "Oignon", ["échalote"], [40, 0.1, 0, 8, 5, 1.7, 1.2, 0]),
        (54, "Ail", [], [130, 0.5, 0.1, 25, 1, 2, 6, 0]),
        (55, "Carotte", [], [36, 0.2, 0, 7.5, 6, 3, 0.8, 0.1]),
        (56, "Pomme de terre", [], [80, 0.1, 0, 17, 1, 2, 2, 0.01]),
        (57, "Tomate", [], [18, 0.2, 0, 3.5, 2.6, 1.2, 0.9, 0.01]),
        (58, "Concentré de tomate", [], [80, 0.5, 0.1, 14, 11, 4, 4, 0.3]),
        (59, "Courgette", [], [17, 0.3, 0.1, 2.5, 2, 1, 1.2, 0]),
        (60, "Poivron", [], [30, 0.3, 0, 5, 4, 2, 1, 0]),
        (61, "Champignon", ["champignons de Paris"], [22, 0.3, 0, 1, 1, 2, 3, 0.01]),
        (62, "Épinards", [], [23, 0.5, 0.1, 1, 0.5, 2.5, 2.7, 0.2]),
        (63, "Brocoli", [], [34, 0.4, 0.1, 2.7, 1.7, 3, 3, 0.05]),
        (64, "Aubergine", [], [25, 0.2, 0, 3, 3, 3, 1, 0]),
        (65, "Haricots verts", [], [30, 0.2, 0, 4, 2, 3, 2, 0]),
        (66, "Pois chiches", ["pois chiches cuits"], [140, 2.5, 0.3, 18, 3, 5, 8, 0.01]),
        (67, "Lentilles", ["lentilles cuites"], [115, 0.5, 0.1, 17, 1, 4, 9, 0]),
        (68, "Haricots rouges", ["haricots rouges cuits"], [100, 0.5, 0.1, 15, 1, 6, 7, 0.02]),
        // Viandes, poissons, protéines
        (69, "Poulet", ["blanc de poulet", "filet de poulet"], [110, 1.5, 0.4, 0, 0, 0, 23, 0.15]),
        (70, "Bœuf haché", ["viande hachée", "steak haché"], [215, 15, 6.5, 0, 0, 0, 19, 0.15]),
        (71, "Jambon blanc", ["jambon"], [110, 3.5, 1.2, 0.5, 0.4, 0, 19, 2.0]),
        (72, "Lardons", [], [270, 22, 8, 0.5, 0, 0, 17, 2.4]),
        (73, "Saumon", [], [200, 12, 2.5, 0, 0, 0, 20, 0.12]),
        (74, "Thon", ["thon au naturel"], [110, 1, 0.3, 0, 0, 0, 25, 0.9]),
        (75, "Tofu", [], [125, 7, 1, 2, 0.5, 1, 13, 0.05]),
        // Pâtisserie, fromage frais, épices
        (79, "Levure chimique", ["levure", "poudre à lever", "baking powder"], [53, 0, 0, 28, 0, 0.2, 0, 27]),
        (80, "Bicarbonate de soude", ["bicarbonate", "bicarbonate alimentaire", "baking soda"], [0, 0, 0, 0, 0, 0, 0, 68]),
        (81, "Extrait de vanille", ["vanille", "vanille liquide", "arôme de vanille"], [288, 0.1, 0, 13, 13, 0, 0.1, 0.01]),
        (82, "Cream cheese", ["Philadelphia", "fromage frais à tartiner", "fromage à tartiner"], [250, 23, 15, 3.5, 3.5, 0, 6, 0.8]),
        (83, "Cannelle", ["cannelle en poudre"], [247, 1.2, 0.3, 80, 2, 53, 4, 0.02]),
        // Assaisonnements, eau
        (76, "Sel", ["gros sel", "sel fin", "fleur de sel"], [0, 0, 0, 0, 0, 0, 0, 100]),
        (77, "Poivre", [], [250, 3, 1, 50, 0, 25, 10, 0.05]),
        (78, "Eau", ["eau froide", "eau chaude", "eau tiède"], [0, 0, 0, 0, 0, 0, 0, 0]),
    ]
}
