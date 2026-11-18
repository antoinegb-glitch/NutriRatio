import Foundation

struct ParsedLine: Hashable {
    /// Ligne telle que collée (sans puce ni numérotation).
    var originalText: String
    /// Nom nettoyé : sans « de », « d' » ni adjectifs de préparation.
    var name: String
    var quantity: Double?
    var unit: RecipeUnit
    var notes: [LineNote]
}

struct ParsedRecipe: Hashable {
    var title: String?
    var servings: Int?
    var lines: [ParsedLine]
}

/// Extraction locale (heuristiques, sans IA) des ingrédients d'une recette collée. Logique pure.
enum RecipeTextParser {
    private enum Heading { case ingredients, steps }

    static func parse(_ text: String) -> ParsedRecipe {
        let rawLines = text.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }
        let hasIngredientHeading = rawLines.contains { heading(of: $0) == .ingredients }
        // Sans titre « Ingrédients », on retient toute ligne qui ressemble à « quantité + ingrédient ».
        var inSection = !hasIngredientHeading
        var seenHeading = false
        var title: String?
        var lines: [ParsedLine] = []

        for line in rawLines where !line.isEmpty {
            switch heading(of: line) {
            case .ingredients:
                inSection = true
                seenHeading = true
                continue
            case .steps:
                if hasIngredientHeading { inSection = false }
                continue
            case nil:
                break
            }
            guard inSection else {
                if hasIngredientHeading, !seenHeading, title == nil, line.count <= 80,
                   parseLine(line, requireQuantity: true) == nil {
                    title = line
                }
                continue
            }
            guard let parsed = parseLine(line, requireQuantity: !hasIngredientHeading) else { continue }
            if parsed.notes.contains(.noQuantity), !looksLikeBareIngredient(parsed.originalText) { continue }
            lines.append(parsed)
        }
        return ParsedRecipe(title: title, servings: detectServings(in: text), lines: lines)
    }

    // MARK: - Titres de section

    private static func heading(of line: String) -> Heading? {
        let decoration = CharacterSet(charactersIn: "#*_-–—•:. \t0123456789)")
        let folded = TextNormalizer.fold(line).trimmingCharacters(in: decoration)
        let words = folded.split(separator: " ")
        guard let first = words.first, words.count <= 6 else { return nil }
        let word = String(first).trimmingCharacters(in: .punctuationCharacters)
        if ["ingredient", "ingredients"].contains(word) { return .ingredients }
        let steps: Set<String> = ["preparation", "preparations", "instruction", "instructions", "direction", "directions",
                                  "method", "methode", "etape", "etapes", "step", "steps", "procedure", "realisation"]
        return steps.contains(word) ? .steps : nil
    }

    /// Dans une section « Ingrédients », une ligne sans quantité (« Sel », « Poivre ») est gardée
    /// à compléter ; un sous-titre (« Pour la pâte : ») ou une phrase de préparation est ignoré.
    private static func looksLikeBareIngredient(_ text: String) -> Bool {
        let words = text.split(separator: " ")
        if words.count > 5 || text.hasSuffix(":") || text.hasSuffix(".") { return false }
        return TextNormalizer.fold(text).split(separator: " ").first.map { $0 != "pour" } ?? false
    }

    private static func detectServings(in text: String) -> Int? {
        let folded = TextNormalizer.fold(text)
        let patterns = [#"(\d{1,2})\s*(?:personnes?|pers\b|portions?|people|servings?|convives)"#,
                        #"(?:serves|makes)\s+(\d{1,2})\b"#]
        for pattern in patterns {
            guard let match = firstMatch(pattern, in: folded), let range = Range(match.range(at: 1), in: folded),
                  let value = Int(folded[range]), value > 0 else { continue }
            return value
        }
        return nil
    }

    // MARK: - Une ligne

    /// `requireQuantity` : sans quantité, la ligne est écartée (texte libre sans titre « Ingrédients »).
    static func parseLine(_ raw: String, requireQuantity: Bool) -> ParsedLine? {
        let text = stripListMarker(raw.trimmingCharacters(in: .whitespacesAndNewlines))
        guard !text.isEmpty else { return nil }

        let tokens = prepare(text).split(whereSeparator: \.isWhitespace).map(String.init)
        guard !tokens.isEmpty else { return nil }
        let forms = tokens.map(matchForm)

        var index = 0
        while index < tokens.count, approximations.contains(forms[index]) { index += 1 }
        let start = index

        var quantity: Double?
        var notes: [LineNote] = []
        var unit = RecipeUnit.piece

        if let length = vagueLength(forms, at: index) {
            notes.append(.vagueQuantity)
            index += length
        } else if let parsed = parseQuantity(tokens, forms, at: index) {
            quantity = parsed.value
            if parsed.isRange { notes.append(.rangeAveraged) }
            index += parsed.length
            if let match = matchUnit(forms, at: index) {
                unit = match.unit
                index += match.length
            }
        } else if ["a", "an"].contains(forms[index]), let match = matchUnit(forms, at: index + 1) {
            quantity = 1
            unit = match.unit
            index += 1 + match.length
        } else {
            if requireQuantity { return nil }
            notes.append(.noQuantity)
            index = start
        }

        if quantity != nil, index < forms.count, notQuantities.contains(forms[index]) { return nil }

        let displayName = joined(tokens[index...])
        return ParsedLine(originalText: text, name: cleanName(displayName), quantity: quantity, unit: unit, notes: notes)
    }

    /// Retire puces (-, •, *, ✓…) et numérotation (« 1. », « 2) »).
    private static func stripListMarker(_ text: String) -> String {
        var result = text
        let bullets = CharacterSet(charactersIn: "-–—•·*▪◦‣✓☐□●○>[]").union(.whitespaces)
        while let first = result.unicodeScalars.first, bullets.contains(first) {
            result.removeFirst()
        }
        if let match = firstMatch(#"^\d{1,2}[.)]\s+"#, in: result), let range = Range(match.range, in: result) {
            result.removeSubrange(range)
        }
        return result.trimmingCharacters(in: .whitespaces)
    }

    private static let unicodeFractions = ["½": "1/2", "¼": "1/4", "¾": "3/4", "⅓": "1/3", "⅔": "2/3", "⅛": "1/8"]

    /// Sépare ce qui doit l'être pour découper en mots : « 1½ » → « 1 1/2 », « 200g » → « 200 g »,
    /// « 2-3 » → « 2 - 3 », « d'ail » → « d' ail ».
    private static func prepare(_ text: String) -> String {
        var result = text
        for (symbol, fraction) in unicodeFractions {
            result = result.replacingOccurrences(of: symbol, with: " \(fraction) ")
        }
        result = result.replacingOccurrences(of: "’", with: "'")
        result = replace(#"(\d)([A-Za-zÀ-ÖØ-öø-ÿŒœ])"#, in: result, with: "$1 $2")
        result = replace(#"(\d)\s*[-–—]\s*(\d)"#, in: result, with: "$1 - $2")
        return result.replacingOccurrences(of: "'", with: "' ")
    }

    /// Forme de comparaison : sans accents, ni points, ni ponctuation de bord (« c.à.s. » → « cas »).
    private static func matchForm(_ token: String) -> String {
        let folded = TextNormalizer.fold(token).replacingOccurrences(of: ".", with: "")
        let trimmed = folded.trimmingCharacters(in: CharacterSet(charactersIn: ",;:()[]"))
        return trimmed.isEmpty ? folded : trimmed
    }

    private static func joined(_ tokens: ArraySlice<String>) -> String {
        var result = ""
        for token in tokens {
            if !result.isEmpty, !result.hasSuffix("'") { result += " " }
            result += token
        }
        return result
    }

    // MARK: - Quantités

    private static let wordNumbers: [String: Double] = [
        "un": 1, "une": 1, "one": 1, "deux": 2, "two": 2, "trois": 3, "three": 3, "quatre": 4, "four": 4,
        "cinq": 5, "five": 5, "six": 6, "sept": 7, "huit": 8, "neuf": 9, "dix": 10, "douze": 12,
        "demi": 0.5, "demie": 0.5, "half": 0.5,
    ]
    private static let rangeConnectors: Set<String> = ["-", "a", "to", "ou", "or"]
    private static let approximations: Set<String> = ["environ", "env", "about", "approx", "approximately", "~"]
    /// Après un nombre, ces mots indiquent une durée, une température ou un nombre de convives, pas un ingrédient.
    private static let notQuantities: Set<String> = [
        "min", "mn", "minute", "minutes", "h", "heure", "heures", "sec", "seconde", "secondes", "degre", "degres",
        "personne", "personnes", "pers", "portion", "portions", "people", "servings", "serving", "fois", "cm", "mm",
    ]

    private static func parseQuantity(_ tokens: [String], _ forms: [String], at index: Int) -> (value: Double, length: Int, isRange: Bool)? {
        guard let first = number(tokens, forms, at: index) else { return nil }
        var value = first.value
        var length = first.length
        var isRange = false
        let next = index + length
        if next + 1 < tokens.count, rangeConnectors.contains(forms[next]),
           let second = number(tokens, forms, at: next + 1) {
            value = (value + second.value) / 2
            length += 1 + second.length
            isRange = true
        }
        return (value, length, isRange)
    }

    /// Nombre entier, décimal (virgule ou point), fraction, nombre mixte (« 1 1/2 ») ou en lettres.
    private static func number(_ tokens: [String], _ forms: [String], at index: Int) -> (value: Double, length: Int)? {
        guard index < tokens.count else { return nil }
        let token = tokens[index]
        if let value = numeric(token) {
            if token.allSatisfy(\.isNumber), index + 1 < tokens.count, let fraction = fraction(tokens[index + 1]) {
                return (value + fraction, 2)
            }
            return (value, 1)
        }
        if let value = fraction(token) { return (value, 1) }
        if let value = wordNumbers[forms[index]] { return (value, 1) }
        return nil
    }

    private static func numeric(_ token: String) -> Double? {
        guard token.first?.isNumber == true, token.allSatisfy({ $0.isNumber || $0 == "." || $0 == "," }) else { return nil }
        return Double(token.replacingOccurrences(of: ",", with: "."))
    }

    private static func fraction(_ token: String) -> Double? {
        let parts = token.split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count == 2, let numerator = Double(parts[0]), let denominator = Double(parts[1]), denominator != 0 else { return nil }
        return numerator / denominator
    }

    /// « un peu de », « quelques », « a pinch of »… : quantité à compléter.
    private static func vagueLength(_ forms: [String], at index: Int) -> Int? {
        let phrases: [[String]] = [["un", "peu"], ["quelques"], ["a", "few"], ["a", "little"], ["a", "bit"], ["some"],
                                   ["une", "poignee"], ["un", "filet"], ["une", "goutte"], ["quelques"]]
        for phrase in phrases where index + phrase.count <= forms.count && Array(forms[index..<index + phrase.count]) == phrase {
            return phrase.count
        }
        return nil
    }

    // MARK: - Unités

    private static let unitAliases: [(tokens: [String], unit: RecipeUnit)] = {
        var table: [(tokens: [String], unit: RecipeUnit)] = []
        func add(_ unit: RecipeUnit, _ aliases: [String]...) {
            for alias in aliases { table.append((alias, unit)) }
        }
        add(.gram, ["g"], ["gr"], ["gramme"], ["grammes"], ["gram"], ["grams"])
        add(.kilogram, ["kg"], ["kilo"], ["kilos"], ["kilogramme"], ["kilogrammes"])
        add(.milligram, ["mg"])
        add(.milliliter, ["ml"], ["millilitre"], ["millilitres"])
        add(.centiliter, ["cl"], ["centilitre"], ["centilitres"])
        add(.deciliter, ["dl"], ["decilitre"], ["decilitres"])
        add(.liter, ["l"], ["litre"], ["litres"], ["liter"], ["liters"])
        add(.tablespoon, ["c", "a", "soupe"], ["c", "a", "s"], ["cuillere", "a", "soupe"], ["cuilleres", "a", "soupe"],
            ["cuilleree", "a", "soupe"], ["cuillerees", "a", "soupe"], ["cas"], ["cs"], ["tbsp"], ["tbs"],
            ["tablespoon"], ["tablespoons"])
        add(.teaspoon, ["c", "a", "cafe"], ["c", "a", "c"], ["cuillere", "a", "cafe"], ["cuilleres", "a", "cafe"],
            ["cuilleree", "a", "cafe"], ["cuillerees", "a", "cafe"], ["cac"], ["cc"], ["tsp"], ["teaspoon"], ["teaspoons"])
        add(.glass, ["verre"], ["verres"], ["glass"], ["glasses"])
        add(.cup, ["tasse"], ["tasses"], ["cup"], ["cups"])
        add(.pinch, ["pincee"], ["pincees"], ["pinch"], ["pinches"])
        add(.knob, ["noix", "de"], ["noix", "d'"])
        add(.ounce, ["oz"], ["ounce"], ["ounces"])
        add(.pound, ["lb"], ["lbs"], ["pound"], ["pounds"])
        return table.sorted { $0.tokens.count > $1.tokens.count }
    }()

    /// « 2 noix de coco » est un ingrédient, pas une noix de beurre.
    private static let notKnob: Set<String> = ["coco", "cajou", "pecan", "muscade", "macadamia", "grenoble", "saint", "cola"]

    private static func matchUnit(_ forms: [String], at index: Int) -> (unit: RecipeUnit, length: Int)? {
        guard index < forms.count else { return nil }
        for alias in unitAliases where index + alias.tokens.count <= forms.count
            && Array(forms[index..<index + alias.tokens.count]) == alias.tokens {
            if alias.unit == .knob {
                let next = index + alias.tokens.count
                guard next < forms.count, !notKnob.contains(forms[next]) else { continue }
            }
            return (alias.unit, alias.tokens.count)
        }
        return nil
    }

    // MARK: - Nom

    private static let preparationWords: Set<String> = [
        "hache", "hachee", "haches", "hachees", "emince", "emincee", "eminces", "emincees", "cisele", "ciselee",
        "ciseles", "ciselees", "rape", "rapee", "rapes", "rapees", "pele", "pelee", "peles", "pelees", "fondu",
        "fondue", "fondus", "fondues", "tranche", "tranchee", "tranches", "tranchees", "ecrase", "ecrasee",
        "ecrases", "ecrasees", "lave", "lavee", "laves", "lavees", "epluche", "epluchee", "epluches", "epluchees",
        "finement", "grossierement", "tamise", "tamisee", "ramolli", "ramollie", "decongele", "decongelee",
        "chopped", "minced", "diced", "sliced", "grated", "melted", "peeled", "crushed", "finely", "roughly",
        "sifted", "softened",
    ]
    private static let cutWords: Set<String> = ["coupe", "coupee", "coupes", "coupees", "taille", "tailles", "cut"]
    private static let leadingArticles: Set<String> = ["de", "d'", "du", "des", "la", "le", "les", "l'", "of", "the"]

    /// Retire parenthèses, mentions après virgule, adjectifs de préparation (« haché », « râpé »…)
    /// et articles de tête. Le texte d'origine reste conservé par ailleurs.
    static func cleanName(_ display: String) -> String {
        var text = replace(#"\([^)]*\)"#, in: display, with: "")
        if let comma = text.firstIndex(of: ",") { text = String(text[..<comma]) }

        let tokens = text.replacingOccurrences(of: "'", with: "' ").split(whereSeparator: \.isWhitespace).map(String.init)
        var kept: [String] = []
        var index = 0
        while index < tokens.count {
            let form = matchForm(tokens[index])
            if cutWords.contains(form) {
                // « coupé en dés », « cut into cubes » : on retire aussi ce qui suit.
                index += 1
                if index < tokens.count, ["en", "into"].contains(matchForm(tokens[index])) { index += 2 }
                continue
            }
            if !preparationWords.contains(form) { kept.append(tokens[index]) }
            index += 1
        }
        while let first = kept.first, leadingArticles.contains(matchForm(first)) { kept.removeFirst() }
        let cleaned = joined(kept[...]).trimmingCharacters(in: .whitespaces)
        return cleaned.isEmpty ? display.trimmingCharacters(in: .whitespaces) : cleaned
    }

    // MARK: - Expressions régulières

    private static func firstMatch(_ pattern: String, in text: String) -> NSTextCheckingResult? {
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return nil }
        return expression.firstMatch(in: text, range: NSRange(text.startIndex..., in: text))
    }

    private static func replace(_ pattern: String, in text: String, with template: String) -> String {
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return text }
        return expression.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: template)
    }
}
