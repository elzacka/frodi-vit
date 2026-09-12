import Foundation
import SwiftData

/// Et dokument du har lastet opp, og som svarene kan bygge på.
///
/// Bare teksten lagres, ikke originalfilen. Det er teksten modellen leser, og
/// en PDF på ti megabyte i basen ville kostet plass uten å gi noe tilbake.
/// Vil du ha originalen, ligger den fremdeles der du hentet den fra.
///
/// Teksten er forseglet, som meldingene. Et opplastet dokument er ofte det mest
/// avslørende i appen — det er derfor du lastet det opp.
@Model
final class Document {
    /// Filnavnet slik det sto da du valgte filen. Vises i listen.
    var name: String = ""

    /// Forseglet UTF-8. Les den gjennom `text()`.
    var sealedText: Data = Data()

    /// Antall tegn i klartekst, lagret ved import.
    ///
    /// Uten dette måtte skjermen låse opp hele teksten bare for å vise «12 000
    /// tegn» i en liste. Tallet er ikke hemmelig; teksten er det.
    var characterCount: Int = 0

    var createdAt: Date = Date()

    /// Samtalen dokumentet hører til. Se `ChatMessage.chat`.
    var chat: Chat?

    /// Utdragene gjenfinningen velger blant. Tomt til dokumentet er delt opp
    /// og innebygget, se `Grounding.index`.
    @Relationship(deleteRule: .cascade, inverse: \Passage.document)
    var passages: [Passage] = []

    init(name: String, text: String, createdAt: Date = Date()) throws {
        self.name = name
        self.sealedText = try Vault.seal(text)
        self.characterCount = text.count
        self.createdAt = createdAt
    }

    func text() throws -> String {
        guard !sealedText.isEmpty else { return "" }
        return try Vault.openText(sealedText)
    }
}
