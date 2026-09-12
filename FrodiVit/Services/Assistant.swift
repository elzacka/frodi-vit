import Foundation

/// The gateway to the language model. Everything that produces text goes through
/// this, so the model can be swapped without the views noticing.
///
/// The same move as `Transcriber` in Fróði røst, and for the same reason: that
/// model was already swapped once, from Apple's engine to nb-whisper, without a
/// single view being touched.
///
/// Bound to the main actor because language-model runtimes are rarely
/// `Sendable`. The actual computation happens on the GPU regardless.
@MainActor
protocol Assistant {
    /// Answers the question, one piece of text at a time.
    ///
    /// Streaming is not decoration. Measured decoding for a small Gemma model on
    /// iPhone 17 is slower with MLX than with most alternatives, and an answer that
    /// arrives word by word is bearable. The same answer behind a spinner is not.
    func answer(to question: String, given context: [String]) -> AsyncThrowingStream<String, Error>
}

enum AssistantError: LocalizedError {
    case modelMissing
    case outOfMemory
    case underlying(String)

    var errorDescription: String? {
        switch self {
        case .modelMissing:
            String(localized: "Språkmodellen mangler i appen.")
        case .outOfMemory:
            String(localized: "Enheten hadde ikke nok minne til å svare.")
        case .underlying(let message):
            message
        }
    }

    /// Longer explanation for the screen. Says what you can do, not only what
    /// went wrong.
    var guidance: String {
        switch self {
        case .modelMissing:
            String(localized: "Fróði fant ikke språkmodellen. Den følger med appen, så dette betyr som regel at installasjonen er ufullstendig. Installer appen på nytt.")
        case .outOfMemory:
            String(localized: "Enheten hadde ikke nok minne. Lukk noen andre apper og prøv igjen.")
        case .underlying:
            String(localized: "Svaret ble ikke ferdig denne gangen. Prøv igjen.")
        }
    }
}

/// Stands in for the model until MLX is wired up.
///
/// It does not answer, it explains why it does not answer. The point is that
/// the rest of the app — the conversation, the sealing, the screen — can be
/// built and tested before the model of nearly a gigabyte enters the picture.
struct MissingModelAssistant: Assistant {
    func answer(to question: String, given context: [String]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish(throwing: AssistantError.modelMissing)
        }
    }
}
