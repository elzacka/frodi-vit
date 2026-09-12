import Foundation
import MLXLMCommon
import MLXLLM

/// Answers with borealis-open-1b, run in the app with MLX.
///
/// The model sits as a folder reference in the app bundle and is loaded from
/// there. There is no download path: `MLXHuggingFace` is not linked in, so a
/// missing file fails instead of fetching.
@MainActor
final class BorealisAssistant: Assistant {
    /// The name of the folder `Scripts/fetch-model.sh` puts the model in.
    ///
    /// The folder reference in `project.yml` points at `Resources/Model`, so that
    /// whole folder lands in the app bundle with its name intact. The model is
    /// therefore under `Model/`, not at the root of the bundle.
    nonisolated static let modelDirectoryName = "borealis-open-1b"
    nonisolated static let modelParentName = "Model"

    /// Loaded at the first question, not at launch. Half a gigabyte of weights
    /// should not sit in memory while you only look at an empty conversation.
    private var session: ChatSession?

    /// Does the model exist in the bundle at all?
    ///
    /// Without this the app falls back on an incomprehensible error from MLX when
    /// someone has skipped `fetch-model.sh`. A plain file check, without state, so
    /// it can be read from anywhere, including the tests, which do not run on the
    /// main actor.
    nonisolated static var isBundled: Bool {
        modelDirectory != nil
    }

    nonisolated static var modelDirectory: URL? {
        guard let url = Bundle.main.url(
            forResource: modelDirectoryName,
            withExtension: nil,
            subdirectory: modelParentName
        ) else { return nil }
        // The folder can exist without being complete, if a script was interrupted.
        // Then it is more honest to say the model is missing.
        return FileManager.default.fileExists(
            atPath: url.appendingPathComponent("config.json").path
        ) ? url : nil
    }

    // No system prompt, deliberately.
    //
    // The Gemma template has no system role. Send one and the template pastes it
    // in at the front of the first *user* message. The model then read «Du er
    // Fróði, en hjelpsom assistent …» as something the user had written, and
    // answered the claim: «Du er en person som svarer på en robot, og du er
    // Fróði.» Measured on a device 8 September 2026.
    //
    // The National Library has moreover baked the behaviour into the weights with
    // «prompt baking», precisely so the prompt does not need to sit in the
    // context. Their own example sends only a user message.
    //
    // Do not add a system prompt again without reading the template first.

    /// Tighter than the default, which is `topP 1.0`, that is, no filtering of the
    /// tail at all. A 1B model pulls a lot of nonsense from there.
    private static var parameters: GenerateParameters {
        var p = GenerateParameters()
        p.temperature = 0.6
        p.topP = 0.9
        // Without a penalty, small models tend to repeat the same sentence up to the cap.
        p.repetitionPenalty = 1.1
        // A cap, so an answer that goes off the rails ends by itself.
        p.maxTokens = 800
        return p
    }

    /// How much document text fits in one prompt, in total.
    ///
    /// **The limit is set by the memory on the device, not by the context window.**
    /// The model handles 32k tokens. The device does not: the weights and the KV
    /// cache sit in memory at the same time, and jetsam takes the app long before
    /// the window is full.
    ///
    /// Measured on iPhone 17 Pro on 11 September 2026, with `ContextProbe`. The cap
    /// the device gives the app is about 3 376 MB:
    ///
    /// | Characters | Peak | Left | Outcome |
    /// |---|---|---|---|
    /// | 8 000 | 2 712 MB | 664 MB | Answers |
    /// | 10 000 | 2 868 MB | 508 MB | Answers |
    /// | 12 000 | 3 065 MB | 310 MB | Answers, with little left |
    /// | 16 000 | – | – | Killed before the first token |
    /// | 41 000 | – | – | Killed before the first token |
    ///
    /// About 2 090 MB go before the first character of document text, and every
    /// 1 000 characters cost roughly 78 MB more. The curve is straight, and the cap
    /// sits just above 14 000 characters on this device.
    ///
    /// The limit stood at 48 000 for two days. That number came from the context
    /// window and was never measured: the NSM guide of 41 191 characters killed the
    /// app before the first word, every time. 8 000 is the value it had before, and
    /// it gives the most margin to devices with less memory than this one.
    ///
    /// The price is that a long document is truncated. `DocumentBar` says so with
    /// «bare starten er med», so a truncated text is visible rather than silent.
    /// The way out is to select the relevant parts with `borealis-embed-212m`, not
    /// to raise the limit again.
    ///
    /// The limit applies to all documents together, not each one. Were it per
    /// document, two uploads would blow the window.
    nonisolated static let contextCharacterLimit = 8_000

    /// How many characters of the budget each document gets.
    ///
    /// Shortest document first, and each gets either what it needs or its share of
    /// what is left. A short note beside a long report therefore does not claim
    /// half the budget without using it.
    nonisolated static func allowances(
        for lengths: [Int], within budget: Int = contextCharacterLimit
    ) -> [Int] {
        var allowances = [Int](repeating: 0, count: lengths.count)
        var remaining = budget
        var left = lengths.count
        for index in lengths.indices.sorted(by: { lengths[$0] < lengths[$1] }) {
            let take = min(lengths[index], remaining / left)
            allowances[index] = take
            remaining -= take
            left -= 1
        }
        return allowances
    }

    func answer(to question: String, given context: [String]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task { @MainActor in
                do {
                    let session = try await session()
                    let prompt = Self.prompt(for: question, given: context)
                    for try await piece in session.streamResponse(to: prompt) {
                        continuation.yield(piece)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: Self.translate(error))
                }
            }
        }
    }

    /// Assembles the question with the text from the documents you have uploaded.
    ///
    /// The document comes first and the question last, because the model is trained
    /// to answer the last thing said. With the question at the top it tends to
    /// answer the document instead.
    ///
    /// This is not retrieval. The whole text is included, truncated against
    /// ``contextCharacterLimit``, which is shared between the documents. Once
    /// `borealis-embed-212m` can be converted, this is where the selection should
    /// happen instead.
    nonisolated static func prompt(for question: String, given context: [String]) -> String {
        let texts = context.filter { !$0.isEmpty }
        let documents = zip(texts, allowances(for: texts.map(\.count)))
            .map { String($0.prefix($1)) }
            .filter { !$0.isEmpty }

        guard !documents.isEmpty else { return question }

        let joined = documents.joined(separator: "\n\n---\n\n")
        return """
            Her er teksten du skal svare ut fra:

            \(joined)

            Svar på dette ut fra teksten over. Står ikke svaret der, si det.

            \(question)
            """
    }

    /// One session is reused across questions, so MLX keeps the KV cache and does
    /// not re-read the whole conversation for every answer.
    private func session() async throws -> ChatSession {
        if let session { return session }

        guard let directory = Self.modelDirectory else {
            throw AssistantError.modelMissing
        }

        let model = try await loadModelContainer(
            from: directory, using: LocalTokenizerLoader()
        )
        let session = ChatSession(model, generateParameters: Self.parameters)
        self.session = session
        return session
    }

    /// MLX reports out-of-memory as an ordinary error. The screen should say what
    /// you can do about it, not reproduce the framework's message.
    private static func translate(_ error: Error) -> Error {
        if error is AssistantError { return error }
        let text = error.localizedDescription.lowercased()
        if text.contains("memory") || text.contains("allocat") {
            return AssistantError.outOfMemory
        }
        return AssistantError.underlying(error.localizedDescription)
    }
}
