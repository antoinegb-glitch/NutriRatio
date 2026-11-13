import Foundation

/// Produit récupéré, avec les champs dont la valeur a été déduite plutôt que lue telle quelle.
struct FetchedProduct: Equatable {
    var product: Product
    var doubtful: Set<NutrientField>
}

/// Client de l'API publique Open Food Facts v2 (lecture seule, sans clé).
struct OpenFoodFactsService {
    enum ServiceError: LocalizedError, Equatable {
        case invalidBarcode
        case offline
        case productNotFound
        case server(status: Int)
        case invalidResponse

        var errorDescription: String? {
            switch self {
            case .invalidBarcode:
                String(localized: "Code-barres invalide : 8 à 14 chiffres attendus.")
            case .offline:
                String(localized: "Pas de connexion à Internet. Réessayez, ou utilisez la photo ou la saisie manuelle.")
            case .productNotFound:
                String(localized: "Produit inconnu d'Open Food Facts. Essayez la photo du tableau ou la saisie manuelle.")
            case .server(let status):
                String(localized: "Open Food Facts ne répond pas correctement (erreur \(status)). Réessayez plus tard.")
            case .invalidResponse:
                String(localized: "Réponse d'Open Food Facts illisible.")
            }
        }
    }

    /// Open Food Facts demande un User-Agent explicite identifiant l'application.
    static let userAgent = "NutriRatio/1.0 (iOS; application personnelle)"

    var session: URLSession = .shared

    static func isValidBarcode(_ code: String) -> Bool {
        (8...14).contains(code.count) && code.allSatisfy { $0.isASCII && $0.isNumber }
    }

    func fetchProduct(barcode rawBarcode: String) async throws -> FetchedProduct {
        let barcode = rawBarcode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Self.isValidBarcode(barcode),
              var components = URLComponents(string: "https://world.openfoodfacts.org/api/v2/product/\(barcode).json")
        else { throw ServiceError.invalidBarcode }
        components.queryItems = [URLQueryItem(name: "fields", value: "product_name,brands,nutriments,serving_size")]
        guard let url = components.url else { throw ServiceError.invalidBarcode }

        var request = URLRequest(url: url, timeoutInterval: 15)
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            switch error.code {
            case .notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotFindHost,
                 .cannotConnectToHost, .dnsLookupFailed, .dataNotAllowed, .internationalRoamingOff:
                throw ServiceError.offline
            default:
                throw ServiceError.invalidResponse
            }
        }

        let status = (response as? HTTPURLResponse)?.statusCode ?? 200
        // Un produit inconnu renvoie un 404 accompagné d'un JSON `status: 0`.
        if status == 404 { throw ServiceError.productNotFound }
        guard (200..<300).contains(status) else { throw ServiceError.server(status: status) }
        return try Self.decodeProduct(from: data, barcode: barcode)
    }

    /// Décodage pur (testable sans réseau).
    static func decodeProduct(from data: Data, barcode: String) throws -> FetchedProduct {
        let response: Response
        do {
            response = try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw ServiceError.invalidResponse
        }
        guard response.status != 0, let payload = response.product else {
            throw ServiceError.productNotFound
        }

        let nutriments = payload.nutriments ?? [:]
        func value(_ key: String) -> Double? {
            guard let number = nutriments[key]?.value, number >= 0 else { return nil }
            return number
        }

        var facts = NutritionFacts()
        var doubtful = Set<NutrientField>()

        if let kcal = value("energy-kcal_100g") {
            facts.energyKcal = kcal
        } else if let kj = value("energy-kj_100g") ?? value("energy_100g") {
            // `energy_100g` est toujours exprimé en kJ ; 1 kcal = 4,184 kJ.
            facts.energyKcal = kj / 4.184
            doubtful.insert(.energy)
        }
        facts.fat = value("fat_100g")
        facts.saturatedFat = value("saturated-fat_100g")
        facts.carbohydrates = value("carbohydrates_100g")
        facts.sugars = value("sugars_100g")
        facts.fiber = value("fiber_100g")
        facts.protein = value("proteins_100g")
        if let salt = value("salt_100g") {
            facts.salt = salt
        } else if let sodium = value("sodium_100g") {
            // Sel = sodium × 2,5 (convention d'étiquetage européenne).
            facts.salt = sodium * 2.5
            doubtful.insert(.salt)
        }

        let brand = payload.brands?
            .split(separator: ",").first
            .map { $0.trimmingCharacters(in: .whitespaces) }
        let product = Product(
            name: payload.productName?.trimmingCharacters(in: .whitespaces) ?? "",
            brand: brand.flatMap { $0.isEmpty ? nil : $0 },
            barcode: barcode,
            servingSize: payload.servingSize,
            facts: facts,
            source: .barcode
        )
        return FetchedProduct(product: product, doubtful: doubtful)
    }

    // MARK: Modèle de la réponse

    private struct Response: Decodable {
        let status: Int?
        let product: Payload?
    }

    private struct Payload: Decodable {
        let productName: String?
        let brands: String?
        let servingSize: String?
        let nutriments: [String: LenientNumber]?

        enum CodingKeys: String, CodingKey {
            case productName = "product_name"
            case brands
            case servingSize = "serving_size"
            case nutriments
        }
    }

    /// Les nutriments d'Open Food Facts mélangent nombres, nombres sous forme de texte
    /// ("56.3") et textes non numériques ("kJ") : tout ce qui n'est pas un nombre vaut `nil`.
    private struct LenientNumber: Decodable {
        let value: Double?

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let number = try? container.decode(Double.self) {
                value = number.isFinite ? number : nil
            } else if let text = try? container.decode(String.self) {
                value = Double(text.replacingOccurrences(of: ",", with: "."))
            } else {
                value = nil
            }
        }
    }
}
