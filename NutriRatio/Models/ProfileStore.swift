import Foundation
import Observation

/// Profil actif et seuils de chaque profil, persistés en UserDefaults.
@Observable
final class ProfileStore {
    private struct Persisted: Codable {
        var selected: ProfileKind
        var configs: [String: ProfileConfig]
        /// Absent des données enregistrées avant l'ajout des apports quotidiens.
        var dailyIntake: DailyIntake?
    }

    private static let storageKey = "profileStore.v1"

    @ObservationIgnored private let defaults: UserDefaults

    var selected: ProfileKind {
        didSet { save() }
    }

    private var configs: [ProfileKind: ProfileConfig] {
        didSet { save() }
    }

    /// `nil` tant que l'utilisateur n'a rien modifié : les valeurs par défaut s'appliquent.
    private var customDailyIntake: DailyIntake? {
        didSet { save() }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        var selected = ProfileKind.balanced
        var configs: [ProfileKind: ProfileConfig] = [:]
        var dailyIntake: DailyIntake?
        if let data = defaults.data(forKey: Self.storageKey),
           let persisted = try? JSONDecoder().decode(Persisted.self, from: data) {
            selected = persisted.selected
            dailyIntake = persisted.dailyIntake.flatMap { $0.isValid ? $0 : nil }
            for kind in ProfileKind.allCases {
                // Une config invalide (fichier corrompu) retombe sur les valeurs par défaut.
                if let config = persisted.configs[kind.rawValue], config.isValid {
                    configs[kind] = config
                }
            }
        }
        self.selected = selected
        self.configs = configs
        self.customDailyIntake = dailyIntake
    }

    func config(for kind: ProfileKind) -> ProfileConfig {
        configs[kind] ?? DefaultProfiles.config(for: kind)
    }

    var activeConfig: ProfileConfig { config(for: selected) }

    /// Enregistre une configuration ; les configurations invalides sont refusées.
    func setConfig(_ config: ProfileConfig, for kind: ProfileKind) {
        guard config.isValid else { return }
        configs[kind] = config
    }

    func reset(_ kind: ProfileKind) {
        configs[kind] = nil
    }

    func isModified(_ kind: ProfileKind) -> Bool {
        config(for: kind) != DefaultProfiles.config(for: kind)
    }

    var dailyIntake: DailyIntake { customDailyIntake ?? DefaultProfiles.dailyIntake }

    var isDailyIntakeModified: Bool { dailyIntake != DefaultProfiles.dailyIntake }

    /// Enregistre les apports quotidiens ; des valeurs nulles ou négatives sont refusées.
    func setDailyIntake(_ intake: DailyIntake) {
        guard intake.isValid else { return }
        customDailyIntake = intake
    }

    func resetDailyIntake() {
        customDailyIntake = nil
    }

    private func save() {
        let persisted = Persisted(
            selected: selected,
            configs: Dictionary(uniqueKeysWithValues: configs.map { ($0.key.rawValue, $0.value) }),
            dailyIntake: customDailyIntake
        )
        if let data = try? JSONEncoder().encode(persisted) {
            defaults.set(data, forKey: Self.storageKey)
        }
    }
}
