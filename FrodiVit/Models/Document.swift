import Foundation
import SwiftData

/// A document you have uploaded, which answers can build on.
///
/// Only the text is stored, not the original file. The text is what the model
/// reads, and a ten-megabyte PDF in the store would cost space and give nothing
/// back. If you want the original, it is still where you fetched it from.
///
/// The text is sealed, like the messages. An uploaded document is often the most
/// revealing thing in the app; that is why you uploaded it.
@Model
final class Document {
    /// The file name as it was when you picked the file. Shown in the list.
    var name: String = ""

    /// Sealed UTF-8. Read it through `text()`.
    var sealedText: Data = Data()

    /// Number of characters in plaintext, stored at import.
    ///
    /// Without this the screen would have to unlock the whole text just to show
    /// «12 000 tegn» in a list. The number is not secret; the text is.
    var characterCount: Int = 0

    var createdAt: Date = Date()

    /// The conversation the document belongs to. See `ChatMessage.chat`.
    var chat: Chat?

    /// The passages retrieval chooses among. Empty until the document is split
    /// and embedded, see `Grounding.index`.
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
