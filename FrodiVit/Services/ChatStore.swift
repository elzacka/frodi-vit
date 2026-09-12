import Foundation
import SwiftData

/// Creates, fetches and deletes conversations.
///
/// Lives outside the view because three screens need the same rules: the
/// conversation list, the Info page and the conversation itself.
@MainActor
enum ChatStore {
    /// The conversations in the order the list shows them: last opened first.
    static func all(in context: ModelContext) -> [Chat] {
        let descriptor = FetchDescriptor<Chat>(
            sortBy: [SortDescriptor(\.lastOpenedAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    /// Makes a new conversation, or lets you stay in the one you are in.
    ///
    /// An empty conversation already is a new conversation. Without this, «Ny
    /// samtale» twice in a row would leave an empty row in the list.
    static func create(orReuse current: Chat?, in context: ModelContext) -> Chat {
        if let current, !current.isDeleted, current.isEmpty {
            current.lastOpenedAt = Date()
            return current
        }

        let chat = Chat()
        context.insert(chat)
        try? context.save()
        return chat
    }

    /// Marks the conversation as the one you were in last.
    static func open(_ chat: Chat, in context: ModelContext) {
        chat.lastOpenedAt = Date()
        try? context.save()
    }

    /// Deletes the conversations and everything that belongs to them.
    ///
    /// The messages and documents follow through `cascade` on the relationship, so
    /// deleting the conversation itself is enough.
    static func delete(_ chats: [Chat], in context: ModelContext) {
        for chat in chats { context.delete(chat) }
        try? context.save()
    }

    /// Collects messages and documents from before the app had several conversations.
    ///
    /// The old version had one thread and no `Chat`. Without this, everything you
    /// had asked would sit invisibly in the store: SwiftData keeps the rows, but no
    /// screen would find them again.
    ///
    /// Runs at launch. If it finds nothing loose, it does nothing.
    static func adoptOrphans(in context: ModelContext) {
        let messages = ((try? context.fetch(FetchDescriptor<ChatMessage>())) ?? [])
            .filter { $0.chat == nil }
            .sorted { $0.createdAt < $1.createdAt }
        let documents = ((try? context.fetch(FetchDescriptor<Document>())) ?? [])
            .filter { $0.chat == nil }
            .sorted { $0.createdAt < $1.createdAt }

        guard !messages.isEmpty || !documents.isEmpty else { return }

        let chat = Chat(createdAt: messages.first?.createdAt ?? Date())
        context.insert(chat)
        for message in messages { message.chat = chat }
        for document in documents { document.chat = chat }

        // The title is taken from the first question, which would otherwise read
        // «Ny samtale» for a thread that may be long.
        if let first = messages.first(where: { $0.role == .user }),
           let text = try? first.text() {
            try? chat.nameIfUnnamed(from: text)
        }

        try? context.save()
    }
}
