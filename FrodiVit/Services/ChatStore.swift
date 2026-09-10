import Foundation
import SwiftData

/// Oppretter, henter og sletter samtaler.
///
/// Ligger utenfor viewet fordi tre skjermer trenger de samme reglene:
/// samtalelisten, innstillingene og selve samtalen.
@MainActor
enum ChatStore {
    /// Samtalene i den rekkefølgen listen viser dem: sist åpnet øverst.
    static func all(in context: ModelContext) -> [Chat] {
        let descriptor = FetchDescriptor<Chat>(
            sortBy: [SortDescriptor(\.lastOpenedAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    /// Lager en ny samtale, eller lar deg bli stående i den du er i.
    ///
    /// En tom samtale er allerede en ny samtale. Uten dette ville «Ny samtale»
    /// to ganger på rad lagt igjen en tom rad i listen.
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

    /// Merker samtalen som den du var i sist.
    static func open(_ chat: Chat, in context: ModelContext) {
        chat.lastOpenedAt = Date()
        try? context.save()
    }

    /// Sletter samtalene og alt som hører til dem.
    ///
    /// Meldingene og dokumentene følger med gjennom `cascade` på relasjonen,
    /// så det er nok å slette samtalen selv.
    static func delete(_ chats: [Chat], in context: ModelContext) {
        for chat in chats { context.delete(chat) }
        try? context.save()
    }

    /// Samler meldinger og dokumenter fra før appen fikk flere samtaler.
    ///
    /// Den gamle versjonen hadde én tråd og ingen `Chat`. Uten dette ville alt
    /// du hadde spurt om blitt liggende usynlig i basen: SwiftData beholder
    /// radene, men ingen skjerm ville funnet dem igjen.
    ///
    /// Kjøres ved oppstart. Finner den ingenting løst, gjør den ingenting.
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

        // Tittelen hentes fra det første spørsmålet, som ellers ville stått
        // som «Ny samtale» for en tråd som kan være lang.
        if let first = messages.first(where: { $0.role == .user }),
           let text = try? first.text() {
            try? chat.nameIfUnnamed(from: text)
        }

        try? context.save()
    }
}
