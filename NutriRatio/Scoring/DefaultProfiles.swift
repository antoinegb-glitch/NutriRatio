import Foundation

/// Valeurs par défaut de tous les profils. C'est le SEUL endroit où elles sont définies.
///
/// Tous les seuils sont en grammes pour 100 kcal. Conversion depuis un pourcentage de
/// l'énergie : g/100 kcal = % de l'énergie / kcal par gramme (4 pour protéines et sucres,
/// 9 pour les lipides).
///
/// Justification des seuils :
/// - Protéines — allégations européennes (règlement CE 1924/2006) : « source de protéines »
///   = 12 % de l'énergie (12 / 4 = 3 g) ; « riche en protéines » = 20 % (20 / 4 = 5 g).
///   Profil Sèche : 20 à 30 % de l'énergie, fourchette associée à une meilleure satiété
///   (5 g et 30 / 4 = 7,5 g).
/// - Fibres — allégations européennes : « source de fibres » = 1,5 g pour 100 kcal ;
///   « riche en fibres » = 3 g pour 100 kcal.
/// - Glucides — ANSES (2016) : 40 à 55 % de l'énergie (55 / 4 ≈ 14 g, seuil bas) ; OMS/FAO :
///   jusqu'à 75 % (75 / 4 ≈ 19 g, seuil haut). Sèche : 40 à 55 % (10 et 14 g). Prise de masse :
///   seuil haut à 22 g (choix de conception). Un féculent complet peut donc être « moyen ».
/// - Sucres — OMS : moins de 10 % de l'énergie (10 / 4 = 2,5 g), idéalement moins de 5 %
///   (1,25 g).
/// - Graisses saturées — EFSA / repères usuels : moins de 10 % de l'énergie
///   (10 / 9 ≈ 1,1 g). Seuil « moyen » = recommandation + 30 % (≈ 1,45 g).
/// - Sel — OMS : moins de 5 g par jour, ramené à 2000 kcal (5 / 20 = 0,25 g).
///   Seuil « moyen » = recommandation + 30 % (≈ 0,33 g).
///
/// Choix de conception (pas des recommandations officielles) : la normalisation par kcal
/// et les ajustements du profil Prise de masse (sucres plus tolérés car l'apport
/// énergétique est recherché, fibres moins exigées car elles rassasient).
enum DefaultProfiles {
    static func config(for kind: ProfileKind) -> ProfileConfig {
        switch kind {
        case .balanced: balanced
        case .cutting: cutting
        case .bulking: bulking
        case .custom: balanced // « Personnalisé » démarre en copie d'Équilibré.
        }
    }

    static let balanced = ProfileConfig(
        protein: .init(low: 3, high: 5),
        fiber: .init(low: 1.5, high: 3),
        carbohydrates: .init(low: 14, high: 19),
        sugars: .init(low: 1.25, high: 2.5),
        saturatedFat: .init(low: 1.1, high: 1.45),
        salt: .init(low: 0.25, high: 0.33)
    )

    /// Sèche : protéines plus exigées (satiété, maintien musculaire).
    static let cutting = ProfileConfig(
        protein: .init(low: 5, high: 7.5),
        fiber: .init(low: 1.5, high: 3),
        carbohydrates: .init(low: 10, high: 14),
        sugars: .init(low: 1.25, high: 2.5),
        saturatedFat: .init(low: 1.1, high: 1.45),
        salt: .init(low: 0.25, high: 0.33)
    )

    /// Prise de masse : tolérance plus large sur les sucres, fibres moins exigées.
    static let bulking = ProfileConfig(
        protein: .init(low: 3, high: 5),
        fiber: .init(low: 1.25, high: 2.5),
        carbohydrates: .init(low: 14, high: 22),
        sugars: .init(low: 2.5, high: 4.5),
        saturatedFat: .init(low: 1.1, high: 1.45),
        salt: .init(low: 0.25, high: 0.33)
    )

    /// Apports quotidiens de référence d'un adulte, pour afficher la part couverte par le produit.
    /// - Énergie 2000 kcal, protéines 50 g, glucides 260 g, sucres 90 g, graisses saturées 20 g : apports de
    ///   référence du règlement (UE) 1169/2011 (annexe XIII), ceux des « % AR » des emballages.
    ///   Les 90 g de sucres sont un repère pour les sucres totaux, pas un objectif.
    /// - Fibres 30 g : recommandation de l'ANSES (2016) pour un adulte.
    /// - Sel 5 g : recommandation de l'OMS, plus stricte que les 6 g du règlement européen ;
    ///   cohérente avec les seuils du critère sel ci-dessus.
    static let dailyIntake = DailyIntake(
        energyKcal: 2000, protein: 50, fiber: 30, carbohydrates: 260, sugars: 90, saturatedFat: 20, salt: 5
    )
}
