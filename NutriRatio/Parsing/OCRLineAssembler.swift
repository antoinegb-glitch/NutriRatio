import CoreGraphics
import Foundation

/// Fragment de texte reconnu, avec son cadre normalisé (repère Vision : origine en bas à gauche).
struct OCRFragment: Equatable {
    let text: String
    let box: CGRect
}

/// Reconstitue les lignes d'un tableau à partir des fragments OCR.
///
/// Vision renvoie souvent le libellé (« Protéines ») et sa valeur (« 7,2 g ») comme deux
/// fragments séparés. On regroupe donc les fragments qui partagent la même hauteur, puis on
/// les ordonne de gauche à droite, pour obtenir « Protéines 7,2 g ».
enum OCRLineAssembler {
    static func lines(from fragments: [OCRFragment]) -> [String] {
        // Du haut vers le bas (y décroissant dans le repère Vision).
        let sorted = fragments.sorted { $0.box.midY > $1.box.midY }
        var rows: [[OCRFragment]] = []
        for fragment in sorted {
            if let anchor = rows.last?.first,
               abs(anchor.box.midY - fragment.box.midY) < 0.5 * min(anchor.box.height, fragment.box.height) {
                rows[rows.count - 1].append(fragment)
            } else {
                rows.append([fragment])
            }
        }
        return rows.map { row in
            row.sorted { $0.box.minX < $1.box.minX }.map(\.text).joined(separator: " ")
        }
    }
}
