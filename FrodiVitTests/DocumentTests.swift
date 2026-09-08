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

    @Test("Et kort dokument blir ikke avkortet")
    func shortDocumentIsNotTruncated() throws {
        #expect(try Document(name: "a.txt", text: "kort").isTruncatedInPrompt == false)
    }

    @Test("Et langt dokument sier fra at bare starten er med")
    func longDocumentIsTruncated() throws {
        let long = String(repeating: "a", count: BorealisAssistant.contextCharacterLimit + 1)
        #expect(try Document(name: "lang.txt", text: long).isTruncatedInPrompt)
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
