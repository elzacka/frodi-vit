import Foundation

/// Deler et dokument i utdrag på rundt tusen tegn.
///
/// Avsnittsskift først, så setningsslutt, og et hardt kutt bare der en tekst
/// verken har det ene eller det andre. Små avsnitt slås sammen til de fyller
/// et utdrag, så en liste med korte punkter ikke blir førti utdrag på én linje
/// hver.
///
/// Tusen tegn er et par hundre tokens: kort nok til at ett utdrag handler om
/// én ting, langt nok til at det bærer sammenhengen sin selv. Med budsjettet
/// på 8 000 tegn blir det sju–åtte utdrag per spørsmål.
enum TextSplitter {
    nonisolated static let targetLength = 1_000

    /// Lengste utdrag som lages. Bare tekst uten noe å kutte på når hit.
    nonisolated static let maximumLength = 2 * targetLength

    nonisolated static func split(_ text: String, target: Int = targetLength) -> [String] {
        let maximum = 2 * target
        var passages: [String] = []
        var current = ""

        func flush() {
            let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { passages.append(trimmed) }
            current = ""
        }

        for paragraph in paragraphs(of: text) {
            for piece in pieces(of: paragraph, limit: maximum) {
                if !current.isEmpty, current.count + piece.count + 1 > target {
                    flush()
                }
                current += current.isEmpty ? piece : "\n" + piece
            }
        }
        flush()
        return passages
    }

    private static func paragraphs(of text: String) -> [String] {
        text.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    /// Et avsnitt som er lengre enn taket, delt ved setningsslutt, og ved et
    /// mellomrom der en «setning» alene er over taket.
    private static func pieces(of paragraph: String, limit: Int) -> [String] {
        guard paragraph.count > limit else { return [paragraph] }

        var pieces: [String] = []
        var current = ""
        for sentence in sentences(of: paragraph) {
            if !current.isEmpty, current.count + sentence.count > limit {
                pieces.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
            }
            if sentence.count > limit {
                pieces.append(contentsOf: hardCut(sentence, limit: limit))
            } else {
                current += sentence
            }
        }
        if !current.isEmpty { pieces.append(current.trimmingCharacters(in: .whitespaces)) }
        return pieces
    }

    private static func sentences(of text: String) -> [String] {
        var sentences: [String] = []
        text.enumerateSubstrings(in: text.startIndex..., options: .bySentences) { sentence, _, _, _ in
            if let sentence { sentences.append(sentence) }
        }
        return sentences.isEmpty ? [text] : sentences
    }

    private static func hardCut(_ text: String, limit: Int) -> [String] {
        var pieces: [String] = []
        var rest = Substring(text)
        while rest.count > limit {
            let window = rest.prefix(limit)
            let cut = window.lastIndex(of: " ").map { rest.index(after: $0) } ?? window.endIndex
            pieces.append(rest[..<cut].trimmingCharacters(in: .whitespaces))
            rest = rest[cut...]
        }
        let tail = rest.trimmingCharacters(in: .whitespaces)
        if !tail.isEmpty { pieces.append(tail) }
        return pieces
    }
}
