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

    /// Et opplastet dokument er ofte det mest avslørende i appen.
    @Test("Teksten ligger ikke i klartekst")
    func textIsSealed() throws {
        let secret = "kontonummeret står her"
        let document = try Document(name: "brev.pdf", text: secret)
        #expect(document.sealedText.range(of: Data(secret.utf8)) == nil)
    }

    /// Tallet lagres ved import, slik at listen slipper å låse opp teksten
    /// bare for å vise hvor stort dokumentet er.
    @Test("Antall tegn lagres i klartekst")
    func characterCountIsStored() throws {
        #expect(try Document(name: "a.txt", text: "abcde").characterCount == 5)
    }

}

/// Budsjettet deles mellom dokumentene, så hvor mye ett av dem får plass til
/// avhenger av hva annet som er lastet opp.
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

    /// Uten dette ville tre opplastinger sendt tre ganger budsjettet inn i
    /// ledeteksten, og sprengt kontekstvinduet.
    @Test("Flere dokumenter deler på budsjettet")
    func budgetIsSharedAcrossDocuments() {
        let budget = BorealisAssistant.contextCharacterLimit
        let shares = BorealisAssistant.allowances(for: [budget, budget, budget])
        #expect(shares.reduce(0, +) <= budget)
    }

    /// Korteste først, slik at et kort notat ikke legger beslag på halve
    /// budsjettet uten å bruke det.
    @Test("Et kort notat tar ikke plass fra en lang rapport")
    func shortDocumentDoesNotStarveTheLongOne() {
        let shares = BorealisAssistant.allowances(for: [10_000, 100], within: 12_000)
        #expect(shares == [10_000, 100])
    }

    @Test("Er alt for langt, deles budsjettet likt")
    func equalSplitWhenEverythingIsTooLong() {
        #expect(BorealisAssistant.allowances(for: [9_000, 9_000], within: 10_000) == [5_000, 5_000])
    }

    /// NSM sin veileder i risikostyring er 18 sider og 41 191 tegn hentet ut
    /// med PDFKit. Den skal avkortes, ikke gå inn hel.
    ///
    /// Denne testen påsto det motsatte fra 8. september, da grensen ble satt
    /// til 48 000 ut fra kontekstvinduet. Målt på iPhone 17 Pro
    /// 11. september drepte den samme veilederen appen før første ord, hver
    /// gang. Se `contextCharacterLimit` for tallene.
    @Test("En veileder på atten sider avkortes")
    func aRealGuideIsCut() {
        let budget = BorealisAssistant.contextCharacterLimit
        #expect(BorealisAssistant.allowances(for: [41_191]) == [budget])
        #expect(budget < 41_191)
    }

    /// Grensen er målt, ikke resonnert fram. Sett den ikke opp uten å måle
    /// på enhet igjen med `ContextProbe` — 16 000 tegn drepte appen.
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
    /// Uten dokumenter skal spørsmålet stå akkurat som du skrev det.
    @Test("Uten dokumenter er ledeteksten bare spørsmålet")
    func questionOnly() {
        #expect(BorealisAssistant.prompt(for: "Hva er klokka?", given: []) == "Hva er klokka?")
    }

    /// Tomme dokumenter skal ikke gi en ledetekst med et tomt avsnitt i.
    @Test("Tomme dokumenter teller ikke")
    func emptyDocumentsAreIgnored() {
        #expect(BorealisAssistant.prompt(for: "Hva står det?", given: ["", ""]) == "Hva står det?")
    }

    /// Modellen svarer på det siste som ble sagt. Står spørsmålet først,
    /// svarer den gjerne på dokumentet i stedet.
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
