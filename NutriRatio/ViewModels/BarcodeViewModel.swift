import AVFoundation
import Foundation
import Observation
import VisionKit

@Observable
@MainActor
final class BarcodeViewModel {
    enum CameraState {
        case checking, available, denied, unsupported
    }

    enum LookupState: Equatable {
        case idle
        case loading(code: String)
        case failed(code: String, message: String)
    }

    private(set) var camera: CameraState = .checking
    private(set) var lookup: LookupState = .idle
    private let service = OpenFoodFactsService()

    /// Demande l'accès à l'appareil photo avant de créer le scanner.
    func prepareCamera() async {
        guard DataScannerViewController.isSupported else {
            camera = .unsupported
            return
        }
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        camera = granted && DataScannerViewController.isAvailable ? .available : .denied
    }

    /// Appelé à chaque code vu par la caméra : ignore les doublons pendant ou après une recherche.
    func scanned(_ code: String) async -> VerificationInput? {
        switch lookup {
        case .loading: return nil
        case .failed(let failedCode, _) where failedCode == code: return nil
        default: return await fetch(code)
        }
    }

    func fetch(_ code: String) async -> VerificationInput? {
        if case .loading = lookup { return nil }
        lookup = .loading(code: code)
        do {
            let fetched = try await service.fetchProduct(barcode: code)
            lookup = .idle
            return VerificationInput(product: fetched.product, doubtful: fetched.doubtful, notice: Self.notice(for: fetched))
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? String(localized: "Erreur inattendue.")
            lookup = .failed(code: code, message: message)
            return nil
        }
    }

    private static func notice(for fetched: FetchedProduct) -> String {
        let facts = fetched.product.facts
        if facts.isEmpty {
            return String(localized: "Open Food Facts connaît ce produit mais n'a aucune valeur nutritionnelle : saisissez-les depuis l'emballage.")
        }
        let incomplete = NutrientField.allCases.contains { $0.isUsedForScoring && facts[$0] == nil }
        if incomplete || !fetched.doubtful.isEmpty {
            return String(localized: "Données Open Food Facts incomplètes : complétez ou vérifiez les champs surlignés.")
        }
        return String(localized: "Données Open Food Facts (collaboratives) : comparez avec l'emballage avant de valider.")
    }
}
