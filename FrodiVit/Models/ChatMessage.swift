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

    /// Modellen rakk ikke å svare ferdig. Da er teksten det den fikk sagt,
    /// og skjermen sier fra i stedet for å la et avkuttet svar se ferdig ut.
    var wasInterrupted: Bool = false

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

    /// Åpner teksten. Kaster om meldingen ble forseglet på en annen telefon.
    func text() throws -> String {
        guard !sealedText.isEmpty else { return "" }
        return try Vault.openText(sealedText)
    }

    /// Brukes mens svaret strømmer inn, der teksten vokser for hvert token.
    func replaceText(_ text: String) throws {
        sealedText = try Vault.seal(text)
    }
}
