import Foundation

/// Apports quotidiens de référence d'un adulte (g par jour, énergie en kcal par jour).
/// Valeurs par défaut dans `DefaultProfiles.dailyIntake` ; modifiables dans les réglages.
struct DailyIntake: Codable, Hashable {
    var energyKcal: Double
    var protein: Double
    var fiber: Double
    var carbohydrates: Double
    var sugars: Double
    var saturatedFat: Double
    var salt: Double

    subscript(criterion: Criterion) -> Double {
        get {
            switch criterion {
            case .protein: protein
            case .fiber: fiber
            case .sugars: sugars
            case .saturatedFat: saturatedFat
            case .salt: salt
            }
        }
        set {
            switch criterion {
            case .protein: protein = newValue
            case .fiber: fiber = newValue
            case .sugars: sugars = newValue
            case .saturatedFat: saturatedFat = newValue
            case .salt: salt = newValue
            }
        }
    }

    init(energyKcal: Double, protein: Double, fiber: Double, carbohydrates: Double,
         sugars: Double, saturatedFat: Double, salt: Double) {
        self.energyKcal = energyKcal
        self.protein = protein
        self.fiber = fiber
        self.carbohydrates = carbohydrates
        self.sugars = sugars
        self.saturatedFat = saturatedFat
        self.salt = salt
    }

    /// Les apports enregistrés avant l'ajout des glucides n'en contiennent pas : valeur par défaut.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        energyKcal = try container.decode(Double.self, forKey: .energyKcal)
        protein = try container.decode(Double.self, forKey: .protein)
        fiber = try container.decode(Double.self, forKey: .fiber)
        carbohydrates = try container.decodeIfPresent(Double.self, forKey: .carbohydrates)
            ?? DefaultProfiles.dailyIntake.carbohydrates
        sugars = try container.decode(Double.self, forKey: .sugars)
        saturatedFat = try container.decode(Double.self, forKey: .saturatedFat)
        salt = try container.decode(Double.self, forKey: .salt)
    }

    var isValid: Bool {
        energyKcal > 0 && carbohydrates > 0 && Criterion.allCases.allSatisfy { self[$0] > 0 }
    }

    /// Part de l'apport quotidien couverte par 100 kcal du produit, en %.
    func percent(of result: CriterionResult) -> Double {
        result.per100kcal / self[result.criterion] * 100
    }

    /// Part de l'apport quotidien couverte par 100 g du produit, en %.
    func percentPer100g(of result: CriterionResult) -> Double {
        result.per100g / self[result.criterion] * 100
    }

    /// Part des calories quotidiennes que représentent 100 kcal, en %. Repère de comparaison :
    /// un nutriment au-dessus de ce pourcentage est apporté plus que proportionnellement.
    var percentOfEnergyPer100kcal: Double {
        100 / energyKcal * 100
    }
}
