import Foundation
import MLX
import MLXLMCommon
import MLXNN
import Tokenizers

/// Gjør tekst om til vektorer med borealis-embed-212m, kjørt i appen med MLX.
///
/// Dette er gjenfinningen: et spørsmål og et avsnitt som handler om det samme
/// får vektorer som peker samme vei, og cosinus mellom dem sier hvor likt. Se
/// `Retrieval` for utvalget; her lages bare vektorene.
///
/// **Modellen kjøres ikke gjennom `MLXEmbedders.EmbeddingGemma`, med vilje.**
/// Den klassen regner kausalt og med GELU, som den vanlige Gemma 3. Denne
/// modellen er trent tosidig (`use_bidirectional_attention: true`) og med silu
/// (`hidden_activation: "silu"`), og de to skiller seg fra hverandre. Målt
/// 12. september 2026 på åtte norske avsnitt og sju spørsmål:
///
/// | Oppmerksomhet | Riktig av 7 | Margin til nest beste |
/// |---|---|---|
/// | Kausal, GELU | 6 | 0,106 |
/// | Tosidig, silu | 7 | 0,210 |
///
/// Vektorene fra de to leseratene er heller ikke de samme — cosinus rundt 0,7
/// for samme tekst. Ryggraden under er derfor skrevet ut her, med de to
/// forskjellene på plass, og `EmbedderTests` holder den opp mot vektorer regnet
/// i Python fra fp32-vektene.
///
/// Vektene lastes ved hvert kall og slippes etterpå. 236 MB skal ikke ligge
/// ved siden av svarmodellens to gigabyte mens du leser et svar; det er der
/// marginen mot jetsam er minst.
actor BorealisEmbedder {
    nonisolated static let modelDirectoryName = "borealis-embed-212m"

    nonisolated static var isBundled: Bool {
        modelDirectory != nil
    }

    nonisolated static var modelDirectory: URL? {
        guard let url = Bundle.main.url(
            forResource: modelDirectoryName,
            withExtension: nil,
            subdirectory: BorealisAssistant.modelParentName
        ) else { return nil }
        return FileManager.default.fileExists(
            atPath: url.appendingPathComponent("config.json").path
        ) ? url : nil
    }

    /// Lengste tekst som går gjennom i ett stykke, i tokens.
    ///
    /// Lik glidevinduet i modellen. Under den grensen ser hvert lag hele
    /// teksten, og det trengs ingen maske i det hele tatt. `TextSplitter`
    /// lager avsnitt på rundt tusen tegn, altså et par hundre tokens, så
    /// grensen treffes ikke i praksis — den er et gulv under fotavtrykket,
    /// ikke en regel du merker.
    nonisolated static let maximumTokens = 1_024

    /// Én vektor per tekst, normalisert til lengde 1, så prikkproduktet mellom
    /// to av dem er cosinus.
    func embed(_ texts: [String]) async throws -> [[Float]] {
        guard let directory = Self.modelDirectory else {
            throw AssistantError.modelMissing
        }
        let tokenizer = try await AutoTokenizer.from(modelFolder: directory)
        let model = try Self.load(from: directory)
        defer {
            // Vektene forsvinner med modellen; bufferen MLX holder på GPU-en
            // gjør det ikke uten at noen sier fra.
            MLX.GPU.clearCache()
        }

        return texts.map { text in
            let ids = Array(
                tokenizer.encode(text: text, addSpecialTokens: true).prefix(Self.maximumTokens)
            )
            let vector = model(MLXArray(ids.map(Int32.init)))
            return vector.asArray(Float.self)
        }
    }

    private static func load(from directory: URL) throws -> EmbedderModel {
        let data = try Data(contentsOf: directory.appendingPathComponent("config.json"))
        let decoder = JSONDecoder()
        let configuration = try decoder.decode(EmbedderConfiguration.self, from: data)
        let base = try decoder.decode(BaseConfiguration.self, from: data)
        let model = EmbedderModel(configuration)
        try loadWeights(modelDirectory: directory, model: model, quantization: base.quantization)
        return model
    }
}

// MARK: - Modellen

