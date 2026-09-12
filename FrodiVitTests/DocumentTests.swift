import Foundation
import Testing
@testable import FrodiVit

@Suite("Dokument")
struct DocumentTests {
    @Test("Teksten kommer uendret tilbake")
    func textRoundTrips() throws {
        let document = try Document(name: "notat.txt", text: "Fristen er 1. oktober.")
        #expect(try document.text() == "Fristen er 1. oktober.")
    }

    /// An uploaded document is often the most revealing thing in the app.
    @Test("Teksten ligger ikke i klartekst")
    func textIsSealed() throws {
        let secret = "kontonummeret står her"
        let document = try Document(name: "brev.pdf", text: secret)
        #expect(document.sealedText.range(of: Data(secret.utf8)) == nil)
    }

    /// The number is stored at import, so the list does not have to unlock the
    /// text just to show how large the document is.
    @Test("Antall tegn lagres i klartekst")
    func characterCountIsStored() throws {
        #expect(try Document(name: "a.txt", text: "abcde").characterCount == 5)
    }

}

/// The budget is shared between the documents, so how much of one fits
/// depends on what else has been uploaded.
@Suite("Tegnbudsjett")
struct AllowanceTests {
    @Test("Ett kort dokument får alt det trenger")
    func shortDocumentFitsWhole() {
        #expect(BorealisAssistant.allowances(for: [400]) == [400])
    }

    @Test("Ett for langt dokument avkortes til budsjettet")
    func longDocumentIsCutToBudget() {
        let budget = BorealisAssistant.contextCharacterLimit
        #expect(BorealisAssistant.allowances(for: [budget + 1]) == [budget])
    }

    /// Without this, three uploads would send three times the budget into the
    /// prompt and blow the context window.
    @Test("Flere dokumenter deler på budsjettet")
    func budgetIsSharedAcrossDocuments() {
        let budget = BorealisAssistant.contextCharacterLimit
        let shares = BorealisAssistant.allowances(for: [budget, budget, budget])
        #expect(shares.reduce(0, +) <= budget)
    }

    /// Shortest first, so a short note does not claim half the budget without
    /// using it.
    @Test("Et kort notat tar ikke plass fra en lang rapport")
    func shortDocumentDoesNotStarveTheLongOne() {
        let shares = BorealisAssistant.allowances(for: [10_000, 100], within: 12_000)
        #expect(shares == [10_000, 100])
    }

    @Test("Er alt for langt, deles budsjettet likt")
    func equalSplitWhenEverythingIsTooLong() {
        #expect(BorealisAssistant.allowances(for: [9_000, 9_000], within: 10_000) == [5_000, 5_000])
    }

    /// NSM's guide to risk management is 18 pages and 41 191 characters as
    /// extracted by PDFKit. It must be truncated, not go in whole.
    ///
    /// This test claimed the opposite from 8 September, when the limit was set to
    /// 48 000 from the context window. Measured on iPhone 17 Pro on 11 September,
    /// the same guide killed the app before the first word, every time. See
    /// `contextCharacterLimit` for the numbers.
    @Test("En veileder på atten sider avkortes")
    func aRealGuideIsCut() {
        let budget = BorealisAssistant.contextCharacterLimit
        #expect(BorealisAssistant.allowances(for: [41_191]) == [budget])
        #expect(budget < 41_191)
    }

    /// The limit is measured, not reasoned. Do not raise it without measuring on
    /// a device again with `ContextProbe`: 16 000 characters killed the app.
    @Test("Budsjettet holder seg under det målte taket")
    func budgetStaysUnderTheMeasuredCeiling() {
        #expect(BorealisAssistant.contextCharacterLimit <= 12_000)
    }

    @Test("Ingen dokumenter gir ingen andeler")
    func noDocuments() {
        #expect(BorealisAssistant.allowances(for: []).isEmpty)
    }
}

@Suite("Ledetekst")
struct PromptTests {
    /// Without documents the question must stand exactly as you wrote it.
    @Test("Uten dokumenter er ledeteksten bare spørsmålet")
    func questionOnly() {
        #expect(BorealisAssistant.prompt(for: "Hva er klokka?", given: []) == "Hva er klokka?")
    }

    /// Empty documents must not give a prompt with an empty paragraph in it.
    @Test("Tomme dokumenter teller ikke")
    func emptyDocumentsAreIgnored() {
        #expect(BorealisAssistant.prompt(for: "Hva står det?", given: ["", ""]) == "Hva står det?")
    }

    /// The model answers the last thing said. With the question first it tends to
    /// answer the document instead.
    @Test("Spørsmålet står sist, dokumentet først")
    func questionComesLast() {
        let prompt = BorealisAssistant.prompt(for: "Når er fristen?", given: ["Fristen er 1. oktober."])
        #expect(prompt.hasSuffix("Når er fristen?"))
        #expect(prompt.contains("Fristen er 1. oktober."))
    }

    @Test("Lange dokumenter avkortes")
    func longDocumentsAreTruncated() {
        let long = String(repeating: "a", count: BorealisAssistant.contextCharacterLimit + 500)
        let prompt = BorealisAssistant.prompt(for: "Hva?", given: [long])
        #expect(prompt.count < long.count + 500)
    }

    @Test("Flere dokumenter blir med, skilt fra hverandre")
    func multipleDocuments() {
        let prompt = BorealisAssistant.prompt(for: "Hva?", given: ["første", "andre"])
        #expect(prompt.contains("første"))
        #expect(prompt.contains("andre"))
    }
}
