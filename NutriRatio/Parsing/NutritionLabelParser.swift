import Foundation

/// Résultat de la lecture d'un tableau nutritionnel. Les valeurs sont ramenées à 100 g/ml.
struct ParsedLabel: Equatable {
    enum Basis: Equatable {
        /// Colonne « pour 100 g / 100 ml » trouvée (ou supposée, faute d'indication contraire).
        case per100
        /// Seule une colonne « par portion » existait ; valeurs converties avec cette portion.
        case perServingConverted(grams: Double)
        /// Colonne « par portion » sans taille de portion lisible : valeurs NON converties.
        case perServingUnknown
    }

    var facts = NutritionFacts()
    var basis: Basis = .per100
    /// Champs lus mais incertains (« < 0,5 », valeur déduite, incohérence…).
    var doubtful: Set<NutrientField> = []
}

/// Parseur du texte OCR d'un tableau nutritionnel français ou anglais. Logique pure.
///
/// Méthode : chaque ligne est normalisée (minuscules, sans accents, virgule → point), puis on
/// y cherche des mots-clés de nutriments. Les nombres situés entre un mot-clé et le suivant
/// sont les valeurs de ce nutriment, une par colonne du tableau.
enum NutritionLabelParser {
    static func parse(_ text: String) -> ParsedLabel {
        parse(lines: text.components(separatedBy: .newlines))
    }

    static func parse(lines rawLines: [String]) -> ParsedLabel {
        let lines = rawLines.map(normalize).filter { !$0.isEmpty }
        let layout = detectLayout(lines)

        var facts = NutritionFacts()
        var doubtful = Set<NutrientField>()
        var kcal: Double?
        var kilojoules: Double?
        var sodium: Double?

        func readEnergy(_ tokens: [Token], plainNumbersAreKcal: Bool = false) {
            var kcalTokens = tokens.filter { $0.unit == "kcal" }
            if kcalTokens.isEmpty, plainNumbersAreKcal, !tokens.contains(where: { $0.unit == "kj" }) {
                kcalTokens = tokens.filter { $0.unit == nil }
            }
            // Bornes physiques : la graisse pure fait 900 kcal (3766 kJ) pour 100 g. Au-delà,
            // c'est autre chose, typiquement « 8400 kJ / 2000 kcal » des apports de référence.
            if kcal == nil, let picked = pick(kcalTokens, layout), picked.token.value <= 900 {
                kcal = picked.token.value
                if picked.shaky { doubtful.insert(.energy) }
            }
            if kilojoules == nil, let picked = pick(tokens.filter { $0.unit == "kj" }, layout), picked.token.value <= 3800 {
                kilojoules = picked.token.value
            }
        }

        for (index, line) in lines.enumerated() {
            let hits = keywordHits(in: line)
            if hits.isEmpty {
                // Ligne sans libellé : seule l'énergie peut s'y poursuivre (« 357 kcal »).
                readEnergy(tokens(in: line[...]))
                continue
            }
            for (position, hit) in hits.enumerated() {
                let isLast = position == hits.count - 1
                let end = isLast ? line.endIndex : hits[position + 1].range.lowerBound
                var found = tokens(in: line[hit.range.upperBound..<end], maxGap: maxGapAfterKeyword)
                // Libellé seul sur sa ligne : la valeur est parfois sur la ligne suivante.
                if found.isEmpty, isLast, index + 1 < lines.count {
                    let next = lines[index + 1]
                    if keywordHits(in: next).isEmpty, next.first.map({ $0.isNumber || $0 == "<" }) == true {
                        found = tokens(in: next[...])
                    }
                }

                switch hit.key {
                case .energy:
                    readEnergy(found, plainNumbersAreKcal: hit.text.contains("calorie"))
                case .nutrient(let field):
                    // La première occurrence gagne : « Sucres » avant « dont sucres ajoutés ».
                    guard facts[field] == nil, let picked = pick(massTokens(found), layout) else { continue }
                    facts[field] = picked.token.grams
                    if picked.shaky || picked.token.lessThan { doubtful.insert(field) }
                case .sodium:
                    guard sodium == nil, let picked = pick(massTokens(found), layout) else { continue }
                    sodium = picked.token.grams
                }
            }
        }

        if let kcal {
            facts.energyKcal = kcal
        } else if let kilojoules {
            facts.energyKcal = kilojoules / 4.184 // 1 kcal = 4,184 kJ
        }
        if facts.salt == nil, let sodium {
            facts.salt = sodium * 2.5 // sel = sodium × 2,5
            doubtful.insert(.salt)
        }

        let present = Set(NutrientField.allCases.filter { facts[$0] != nil })
        switch layout.basis {
        case .per100:
            break
        case .perServingConverted(let grams):
            // Conversion portion → 100 g : à faire confirmer, la portion lue peut être fausse.
            for field in present {
                facts[field] = facts[field].map { $0 * 100 / grams }
            }
            doubtful.formUnion(present)
        case .perServingUnknown:
            doubtful.formUnion(present)
        }

        for warning in facts.consistencyWarnings {
            doubtful.formUnion(warning.fields.filter { present.contains($0) })
        }
        for field in present where field != .energy {
            if let value = facts[field], value > 100 { doubtful.insert(field) }
        }

        return ParsedLabel(facts: facts, basis: layout.basis, doubtful: doubtful)
    }

