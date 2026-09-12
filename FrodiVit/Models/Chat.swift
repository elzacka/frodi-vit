import Foundation
import SwiftData

/// A conversation. Holds the messages and documents that belong to the one thread.
///
/// The app had one conversation at first, and everything lay flat. That holds
/// only as long as you ask about one thing: two topics in one thread give the
/// model documents it should not have seen, and you a history you cannot find
/// your way around.
///
/// The title is sealed, like the messages. It is taken from your first question,
/// and a question often reveals more than the answer does. A list of titles in
/// plaintext would be a readable summary of everything you have asked.
@Model
final class Chat {
    var createdAt: Date = Date()

    /// When you last opened the conversation. Governs the order in the list, and
    /// which conversation the app opens in.
    var lastOpenedAt: Date = Date()

    /// Sealed UTF-8, or `nil` before you have asked anything. Read it through
    /// `title()`.
    var sealedTitle: Data?

    /// Delete the conversation and the messages go with it. They belong to nothing else.
    @Relationship(deleteRule: .cascade, inverse: \ChatMessage.chat)
    var messages: [ChatMessage] = []

    /// The documents belong to the one conversation, not to the app.
    ///
    /// Upload your payslip in one thread and it must not sit in the prompt the next
    /// time you ask about something else entirely.
    @Relationship(deleteRule: .cascade, inverse: \Document.chat)
    var documents: [Document] = []

    init(createdAt: Date = Date()) {
        self.createdAt = createdAt
        self.lastOpenedAt = createdAt
    }

    // MARK: - Content
    var messagesInOrder: [ChatMessage] {
        messages.sorted { $0.createdAt < $1.createdAt }
    }

    var documentsInOrder: [Document] {
        documents.sorted { $0.createdAt < $1.createdAt }
    }

    /// No messages and no documents. Then there is nothing to keep, and «Ny
    /// samtale» can stay in the one you are already in.
    var isEmpty: Bool {
        messages.isEmpty && documents.isEmpty
    }

    // MARK: - Title
    /// Opens the title. Throws if the conversation was sealed on another device.
    func title() throws -> String? {
        guard let sealedTitle else { return nil }
        return try Vault.openText(sealedTitle)
    }

    /// Names the conversation after the first question, once.
    ///
    /// Later questions leave the title alone. It should point at what the thread
    /// started as, and a title that changes while you type is a title you do not
    /// recognise in the list.
    func nameIfUnnamed(from question: String) throws {
        guard sealedTitle == nil else { return }
        let name = Self.title(from: question)
        guard !name.isEmpty else { return }
        sealedTitle = try Vault.seal(name)
    }

    /// The first line, cut at a word boundary.
    ///
    /// Cuts on words rather than characters: «Hva står det i kontrak…» is readable,
    /// «Hva står det i kontrakt» is a title that looks misspelled.
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
