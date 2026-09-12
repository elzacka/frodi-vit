import Foundation
import SwiftData
import SwiftUI

/// Driver samtalen: tar imot spørsmålet, henter svaret, lagrer begge deler.
///
/// Ligger utenfor viewet fordi svaret strømmer inn over tid, og fordi et svar
/// som er halvferdig når du bytter skjerm skal fortsette å komme.
@MainActor
@Observable
final class Conversation {
    private(set) var isAnswering = false
    private(set) var errorMessage: String?

    private let assistant: Assistant
    private var task: Task<Void, Never>?

    init(assistant: Assistant) {
        self.assistant = assistant
    }

    /// Sender spørsmålet og lagrer svaret etter hvert som det kommer.
    ///
    /// Både spørsmålet og svaret legges i `chat`. Uten den ville meldingene
    /// blitt liggende løst i basen, uten en tråd som kan slettes samlet.
    ///
    /// Lagrer på hver oppdatering, ikke bare til slutt. Blir appen avbrutt
    /// midt i et svar, står det som kom fram igjen neste gang — avkortet, men
    /// merket som avkortet, i stedet for at hele svaret er borte.
    func send(_ question: String, in chat: Chat, documents: [Document] = [], context: ModelContext) {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isAnswering else { return }

        errorMessage = nil
        isAnswering = true

        task = Task {
            defer { isAnswering = false }

            let reply: ChatMessage
            do {
                let question = try ChatMessage(role: .user, text: trimmed)
                question.chat = chat
                context.insert(question)

                reply = try ChatMessage(role: .assistant, text: "")
                reply.chat = chat
                context.insert(reply)

                // Samtalen navngis etter det første spørsmålet, og flyttes
                // øverst i listen fordi du nettopp brukte den.
                try chat.nameIfUnnamed(from: trimmed)
                chat.lastOpenedAt = Date()

                try context.save()
            } catch {
                errorMessage = error.localizedDescription
                return
            }

            var text = ""
            do {
                let grounding = try await Grounding.context(
                    for: trimmed, documents: documents, in: context
                )
                reply.sourceNames = grounding.sources
                for try await piece in assistant.answer(to: trimmed, given: grounding.texts) {
                    text += piece
                    try reply.replaceText(text)
                    try? context.save()
                }
            } catch is CancellationError {
                reply.wasInterrupted = true
                try? context.save()
                return
            } catch let error as AssistantError {
                errorMessage = error.guidance
                // Et tomt svar er ikke et svar. Da er beskjeden det eneste
                // som skal stå igjen.
                if text.isEmpty { context.delete(reply) }
                try? context.save()
                return
            } catch {
                errorMessage = AssistantError.underlying(error.localizedDescription).guidance
                if text.isEmpty { context.delete(reply) }
                try? context.save()
                return
            }
        }
    }

    /// Stopper et svar som er i gang. Det som kom fram blir stående.
    func stop() {
        task?.cancel()
    }

    func dismissError() {
        errorMessage = nil
    }
}
