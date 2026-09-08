import Foundation
import MLXLMCommon
import Tokenizers

/// Leser tokenizeren fra en mappe i app-pakken.
///
/// MLX leverer ingen tokenizer. `MLXLMCommon` definerer bare protokollen, og
/// den eneste implementasjonen i pakken er en no-op til ytelsestesting. Veien
/// pakken selv anbefaler går gjennom `MLXHuggingFace`, som er makroer som
/// utvider seg til hub-klienten — altså nett, i en app som ikke skal ha noe.
///
/// Derfor denne broen: `swift-transformers` leser `tokenizer.json` og
/// `tokenizer_config.json` rett fra disk, og `LocalTokenizer` kler den om til
/// protokollen MLX venter. Ingen hub-kode kommer inn i bygget.
struct LocalTokenizerLoader: MLXLMCommon.TokenizerLoader {
    func load(from directory: URL) async throws -> any MLXLMCommon.Tokenizer {
        LocalTokenizer(upstream: try await AutoTokenizer.from(modelFolder: directory))
    }
}

/// `Tokenizers.Tokenizer` sett gjennom `MLXLMCommon.Tokenizer`.
///
/// De to protokollene beskriver det samme, med litt ulike navn: MLX sier
/// `tokenIds`, Hugging Face sier `tokens`. Alt her er navnebytte, ingen logikk.
struct LocalTokenizer: MLXLMCommon.Tokenizer {
    let upstream: any Tokenizers.Tokenizer

    func encode(text: String, addSpecialTokens: Bool) -> [Int] {
        upstream.encode(text: text, addSpecialTokens: addSpecialTokens)
    }

    func decode(tokenIds: [Int], skipSpecialTokens: Bool) -> String {
        upstream.decode(tokens: tokenIds, skipSpecialTokens: skipSpecialTokens)
    }

    func convertTokenToId(_ token: String) -> Int? {
        upstream.convertTokenToId(token)
    }

    func convertIdToToken(_ id: Int) -> String? {
        upstream.convertIdToToken(id)
    }

    var bosToken: String? { upstream.bosToken }
    var eosToken: String? { upstream.eosToken }
    var unknownToken: String? { upstream.unknownToken }

    /// Setter sammen ledeteksten slik modellen er trent til å få den.
    ///
    /// Malen ligger i `chat_template.jinja` ved siden av vektene. Uten den blir
    /// meldingene sendt som løs tekst, og en instruksjonstrent modell svarer da
    /// merkbart dårligere — den ser ikke hvor spørsmålet ditt begynner.
    func applyChatTemplate(
        messages: [[String: any Sendable]],
        tools: [[String: any Sendable]]?,
        additionalContext: [String: any Sendable]?
    ) throws -> [Int] {
        try upstream.applyChatTemplate(
            messages: messages.map { $0.mapValues { value in value } },
            tools: tools,
            additionalContext: additionalContext
        )
    }
}