/// Nøklene slik `Scripts/fetch-model.sh` flater dem ut. Kildens `config.json`
/// har `rope_parameters` og `_sliding_window_pattern`, som verken mlx_lm eller
/// dette leser.
struct EmbedderConfiguration: Codable {
    let hiddenSize: Int
    let hiddenLayers: Int
    let intermediateSize: Int
    let attentionHeads: Int
    let headDim: Int
    let rmsNormEps: Float
    let vocabularySize: Int
    let ropeTheta: Float
    let ropeLocalBaseFreq: Float
    let queryPreAttnScalar: Float
    let slidingWindowPattern: Int

    enum CodingKeys: String, CodingKey {
        case hiddenSize = "hidden_size"
        case hiddenLayers = "num_hidden_layers"
        case intermediateSize = "intermediate_size"
        case attentionHeads = "num_attention_heads"
        case headDim = "head_dim"
        case rmsNormEps = "rms_norm_eps"
        case vocabularySize = "vocab_size"
        case ropeTheta = "rope_theta"
        case ropeLocalBaseFreq = "rope_local_base_freq"
        case queryPreAttnScalar = "query_pre_attn_scalar"
        case slidingWindowPattern = "sliding_window_pattern"
    }
}

/// Gemma 3-ryggraden med middelverdi over tokens på toppen. Vektnavnene
/// følger sjekkpunktet, så `loadWeights` finner dem uten omskriving.
private final class EmbedderModel: Module, BaseLanguageModel {
    @ModuleInfo(key: "model") var backbone: Backbone

    init(_ configuration: EmbedderConfiguration) {
        self._backbone.wrappedValue = Backbone(configuration)
        super.init()
    }

    /// Én sekvens inn, én normalisert vektor ut.
    func callAsFunction(_ tokens: MLXArray) -> MLXArray {
        let hidden = backbone(tokens.reshaped(1, -1))
        let pooled = hidden.mean(axis: 1)[0]
        let normalized = pooled.asType(.float32)
        return normalized / sqrt((normalized * normalized).sum())
    }
}

private final class Backbone: Module {
    @ModuleInfo(key: "embed_tokens") var embedTokens: Embedding
    @ModuleInfo var layers: [Block]
    @ModuleInfo var norm: Gemma.RMSNorm

    private let scale: Float

    init(_ configuration: EmbedderConfiguration) {
        self._embedTokens.wrappedValue = Embedding(
            embeddingCount: configuration.vocabularySize, dimensions: configuration.hiddenSize
        )
        self._layers.wrappedValue = (0 ..< configuration.hiddenLayers).map { index in
            Block(configuration, isSliding: (index + 1) % configuration.slidingWindowPattern != 0)
        }
        self._norm.wrappedValue = Gemma.RMSNorm(
            dimensions: configuration.hiddenSize, eps: configuration.rmsNormEps
        )
        self.scale = sqrt(Float(configuration.hiddenSize))
        super.init()
    }

    func callAsFunction(_ tokens: MLXArray) -> MLXArray {
        var hidden = embedTokens(tokens)
        // Gemma skalerer i bfloat16 og runder dermed 27,71 til 27,75. Samme
        // avrunding her, ellers avviker vektorene fra referansen.
        hidden = hidden * MLXArray(scale, dtype: .bfloat16).asType(hidden.dtype)
        for layer in layers {
            hidden = layer(hidden)
        }
        return norm(hidden)
    }
}

private final class Block: Module {
    @ModuleInfo(key: "self_attn") var attention: Attention
    @ModuleInfo var mlp: MLP
    @ModuleInfo(key: "input_layernorm") var inputNorm: Gemma.RMSNorm
    @ModuleInfo(key: "post_attention_layernorm") var postAttentionNorm: Gemma.RMSNorm
    @ModuleInfo(key: "pre_feedforward_layernorm") var preFeedforwardNorm: Gemma.RMSNorm
    @ModuleInfo(key: "post_feedforward_layernorm") var postFeedforwardNorm: Gemma.RMSNorm

