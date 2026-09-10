import Foundation
import SwiftData

/// En samtale. Holder meldingene og dokumentene som hører til den ene tråden.
///
/// Appen hadde én samtale til å begynne med, og alt lå flatt. Det holder bare
/// så lenge du spør om én ting: to emner i samme tråd gir modellen dokumenter
/// den ikke skulle sett, og deg en historikk du ikke finner fram i.
///
/// Tittelen er forseglet, som meldingene. Den er hentet fra det første
/// spørsmålet ditt, og et spørsmål røper ofte mer enn svaret gjør. En liste
/// over titler i klartekst ville vært en lesbar oppsummering av alt du har
/// spurt om.
@Model
final class Chat {
    var createdAt: Date = Date()

    /// Sist du åpnet samtalen. Styrer rekkefølgen i listen, og hvilken samtale
    /// appen åpner i.
    var lastOpenedAt: Date = Date()

    /// Forseglet UTF-8, eller `nil` før du har spurt om noe. Les den gjennom
    /// `title()`.
    var sealedTitle: Data?

    /// Sletter du samtalen, følger meldingene med. De hører ikke til noe annet.
    @Relationship(deleteRule: .cascade, inverse: \ChatMessage.chat)
    var messages: [ChatMessage] = []

    /// Dokumentene hører til den ene samtalen, ikke til appen.
    ///
    /// Laster du opp lønnsslippen din i én tråd, skal den ikke ligge i
    /// ledeteksten neste gang du spør om noe helt annet.
    @Relationship(deleteRule: .cascade, inverse: \Document.chat)
    var documents: [Document] = []

    init(createdAt: Date = Date()) {
        self.createdAt = createdAt
        self.lastOpenedAt = createdAt
    }

    // MARK: - Innhold

    var messagesInOrder: [ChatMessage] {
        messages.sorted { $0.createdAt < $1.createdAt }
    }

    var documentsInOrder: [Document] {
        documents.sorted { $0.createdAt < $1.createdAt }
    }

    /// Ingen meldinger og ingen dokumenter. Da er det ingenting å ta vare på,
    /// og «Ny samtale» kan bli stående i den du alt er i.
    var isEmpty: Bool {
        messages.isEmpty && documents.isEmpty
    }

    // MARK: - Tittel

    /// Åpner tittelen. Kaster om samtalen ble forseglet på en annen enhet.
    func title() throws -> String? {
        guard let sealedTitle else { return nil }
        return try Vault.openText(sealedTitle)
    }

    /// Navngir samtalen etter det første spørsmålet, én gang.
    ///
    /// Senere spørsmål lar tittelen stå. Den skal peke på hva tråden startet
    /// som, og en tittel som skifter mens du skriver er en tittel du ikke
    /// kjenner igjen i listen.
    func nameIfUnnamed(from question: String) throws {
        guard sealedTitle == nil else { return }
        let name = Self.title(from: question)
        guard !name.isEmpty else { return }
        sealedTitle = try Vault.seal(name)
    }

    /// Første linje, kuttet på et ordskille.
    ///
    /// Kutter på ord framfor på tegn: «Hva står det i kontrak…» er til å lese,
    /// «Hva står det i kontrakt» er en tittel som ser feilstavet ut.
    static func title(from question: String, limit: Int = 48) -> String {
        let firstLine = question
            .split(separator: "\n", omittingEmptySubsequences: true)
            .first
            .map(String.init) ?? question
        let trimmed = firstLine.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > limit else { return trimmed }

        let head = trimmed.prefix(limit)
        let cut = head.lastIndex(of: " ").map { head[head.startIndex..<$0] } ?? head
        return cut.trimmingCharacters(in: .whitespaces) + "…"
    }
}
