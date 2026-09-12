import Foundation
import SwiftData
import SwiftUI

/// Drives the conversation: takes the question, fetches the answer, saves both.
///
/// Lives outside the view because the answer streams in over time, and because
/// an answer that is half done when you switch screens should keep coming.
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

    /// Sends the question and saves the answer as it arrives.
    ///
    /// Both the question and the answer go into `chat`. Without it the messages
    /// would sit loose in the store, with no thread that can be deleted as one.
    ///
    /// Saves on every update, not only at the end. If the app is interrupted in the
    /// middle of an answer, what came through is there next time: truncated, but
    /// marked as truncated, instead of the whole answer being gone.
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

                // The conversation is named after the first question, and moved to the top
                // of the list because you just used it.
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
                // An empty answer is not an answer. Then the message is the only thing
                // that should remain.
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

    /// Stops an answer in progress. What came through stays.
    func stop() {
        task?.cancel()
    }

    func dismissError() {
        errorMessage = nil
    }
}