    // MARK: Normalisation

    static func normalize(_ raw: String) -> String {
        var text = raw
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr_FR"))
            .lowercased()
        text = text.replacing("1oo", with: "100") // « 1OO g », confusion OCR classique
        text = text.replacing(#/(\d),(\d)/#) { "\($0.1).\($0.2)" } // virgule décimale
        text = text.replacing(#/(\d) (\d{3})\s*kj/#) { "\($0.1)\($0.2) kj" } // « 1 590 kJ »
        text = text.replacing(#/\([^)]*sodium[^)]*\)/#, with: " ") // « Sel (sodium x 2,5) »
        text = text.replacing(#/\btraces?\b/#, with: "0 g")
        return text.trimmingCharacters(in: .whitespaces)
    }

    // MARK: Mots-clés

    private enum Key {
        case energy
        case nutrient(NutrientField)
        case sodium
    }

    private struct Hit {
        let key: Key
        let range: Range<String.Index>
        let text: Substring
    }

    /// Au-delà de cette distance entre un mot-clé et un nombre, le nombre n'est sans doute
    /// pas sa valeur (ex. « sel » dans une liste d'ingrédients suivie de « pour 100 g »).
    private static let maxGapAfterKeyword = 30

    /// L'ordre compte : les libellés les plus spécifiques d'abord, pour que « saturated fat »
    /// ne soit pas lu comme « fat », ni « dont sucres » comme « glucides ».
    private static let keywordPatterns: [(Key, Regex<Substring>)] = [
        (.nutrient(.saturatedFat), #/\bsatur\w*(?:\s+fat\b)?/#),
        (.nutrient(.fat), #/\bmatieres?\s+grasses?\b|\blipides?\b|\bgraisses?\b|\b(?:total\s+)?fat\b/#),
        (.nutrient(.sugars), #/\bsucres?\b|\bsugars?\b/#),
        (.nutrient(.carbohydrates), #/\bglucides?\b|\b(?:total\s+)?carbohydrates?\b|\bcarbs\b/#),
        (.nutrient(.fiber), #/\bfib(?:re|er)s?(?:\s+alimentaires)?\b/#),
        (.nutrient(.protein), #/\bprotein\w*/#),
        (.nutrient(.salt), #/\bsel\b|\bsalt\b/#),
        (.sodium, #/\bsodium\b/#),
        (.energy, #/\bvaleurs?\s+energetiques?\b|\benergie\b|\benergy\b|\bcalories\b/#),
    ]

    private static func keywordHits(in line: String) -> [Hit] {
        var hits: [Hit] = []
        for (key, pattern) in keywordPatterns {
            for match in line.matches(of: pattern) where !hits.contains(where: { $0.range.overlaps(match.range) }) {
                hits.append(Hit(key: key, range: match.range, text: match.output))
            }
        }
        return hits.sorted { $0.range.lowerBound < $1.range.lowerBound }
    }

    // MARK: Nombres

    private struct Token {
        let value: Double
        let unit: Substring?
        /// Valeur précédée de « < » : on garde la borne (prudente) et on la signale.
        let lessThan: Bool

        var grams: Double { unit == "mg" ? value / 1000 : value }
    }

    private static let numberPattern = #/(<\s*)?(\d+(?:\.\d+)?)\s*(kcal|kj|mg|ml|g|%)?(?![a-z])/#

    private static func tokens(in segment: Substring, maxGap: Int? = nil) -> [Token] {
        var result: [Token] = []
        for match in segment.matches(of: numberPattern) {
            if result.isEmpty, let maxGap,
               segment.distance(from: segment.startIndex, to: match.range.lowerBound) > maxGap {
                return []
            }
            guard let value = Double(match.output.2) else { continue }
            result.append(Token(value: value, unit: match.output.3, lessThan: match.output.1 != nil))
        }
        return result
    }

    /// Valeurs massiques uniquement : on écarte les pourcentages d'apports de référence, etc.
    private static func massTokens(_ tokens: [Token]) -> [Token] {
        tokens.filter { $0.unit == nil || $0.unit == "g" || $0.unit == "mg" }
    }

    // MARK: Colonnes

    private struct Layout {
        /// Rang de la colonne « pour 100 g » parmi les colonnes de valeurs.
        var per100Index = 0
        var basis: ParsedLabel.Basis = .per100
    }

    private static let per100Pattern = #/\b100\s*(?:g|ml)\b/#
    private static let servingPattern = #/\b(?:portion|serving|biscuit|tranche|barre)s?\b|\b(?:par|per|pour)\s+\d+(?:\.\d+)?\s*(?:g|ml)\b/#

    private static func detectLayout(_ lines: [String]) -> Layout {
        var layout = Layout()
        var hasPer100 = false
        var hasServing = false
        var servingGrams: Double?
        var orderDecided = false

        for line in lines {
            let per100 = line.firstMatch(of: per100Pattern)
            // On masque « 100 g » pour que « pour 100 g » ne passe pas pour une portion.
            let masked = line.replacing(per100Pattern) { String(repeating: " ", count: $0.output.count) }
            let serving = masked.firstMatch(of: servingPattern)

            if per100 != nil { hasPer100 = true }
            if let serving {
                hasServing = true
                if servingGrams == nil {
                    servingGrams = tokens(in: masked[...])
                        .first { ($0.unit == "g" || $0.unit == "ml") && $0.value > 0 }?.value
                }
                // Les deux en-têtes sur la même ligne : leur ordre donne celui des colonnes.
                if let per100, !orderDecided {
                    let per100Offset = line.distance(from: line.startIndex, to: per100.range.lowerBound)
                    let servingOffset = masked.distance(from: masked.startIndex, to: serving.range.lowerBound)
                    layout.per100Index = per100Offset < servingOffset ? 0 : 1
                    orderDecided = true
                }
            }
        }

        if hasServing, !hasPer100 {
            layout.basis = servingGrams.map { .perServingConverted(grams: $0) } ?? .perServingUnknown
        }
        return layout
    }

    /// Choisit la valeur de la colonne « pour 100 g ». `shaky` : la colonne attendue manquait
    /// sur cette ligne, la valeur retenue vient peut-être de la colonne « par portion ».
    private static func pick(_ tokens: [Token], _ layout: Layout) -> (token: Token, shaky: Bool)? {
        guard let first = tokens.first else { return nil }
        if layout.per100Index < tokens.count { return (tokens[layout.per100Index], false) }
        return (first, true)
    }
}
