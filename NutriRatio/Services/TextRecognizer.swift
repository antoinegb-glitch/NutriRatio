import CoreGraphics
import Foundation
import ImageIO
import Vision

/// OCR local (framework Vision) : aucune image ne quitte l'appareil.
enum TextRecognizer {
    /// Renvoie les lignes de texte de l'image, reconstituées rangée par rangée.
    static func recognizeLines(in image: CGImage, orientation: CGImagePropertyOrientation) async throws -> [String] {
        // La reconnaissance est synchrone et coûteuse : on la sort du fil principal.
        try await Task.detached(priority: .userInitiated) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["fr-FR", "en-US"]
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: image, orientation: orientation, options: [:])
            try handler.perform([request])

            let fragments = (request.results ?? []).compactMap { observation -> OCRFragment? in
                guard let candidate = observation.topCandidates(1).first else { return nil }
                return OCRFragment(text: candidate.string, box: observation.boundingBox)
            }
            return OCRLineAssembler.lines(from: fragments)
        }.value
    }
}
