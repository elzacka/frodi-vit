import Foundation
import MLX
import MLXLMCommon
import MLXNN
import Tokenizers

/// Turns text into vectors with borealis-embed-212m, run in the app with MLX.
///
/// This is the retrieval: a question and a paragraph about the same thing get
/// vectors pointing the same way, and the cosine between them says how alike.
/// See `Retrieval` for the selection; only the vectors are made here.
///
/// **The model is deliberately not run through `MLXEmbedders.EmbeddingGemma`.**
/// That class computes causally and with GELU, like ordinary Gemma 3. This model
/// is trained bidirectionally (`use_bidirectional_attention: true`) and with silu
/// (`hidden_activation: "silu"`), and the two differ. Measured 12 September 2026
/// on eight Norwegian paragraphs and seven questions:
///
/// | Attention | Correct of 7 | Margin to runner-up |
/// |---|---|---|
/// | Causal, GELU | 6 | 0.106 |
/// | Bidirectional, silu | 7 | 0.210 |
///
/// Nor are the vectors from the two readings the same: cosine around 0.7 for
/// the same text. So the backbone below is written out here, with the two
/// differences in place, and `EmbedderTests` holds it against vectors computed
/// in Python from the fp32 weights.
///
/// The weights are loaded on every call and released afterwards. 236 MB should
/// not sit beside the answer model's two gigabytes while you read an answer;
/// that is where the margin against jetsam is smallest.
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

    /// The longest text that goes through in one piece, in tokens.
    ///
    /// Equal to the model's sliding window. Below that limit every layer sees the
    /// whole text, and no mask is needed at all. `TextSplitter` makes passages of
    /// about a thousand characters, a couple of hundred tokens, so the limit is not
    /// hit in practice; it is a floor under the footprint, not a rule you notice.
    nonisolated static let maximumTokens = 1_024

    /// Texts are padded to the nearest multiple of this before they go in, so the
    /// model sees few distinct lengths.
    ///
    /// Metal keeps memory for every new shape it computes on, and releases it only
    /// when the model is gone. Measured on a device on 12 September 2026 with 46
    /// passages in 46 lengths: 1 100 MB above the weights while embedding ran, and
    /// 2 MB when the same 46 lengths came again. With the answer model already in
    /// memory, 1 100 MB is more than the device has left. Sixteen shapes instead of
    /// hundreds keeps it down.
    nonisolated static let lengthStep = 64

    /// `pad_token_id` in config.json. The padding tokens are masked out of the
    /// attention and not counted in the mean, so the result is the same as
    /// without padding.
    nonisolated static let padToken: Int32 = 3

    /// One vector per text, normalised to length 1, so the dot product between
    /// two of them is the cosine.
    func embed(_ texts: [String]) async throws -> [[Float]] {
        guard let directory = Self.modelDirectory else {
            throw AssistantError.modelMissing
        }
        let vectors = try await Self.run(texts, from: directory)
        // The weights are released once `run` has returned. MLX has then put the
        // buffers they lived in into its own queue for reuse, and they do not go away
        // unless told. Measured on a device on 12 September 2026: 290 MB stayed behind
        // when this sat in a `defer`, which runs before the model is gone.
        MLX.GPU.clearCache()
        return vectors
    }

    private static func run(_ texts: [String], from directory: URL) async throws -> [[Float]] {
        let tokenizer = try await AutoTokenizer.from(modelFolder: directory)
        let model = try load(from: directory)
        return texts.map { text in
            let ids = tokenizer.encode(text: text, addSpecialTokens: true)
                .prefix(maximumTokens)
                .map(Int32.init)
            let padded = (ids.count + lengthStep - 1) / lengthStep * lengthStep
            let filled = ids + Array(repeating: padToken, count: padded - ids.count)
            return model(MLXArray(filled), length: ids.count).asArray(Float.self)
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

// MARK: - The model
/// The keys as `Scripts/fetch-model.sh` flattens them. The source `config.json`
/// has `rope_parameters` and `_sliding_window_pattern`, which neither mlx_lm nor
/// this reads.
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

/// The Gemma 3 backbone with mean pooling over tokens on top. The weight names
/// follow the checkpoint, so `loadWeights` finds them without rewriting.
private final class EmbedderModel: Module, BaseLanguageModel {
    @ModuleInfo(key: "model") var backbone: Backbone

    init(_ configuration: EmbedderConfiguration) {
        self._backbone.wrappedValue = Backbone(configuration)
        super.init()
    }

    /// One sequence in, one normalised vector out. `length` is the number of real
    /// tokens; the rest is padding kept out of both the attention and the mean.
    func callAsFunction(_ tokens: MLXArray, length: Int) -> MLXArray {
        let total = tokens.dim(0)
        let mask: MLXArray? = length < total
            ? MLXArray(
                (0 ..< total).map { $0 < length ? Float(0) : -Float.infinity }
            ).reshaped(1, 1, 1, total)
            : nil
        let hidden = backbone(tokens.reshaped(1, -1), mask: mask)
        let pooled = hidden[0, 0 ..< length].mean(axis: 0)
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

    func callAsFunction(_ tokens: MLXArray, mask: MLXArray?) -> MLXArray {
        var hidden = embedTokens(tokens)
        // Gemma scales in bfloat16 and thereby rounds 27.71 to 27.75. The same
        // rounding here, or the vectors deviate from the reference.
        hidden = hidden * MLXArray(scale, dtype: .bfloat16).asType(hidden.dtype)
        let typedMask = mask?.asType(hidden.dtype)
        for layer in layers {
            hidden = layer(hidden, mask: typedMask)
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

    func callAsFunction(_ x: MLXArray, mask: MLXArray?) -> MLXArray {
        let attended = postAttentionNorm(attention(inputNorm(x), mask: mask))
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

    func callAsFunction(_ x: MLXArray, mask: MLXArray?) -> MLXArray {
        let (batch, length) = (x.dim(0), x.dim(1))

        var queries = queryProj(x).reshaped(batch, length, heads, -1).transposed(0, 2, 1, 3)
        var keys = keyProj(x).reshaped(batch, length, heads, -1).transposed(0, 2, 1, 3)
        let values = valueProj(x).reshaped(batch, length, heads, -1).transposed(0, 2, 1, 3)

        queries = rope(queryNorm(queries))
        keys = rope(keyNorm(keys))

        // No causal mask: every token sees the whole text, both ways. That is what
        // separates an embedding from a language model. The mask coming in hides only
        // padding tokens.
        let output = MLXFast.scaledDotProductAttention(
            queries: queries, keys: keys, values: values, scale: scale, mask: mask
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
        // silu, not GELU. The checkpoint says so itself in `hidden_activation`.
        downProj(silu(gateProj(x)) * upProj(x))
    }
}
