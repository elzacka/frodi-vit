import Foundation
import MLXLMCommon
import Tokenizers

/// Reads the tokenizer from a folder in the app bundle.
///
/// MLX ships no tokenizer. `MLXLMCommon` only defines the protocol, and the only
/// implementation in the package is a no-op for performance testing. The route
/// the package itself recommends goes through `MLXHuggingFace`, which is macros
/// that expand to the hub client: the network, in an app that must have none.
///
/// Hence this bridge: `swift-transformers` reads `tokenizer.json` and
/// `tokenizer_config.json` straight from disk, and `LocalTokenizer` dresses it up
/// as the protocol MLX expects. No hub code enters the build.
struct LocalTokenizerLoader: MLXLMCommon.TokenizerLoader {
    func load(from directory: URL) async throws -> any MLXLMCommon.Tokenizer {
        LocalTokenizer(upstream: try await AutoTokenizer.from(modelFolder: directory))
    }
}

/// `Tokenizers.Tokenizer` seen through `MLXLMCommon.Tokenizer`.
///
/// The two protocols describe the same thing with slightly different names: MLX
/// says `tokenIds`, Hugging Face says `tokens`. Everything here is renaming, no logic.
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

    /// Assembles the prompt the way the model was trained to receive it.
    ///
    /// The template lives in `chat_template.jinja` next to the weights. Without it
    /// the messages are sent as loose text, and an instruction-tuned model then
    /// answers noticeably worse: it cannot see where your question begins.
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
