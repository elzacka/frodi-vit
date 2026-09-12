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

    /// The text must never sit readable in the store.
    @Test("Teksten ligger ikke i klartekst")
    func textIsSealed() throws {
        let secret = "noe jeg ikke vil at andre skal lese"
        let message = try ChatMessage(role: .user, text: secret)
        #expect(message.sealedText.range(of: Data(secret.utf8)) == nil)
    }

    /// The answer grows while it streams in, and every update is sealed anew. The
    /// previous text must not be left behind.
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

    /// An empty message is created the moment the answer starts, before the first token.
    @Test("En tom melding gir tom tekst, ikke en feil")
    func emptyMessageIsNotAnError() throws {
        #expect(try ChatMessage(role: .assistant, text: "").text() == "")
    }

    // MARK: - The empty answer bubble
    /// The screen already has a «Tenker …». An empty bubble beside it says nothing.
    @Test("Et svar uten tekst venter på første token")
    func emptyAnswerIsWaiting() throws {
        #expect(try ChatMessage(role: .assistant, text: "").isAwaitingFirstToken)
    }

    @Test("Et svar med tekst venter ikke")
    func answerWithTextIsNotWaiting() throws {
        #expect(try !ChatMessage(role: .assistant, text: "Fróði").isAwaitingFirstToken)
    }

    /// An interrupted answer shows «Svaret ble avbrutt», and must stay even if no
    /// text ever came.
    @Test("Et avbrutt svar blir stående")
    func interruptedAnswerStays() throws {
        let message = try ChatMessage(role: .assistant, text: "")
        message.wasInterrupted = true
        #expect(!message.isAwaitingFirstToken)
    }

    /// Applies only to answers. An empty question cannot be sent anyway.
    @Test("Et spørsmål venter aldri")
    func questionsNeverWait() throws {
        #expect(try !ChatMessage(role: .user, text: "").isAwaitingFirstToken)
    }
}
