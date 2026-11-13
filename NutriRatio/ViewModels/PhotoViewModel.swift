import Foundation
import ImageIO
import Observation
import UIKit

@Observable
@MainActor
final class PhotoViewModel {
    enum State: Equatable {
        case idle
        case processing
        case failed(String)
    }

    private(set) var state: State = .idle

    func loadFailed() {
        state = .failed(String(localized: "Impossible de charger cette image."))
    }

    /// OCR puis analyse du texte. Renvoie `nil` (et un message) si rien d'exploitable n'a été lu.
    func process(_ image: UIImage) async -> VerificationInput? {
        guard let cgImage = image.cgImage else {
            loadFailed()
            return nil
        }
        state = .processing
        do {
            let lines = try await TextRecognizer.recognizeLines(
                in: cgImage,
                orientation: CGImagePropertyOrientation(image.imageOrientation)
            )
            let parsed = NutritionLabelParser.parse(lines: lines)
            guard !parsed.facts.isEmpty else {
                state = .failed(String(localized: "Aucune valeur nutritionnelle reconnue. Reprenez la photo bien à plat, nette et sans reflet, cadrée sur le tableau."))
                return nil
            }
            state = .idle
            return VerificationInput(
                product: Product(facts: parsed.facts, source: .photo),
                doubtful: parsed.doubtful,
                notice: Self.notice(for: parsed.basis)
            )
        } catch {
            state = .failed(String(localized: "La lecture de l'image a échoué. Réessayez avec une autre photo."))
            return nil
        }
    }

    private static func notice(for basis: ParsedLabel.Basis) -> String {
        switch basis {
        case .per100:
            String(localized: "Valeurs lues sur la photo : comparez chaque ligne avec l'emballage avant de valider.")
        case .perServingConverted(let grams):
            String(localized: "Tableau « par portion » de \(grams.formatted(.number.precision(.fractionLength(0...1)))) g, converti pour 100 g : vérifiez toutes les valeurs.")
        case .perServingUnknown:
            String(localized: "Tableau « par portion » sans taille de portion lisible : les valeurs ne sont PAS ramenées à 100 g. Corrigez-les à la main.")
        }
    }
}

private extension CGImagePropertyOrientation {
    /// Vision doit connaître l'orientation de la photo pour lire le texte dans le bon sens.
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .upMirrored: self = .upMirrored
        case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