    init(_ configuration: EmbedderConfiguration, isSliding: Bool) {
        let size = configuration.hiddenSize
        let eps = configuration.rmsNormEps
        self._attention.wrappedValue = Attention(configuration, isSliding: isSliding)
        self._mlp.wrappedValue = MLP(dimensions: size, hiddenDimensions: configuration.intermediateSize)
        self._inputNorm.wrappedValue = Gemma.RMSNorm(dimensions: size, eps: eps)
        self._postAttentionNorm.wrappedValue = Gemma.RMSNorm(dimensions: size, eps: eps)
        self._preFeedforwardNorm.wrappedValue = Gemma.RMSNorm(dimensions: size, eps: eps)
        self._postFeedforwardNorm.wrappedValue = Gemma.RMSNorm(dimensions: size, eps: eps)
        super.init()
    }

    func callAsFunction(_ x: MLXArray) -> MLXArray {
        let attended = postAttentionNorm(attention(inputNorm(x)))
        let h = Gemma.clipResidual(x, attended)
        let fed = postFeedforwardNorm(mlp(preFeedforwardNorm(h)))
        return Gemma.clipResidual(h, fed)
    }
}

private final class Attention: Module {
    @ModuleInfo(key: "q_proj") var queryProj: Linear
    @ModuleInfo(key: "k_proj") var keyProj: Linear
    @ModuleInfo(key: "v_proj") var valueProj: Linear
    @ModuleInfo(key: "o_proj") var outputProj: Linear
    @ModuleInfo(key: "q_norm") var queryNorm: Gemma.RMSNorm
    @ModuleInfo(key: "k_norm") var keyNorm: Gemma.RMSNorm
    @ModuleInfo var rope: RoPE

    private let heads: Int
    private let scale: Float

    init(_ configuration: EmbedderConfiguration, isSliding: Bool) {
        let size = configuration.hiddenSize
        let headDim = configuration.headDim
        self.heads = configuration.attentionHeads
        self.scale = pow(configuration.queryPreAttnScalar, -0.5)
        self._queryProj.wrappedValue = Linear(size, heads * headDim, bias: false)
        self._keyProj.wrappedValue = Linear(size, heads * headDim, bias: false)
        self._valueProj.wrappedValue = Linear(size, heads * headDim, bias: false)
        self._outputProj.wrappedValue = Linear(heads * headDim, size, bias: false)
        self._queryNorm.wrappedValue = Gemma.RMSNorm(dimensions: headDim, eps: configuration.rmsNormEps)
        self._keyNorm.wrappedValue = Gemma.RMSNorm(dimensions: headDim, eps: configuration.rmsNormEps)
        self._rope.wrappedValue = RoPE(
            dimensions: headDim,
            traditional: false,
            base: isSliding ? configuration.ropeLocalBaseFreq : configuration.ropeTheta
        )
        super.init()
    }

    func callAsFunction(_ x: MLXArray) -> MLXArray {
        let (batch, length) = (x.dim(0), x.dim(1))

        var queries = queryProj(x).reshaped(batch, length, heads, -1).transposed(0, 2, 1, 3)
        var keys = keyProj(x).reshaped(batch, length, heads, -1).transposed(0, 2, 1, 3)
        let values = valueProj(x).reshaped(batch, length, heads, -1).transposed(0, 2, 1, 3)

        queries = rope(queryNorm(queries))
        keys = rope(keyNorm(keys))

        // Ingen maske: hvert token ser hele teksten, begge veier. Det er
        // dette som skiller en innebygging fra en språkmodell.
        let output = MLXFast.scaledDotProductAttention(
            queries: queries, keys: keys, values: values, scale: scale, mask: nil
        )
        .transposed(0, 2, 1, 3)
        .reshaped(batch, length, -1)

        return outputProj(output)
    }
}

private final class MLP: Module {
    @ModuleInfo(key: "gate_proj") var gateProj: Linear
    @ModuleInfo(key: "down_proj") var downProj: Linear
    @ModuleInfo(key: "up_proj") var upProj: Linear

    init(dimensions: Int, hiddenDimensions: Int) {
        self._gateProj.wrappedValue = Linear(dimensions, hiddenDimensions, bias: false)
        self._downProj.wrappedValue = Linear(hiddenDimensions, dimensions, bias: false)
        self._upProj.wrappedValue = Linear(dimensions, hiddenDimensions, bias: false)
        super.init()
    }

    func callAsFunction(_ x: MLXArray) -> MLXArray {
        // silu, ikke GELU. Sjekkpunktet sier det selv i `hidden_activation`.
        downProj(silu(gateProj(x)) * upProj(x))
    }
}
