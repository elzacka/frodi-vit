import Foundation
import Testing
@testable import FrodiVit

@Suite("Oppdeling")
struct TextSplitterTests {
    @Test("En kort tekst blir ett utdrag")
    func shortTextIsOnePassage() {
        #expect(TextSplitter.split("Fristen er 1. oktober.") == ["Fristen er 1. oktober."])
    }

    @Test("Tom tekst gir ingen utdrag")
    func emptyTextGivesNothing() {
        #expect(TextSplitter.split("  \n\n ").isEmpty)
    }

    /// En liste med korte punkter skal ikke bli ett utdrag per linje.
    @Test("Små avsnitt slås sammen til de fyller et utdrag")
    func smallParagraphsAreMerged() {
        let text = (1 ... 20).map { "Punkt \($0) i listen." }.joined(separator: "\n\n")
        let passages = TextSplitter.split(text, target: 100)
        #expect(passages.count > 1)
        #expect(passages.count < 20)
        #expect(passages.allSatisfy { $0.count <= 100 })
        #expect(passages.joined(separator: "\n") == text.replacingOccurrences(of: "\n\n", with: "\n"))
    }

    @Test("Et avsnitt over taket deles ved setningsslutt")
    func longParagraphSplitsAtSentences() {
        let sentence = "Dette er en setning som handler om noe. "
        let text = String(repeating: sentence, count: 30)
        let passages = TextSplitter.split(text, target: 200)
        #expect(passages.count > 1)
        #expect(passages.allSatisfy { $0.count <= 400 })
        #expect(passages.allSatisfy { $0.hasSuffix("noe.") })
    }

    /// Tekst uten punktum og uten avsnitt — en tabell limt inn som én linje.
    @Test("Tekst uten noe å kutte på deles ved mellomrom")
    func textWithoutBoundariesIsHardCut() {
        let text = (1 ... 300).map { "ord\($0)" }.joined(separator: " ")
        let passages = TextSplitter.split(text, target: 100)
        #expect(passages.allSatisfy { $0.count <= 200 })
        #expect(passages.allSatisfy { !$0.hasPrefix(" ") && !$0.hasSuffix(" ") })
        #expect(passages.joined(separator: " ") == text)
    }

    @Test("Ingenting går over taket")
    func nothingExceedsMaximum() {
        let text = String(repeating: "x", count: 5 * TextSplitter.maximumLength)
        #expect(TextSplitter.split(text).allSatisfy { $0.count <= TextSplitter.maximumLength })
    }
}

@Suite("Utvalg")
struct RetrievalTests {
    private func candidate(_ x: Float, _ y: Float, length: Int = 100) -> Retrieval.Candidate {
        Retrieval.Candidate(vector: [x, y], length: length)
    }

    @Test("Cosinus mellom normaliserte vektorer er prikkproduktet")
    func cosineIsDotProduct() {
        #expect(Retrieval.cosine([1, 0], [1, 0]) == 1)
        #expect(Retrieval.cosine([1, 0], [0, 1]) == 0)
        #expect(abs(Retrieval.cosine([0.6, 0.8], [0.8, 0.6]) - 0.96) < 0.0001)
    }

    @Test("De som ligner mest velges først")
    func bestMatchesAreChosen() {
        let candidates = [candidate(0, 1), candidate(1, 0), candidate(0.9, 0.1)]
        #expect(Retrieval.select(query: [1, 0], from: candidates, budget: 200) == [1, 2])
    }

    /// Modellen skal lese dokumentet i rekkefølge, ikke stokket etter poeng.
    @Test("Utvalget kommer i dokumentrekkefølge")
    func chosenAreInOriginalOrder() {
        let candidates = [candidate(0.9, 0.1), candidate(0, 1), candidate(1, 0)]
        #expect(Retrieval.select(query: [1, 0], from: candidates, budget: 200) == [0, 2])
    }

    @Test("Et utdrag som ikke får plass hoppes over til fordel for et kortere")
    func oversizedCandidateIsSkipped() {
        let candidates = [candidate(1, 0, length: 150), candidate(0.9, 0.1, length: 60), candidate(0.8, 0.2, length: 60)]
        #expect(Retrieval.select(query: [1, 0], from: candidates, budget: 100) == [1])
    }

    @Test("Ingen kandidater gir ingen utvalg")
    func nothingIn() {
        #expect(Retrieval.select(query: [1, 0], from: [], budget: 100).isEmpty)
    }
}

@Suite("Utdrag")
struct PassageTests {
    @Test("Vektoren kommer uendret tilbake")
    func vectorRoundTrips() throws {
        let passage = try Passage(index: 3, text: "Fristen er 1. oktober.", vector: [0.25, -1, 0.5])
        #expect(passage.floats == [0.25, -1, 0.5])
        #expect(passage.index == 3)
        #expect(passage.characterCount == 22)
    }

    @Test("Teksten ligger ikke i klartekst")
    func textIsSealed() throws {
        let secret = "kontonummeret står her"
        let passage = try Passage(index: 0, text: secret, vector: [1])
        #expect(passage.sealedText.range(of: Data(secret.utf8)) == nil)
        #expect(try passage.text() == secret)
    }
}

@Suite("Kildelinjen")
struct SourceListTests {
    @Test("Ett, to og tre navn", arguments: [
        (["a.pdf"], "«a.pdf»"),
        (["a.pdf", "b.txt"], "«a.pdf» og «b.txt»"),
        (["a.pdf", "b.txt", "c.md"], "«a.pdf», «b.txt» og «c.md»"),
    ])
    func names(input: [String], expected: String) {
        #expect(MessageBubble.list(input) == expected)
    }
}
