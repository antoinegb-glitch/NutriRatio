import Foundation

/// Apports quotidiens de référence d'un adulte (g par jour, énergie en kcal par jour).
/// Valeurs par défaut dans `DefaultProfiles.dailyIntake` ; modifiables dans les réglages.
struct DailyIntake: Codable, Hashable {
    var energyKcal: Double
    var protein: Double
    var fiber: Double
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

    var isValid: Bool {
        energyKcal > 0 && Criterion.allCases.allSatisfy { self[$0] > 0 }
    }

    /// Part de l'apport quotidien couverte par 100 kcal du produit, en %.
    func percent(of result: CriterionResult) -> Double {
        result.per100kcal / self[result.criterion] * 100
    }

    /// Part des calories quotidiennes que représentent 100 kcal, en %. Repère de comparaison :
    /// un nutriment au-dessus de ce pourcentage est apporté plus que proportionnellement.
    var percentOfEnergyPer100kcal: Double {
        100 / energyKcal * 100
    }
}
