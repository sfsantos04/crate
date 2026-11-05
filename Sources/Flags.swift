import Foundation

/// A API do slskd não devolve país da sala (só nome, usuários e flags de estado),
/// então o país vem do nome: emoji já presente ou palavra/código reconhecível.
enum CountryFlag {
    struct Match: Equatable {
        let code: String
        let name: String
        var emoji: String { CountryFlag.emoji(for: code) }
    }

    static func emoji(for code: String) -> String {
        let upper = code.uppercased()
        guard upper.count == 2 else { return "🌐" }
        var scalars = String.UnicodeScalarView()
        for scalar in upper.unicodeScalars {
            guard let value = UnicodeScalar(0x1F1E6 + (scalar.value - 65)) else { return "🌐" }
            scalars.append(value)
        }
        return String(scalars)
    }

    static func name(for code: String) -> String {
        Locale.current.localizedString(forRegionCode: code.uppercased()) ?? code.uppercased()
    }

    private static let table: [(aliases: [String], code: String)] = [
        (["brasil", "brazil", "br", "brasileira", "brasileiro"], "BR"),
        (["portugal", "portuguesa", "portugues", "português", "pt"], "PT"),
        (["argentina", "ar"], "AR"),
        (["mexico", "méxico", "mx", "mexicana"], "MX"),
        (["chile", "cl"], "CL"),
        (["colombia", "colômbia", "co"], "CO"),
        (["peru", "perú", "pe"], "PE"),
        (["uruguay", "uruguai", "uy"], "UY"),
        (["paraguay", "paraguai", "py"], "PY"),
        (["bolivia", "bolívia", "bo"], "BO"),
        (["ecuador", "equador", "ec"], "EC"),
        (["venezuela", "ve"], "VE"),
        (["españa", "espana", "spain", "espanha", "es"], "ES"),
        (["italia", "italy", "it"], "IT"),
        (["france", "frança", "franca", "fr"], "FR"),
        (["deutschland", "germany", "alemanha", "de"], "DE"),
        (["netherlands", "holanda", "nederland", "nl"], "NL"),
        (["belgium", "belgica", "bélgica", "be"], "BE"),
        (["austria", "österreich", "at"], "AT"),
        (["sweden", "suecia", "suécia", "se"], "SE"),
        (["norway", "noruega", "no"], "NO"),
        (["denmark", "dinamarca", "dk"], "DK"),
        (["finland", "finlandia", "finlândia", "fi"], "FI"),
        (["poland", "polska", "polonia", "polônia", "pl"], "PL"),
        (["russia", "россия", "ru"], "RU"),
        (["ukraine", "ucrania", "ucrânia", "ua"], "UA"),
        (["turkey", "turkiye", "türkiye", "turquia", "tr"], "TR"),
        (["greece", "grecia", "grécia", "gr"], "GR"),
        (["hungary", "hungria", "hu"], "HU"),
        (["romania", "romênia", "ro"], "RO"),
        (["bulgaria", "bulgária", "bg"], "BG"),
        (["serbia", "sérvia", "rs"], "RS"),
        (["croatia", "croácia", "hr"], "HR"),
        (["israel", "israelita", "il"], "IL"),
        (["iran", "irã", "ir"], "IR"),
        (["egypt", "egito", "eg"], "EG"),
        (["south africa", "áfrica do sul", "za"], "ZA"),
        (["nigeria", "nigéria", "ng"], "NG"),
        (["morocco", "marrocos", "ma"], "MA"),
        (["japan", "japão", "japao", "jp"], "JP"),
        (["korea", "coreia", "coréia", "kr"], "KR"),
        (["china", "chinesa", "cn"], "CN"),
        (["india", "índia", "indiana", "in"], "IN"),
        (["indonesia", "indonésia", "id"], "ID"),
        (["philippines", "filipinas", "ph"], "PH"),
        (["thailand", "tailândia", "th"], "TH"),
        (["vietnam", "việt nam", "vn"], "VN"),
        (["australia", "austrália", "au"], "AU"),
        (["new zealand", "nova zelândia", "nz"], "NZ"),
        (["canada", "canadá", "ca"], "CA"),
        (["usa", "eua", "united states", "estados unidos", "america", "us"], "US"),
        (["uk", "england", "inglaterra", "britain", "reino unido", "gb"], "GB"),
        (["ireland", "irlanda", "ie"], "IE"),
        (["czech", "tchéquia", "cz"], "CZ"),
        (["slovakia", "eslováquia", "sk"], "SK"),
    ]

    /// Bandeira explícita no nome (par de indicadores regionais).
    static func literalEmoji(in text: String) -> String? {
        let scalars = Array(text.unicodeScalars)
        for index in 0..<max(0, scalars.count - 1) {
            let first = scalars[index].value
            let second = scalars[index + 1].value
            if (0x1F1E6...0x1F1FF).contains(first), (0x1F1E6...0x1F1FF).contains(second) {
                let a = UnicodeScalar(first - 0x1F1E6 + 65)
                let b = UnicodeScalar(second - 0x1F1E6 + 65)
                if let a, let b { return String(Character(a)) + String(Character(b)) }
            }
        }
        return nil
    }

    /// Código entre colchetes/parênteses: [br], (US), |de|.
    private static func bracketedCode(in text: String) -> String? {
        let pattern = "[\\[\\(\\{|]\\s*([A-Za-z]{2})\\s*[\\]\\)\\}|]"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        for match in regex.matches(in: text, range: range) {
            if let captured = Range(match.range(at: 1), in: text) {
                return String(text[captured]).uppercased()
            }
        }
        return nil
    }

    static func detect(_ rawName: String) -> Match? {
        if let emoji = literalEmoji(in: rawName) {
            // converte o emoji de volta em código para poder exibir o nome do país
            let scalars = Array(emoji.unicodeScalars)
            if scalars.count == 2 {
                let a = Character(UnicodeScalar(scalars[0].value - 0x1F1E6 + 65) ?? "?")
                let b = Character(UnicodeScalar(scalars[1].value - 0x1F1E6 + 65) ?? "?")
                let code = String([a, b])
                return Match(code: code, name: name(for: code))
            }
        }

        let lowered = rawName.folding(options: [.diacriticInsensitive, .caseInsensitive],
                                      locale: Locale(identifier: "pt_BR"))
        if let code = bracketedCode(in: rawName), let entry = table.first(where: { $0.code == code }) {
            return Match(code: entry.code, name: name(for: entry.code))
        }

        for entry in table {
            for alias in entry.aliases {
                if lowered.contains(alias) {
                    return Match(code: entry.code, name: name(for: entry.code))
                }
            }
        }
        return nil
    }
}
