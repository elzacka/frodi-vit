import Foundation

/// Splits a document into passages of about a thousand characters.
///
/// Paragraph breaks first, then sentence ends, and a hard cut only where a text
/// has neither. Small paragraphs are merged until they fill a passage, so a list
/// of short items does not become forty passages of one line each.
///
/// A thousand characters is a couple of hundred tokens: short enough that one
/// passage is about one thing, long enough that it carries its own context.
/// With the 8 000 character budget that is seven or eight passages per question.
enum TextSplitter {
    nonisolated static let targetLength = 1_000

    /// The longest passage made. Only text with nothing to cut on reaches this.
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

    /// A paragraph longer than the cap, split at sentence ends, and at a space
    /// where a single «sentence» is itself over the cap.
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
