import Foundation

/// Unités de quantité d'une ligne d'ingrédient.
enum RecipeUnit: String, Codable, CaseIterable, Identifiable, Hashable {
    case gram, kilogram, milligram
    case milliliter, centiliter, deciliter, liter
    case tablespoon, teaspoon, glass, cup
    case pinch, knob, ounce, pound
    /// Unité comptée (« 2 œufs », « 3 gousses d'ail »).
    case piece

    var id: String { rawValue }

    var label: String {
        switch self {
        case .gram: "g"
        case .kilogram: "kg"
        case .milligram: "mg"
        case .milliliter: "ml"
        case .centiliter: "cl"
        case .deciliter: "dl"
        case .liter: "l"
        case .tablespoon: String(localized: "c. à soupe")
        case .teaspoon: String(localized: "c. à café")
        case .glass: String(localized: "verre")
        case .cup: String(localized: "tasse")
        case .pinch: String(localized: "pincée")
        case .knob: String(localized: "noix de")
        case .ounce: "oz"
        case .pound: "lb"
        case .piece: String(localized: "pièce")
        }
    }

    /// Volume en ml pour les unités de volume, `nil` sinon.
    var milliliters: Double? {
        switch self {
        case .milliliter: 1
        case .centiliter: 10
        case .deciliter: 100
        case .liter: 1000
        case .tablespoon: 15
        case .teaspoon: 5
        case .glass: 200
        case .cup: 240
        default: nil
        }
    }

    /// Poids direct en g, pour les unités de masse.
    var gramsPerUnit: Double? {
        switch self {
        case .gram: 1
        case .kilogram: 1000
        case .milligram: 0.001
        case .ounce: 28.35
        case .pound: 453.6
        default: nil
        }
    }

    /// Volumes « exacts » (ml, cl, dl, l) : l'eau et le lait valent ≈ 1 g/ml, sinon on suppose 1 en le signalant.
    var isMetricVolume: Bool {
        switch self {
        case .milliliter, .centiliter, .deciliter, .liter: true
        default: false
        }
    }
}
