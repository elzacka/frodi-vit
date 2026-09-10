import Foundation
import Testing
@testable import FrodiVit

@Suite("Melding")
struct ChatMessageTests {
    @Test("Teksten kommer uendret tilbake")
    func textRoundTrips() throws {
        let message = try ChatMessage(role: .user, text: "Hva betyr «fróði»?")
        #expect(try message.text() == "Hva betyr «fróði»?")
    }

    /// Teksten skal aldri ligge lesbar i basen.
    @Test("Teksten ligger ikke i klartekst")
    func textIsSealed() throws {
        let secret = "noe jeg ikke vil at andre skal lese"
        let message = try ChatMessage(role: .user, text: secret)
        #expect(message.sealedText.range(of: Data(secret.utf8)) == nil)
    }

    /// Svaret vokser mens det strømmer inn, og hver oppdatering forsegles på
    /// nytt. Den forrige teksten skal ikke bli liggende igjen.
    @Test("Teksten kan byttes ut mens svaret kommer")
    func textCanBeReplaced() throws {
        let message = try ChatMessage(role: .assistant, text: "Fróði")
        try message.replaceText("Fróði betyr «den kunnskapsrike».")

        #expect(try message.text() == "Fróði betyr «den kunnskapsrike».")
        #expect(message.sealedText.range(of: Data("Fróði".utf8)) == nil)
    }

    @Test("Rollen overlever lagring")
    func roleSurvives() throws {
        #expect(try ChatMessage(role: .user, text: "a").role == .user)
        #expect(try ChatMessage(role: .assistant, text: "b").role == .assistant)
    }

    /// En tom melding lages i det svaret starter, før første token kommer.
    @Test("En tom melding gir tom tekst, ikke en feil")
    func emptyMessageIsNotAnError() throws {
        #expect(try ChatMessage(role: .assistant, text: "").text() == "")
    }

    // MARK: - Den tomme svarboblen

    /// Skjermen har alt en «Tenker …». En tom boble ved siden av den sier
    /// ingenting.
    @Test("Et svar uten tekst venter på første token")
    func emptyAnswerIsWaiting() throws {
        #expect(try ChatMessage(role: .assistant, text: "").isAwaitingFirstToken)
    }

    @Test("Et svar med tekst venter ikke")
    func answerWithTextIsNotWaiting() throws {
        #expect(try !ChatMessage(role: .assistant, text: "Fróði").isAwaitingFirstToken)
    }

    /// Et avbrutt svar viser «Svaret ble avbrutt», og skal bli stående selv om
    /// det aldri kom noe tekst.
    @Test("Et avbrutt svar blir stående")
    func interruptedAnswerStays() throws {
        let message = try ChatMessage(role: .assistant, text: "")
        message.wasInterrupted = true
        #expect(!message.isAwaitingFirstToken)
    }

    /// Gjelder bare svar. Et tomt spørsmål kan uansett ikke sendes.
    @Test("Et spørsmål venter aldri")
    func questionsNeverWait() throws {
        #expect(try !ChatMessage(role: .user, text: "").isAwaitingFirstToken)
    }
}
