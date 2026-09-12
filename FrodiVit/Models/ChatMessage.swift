import Foundation
import SwiftData

/// A message in the conversation. The text is sealed, never in plaintext.
///
/// The SwiftData store is protected by the sandbox and file protection, but that
/// is not enough here: what you ask often reveals more than the answer does, and
/// a store that can be read is a store that can be read. So the text goes
/// through `Vault` on the way in and out, the same as the documents you upload.
@Model
final class ChatMessage {
    /// Who wrote the message. Stored as text because SwiftData cannot sort or
    /// filter on an enum without extra work.
    var roleValue: String = Role.user.rawValue

    /// Sealed UTF-8. Read it through `text()`, not directly.
    var sealedText: Data = Data()

    var createdAt: Date = Date()

    /// The conversation the message belongs to.
    ///
    /// Optional because messages saved before the app had several conversations
    /// have none. `ChatStore.adoptOrphans` collects them at launch.
    var chat: Chat?

    /// The model did not finish answering. The text is then what it got said, and
    /// the screen says so instead of letting a cut-off answer look complete.
    var wasInterrupted: Bool = false

    /// The names of the documents the answer builds on, in the order the passages
    /// appeared. Empty when the answer builds on nothing.
    ///
    /// Not sealed: the name already sits in plaintext on `Document`, and one more
    /// name on an answer reveals no more than that.
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

    /// Opens the text. Throws if the message was sealed on another device.
    func text() throws -> String {
        guard !sealedText.isEmpty else { return "" }
        return try Vault.openText(sealedText)
    }

    /// Used while the answer streams in, where the text grows with every token.
    func replaceText(_ text: String) throws {
        sealedText = try Vault.seal(text)
    }

    /// An empty answer bubble waiting for the first word.
    ///
    /// The answer is created the moment the question is sent, so what streams in
    /// has somewhere to be saved along the way. Until the first token the message
    /// is empty, and the screen already has a «Tenker …» saying the same. Two
    /// signals for the same thing, one of them an empty shape, say less than one.
    ///
    /// Also applies after a restart: if the app crashes before the first token, the
    /// empty message stays, and without this it would sit as an empty bubble in the
    /// conversation forever. An interrupted answer is different: it shows «Svaret
    /// ble avbrutt», and should stay.
    var isAwaitingFirstToken: Bool {
        guard role == .assistant, !wasInterrupted else { return false }
        return ((try? text()) ?? "").isEmpty
    }
}
