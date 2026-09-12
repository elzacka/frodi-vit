import Foundation
import SwiftData

/// En melding i samtalen. Teksten ligger forseglet, aldri i klartekst.
///
/// SwiftData-basen er beskyttet av sandkassen og filbeskyttelsen, men det er
/// ikke nok her: det du spør om avslører ofte mer enn svaret gjør, og en base
/// som kan leses er en base som kan leses. Derfor går teksten gjennom `Vault`
/// på vei inn og ut, på samme måte som dokumentene du laster opp.
@Model
final class ChatMessage {
    /// Hvem som skrev meldingen. Lagres som tekst fordi SwiftData ikke kan
    /// sortere eller filtrere på en enum uten videre.
    var roleValue: String = Role.user.rawValue

    /// Forseglet UTF-8. Les den gjennom `text()`, ikke direkte.
    var sealedText: Data = Data()

    var createdAt: Date = Date()

    /// Samtalen meldingen hører til.
    ///
    /// Valgfri fordi meldinger lagret før appen fikk flere samtaler ikke har
    /// noen. `ChatStore.adoptOrphans` samler dem opp ved oppstart.
    var chat: Chat?

    /// Modellen rakk ikke å svare ferdig. Da er teksten det den fikk sagt,
    /// og skjermen sier fra i stedet for å la et avkuttet svar se ferdig ut.
    var wasInterrupted: Bool = false

    /// Navnene på dokumentene svaret bygger på, i den rekkefølgen utdragene
    /// sto. Tomt når svaret ikke bygger på noe.
    ///
    /// Ikke forseglet: navnet ligger alt i klartekst på `Document`, og et navn
    /// til på et svar avslører ikke mer enn det.
    var sourceNames: [String] = []

    init(role: Role, text: String, createdAt: Date = Date()) throws {
        self.roleValue = role.rawValue
        self.sealedText = try Vault.seal(text)
        self.createdAt = createdAt
    }

    enum Role: String {
        case user
        case assistant
    }

    var role: Role {
        Role(rawValue: roleValue) ?? .user
    }

    /// Åpner teksten. Kaster om meldingen ble forseglet på en annen enhet.
    func text() throws -> String {
        guard !sealedText.isEmpty else { return "" }
        return try Vault.openText(sealedText)
    }

    /// Brukes mens svaret strømmer inn, der teksten vokser for hvert token.
    func replaceText(_ text: String) throws {
        sealedText = try Vault.seal(text)
    }

    /// En tom svarboble som venter på det første ordet.
    ///
    /// Svaret opprettes i det spørsmålet sendes, slik at det som strømmer inn
    /// har et sted å lagres underveis. Fram til første token er meldingen tom,
    /// og skjermen har alt en «Tenker …» som sier det samme. To varsler om det
    /// samme, der det ene er en tom form, sier mindre enn ett.
    ///
    /// Gjelder også etter en omstart: krasjer appen før første token, blir den
    /// tomme meldingen liggende, og uten dette ville den stått som en tom
    /// boble i samtalen for alltid. Et avbrutt svar er noe annet — det viser
    /// «Svaret ble avbrutt», og skal bli stående.
    var isAwaitingFirstToken: Bool {
        guard role == .assistant, !wasInterrupted else { return false }
        return ((try? text()) ?? "").isEmpty
    }
}
