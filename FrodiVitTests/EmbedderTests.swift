import Foundation
import Testing
@testable import FrodiVit

/// Holds the Swift backbone against vectors computed in Python from the fp32
/// weights, bidirectional and with silu. If they deviate, the backbone is wrong,
/// not the model.
///
/// The reference lives in `Fixtures/embedder-reference.json`, made on
/// 12 September 2026 with `mlx_lm` and the original weights from the National
/// Library. Eight paragraphs, seven questions each with its correct paragraph.
///
/// Cannot run in the simulator: MLX cannot create a Metal device there and
/// aborts before the first token. So it is compiled for device only.
#if !targetEnvironment(simulator)
@Suite("Innebygging", .enabled(if: BorealisEmbedder.isBundled))
struct EmbedderTests {
    struct Reference: Decodable {
        struct Query: Decodable {
            let text: String
            let expected: Int
        }
        let passages: [String]
        let queries: [Query]
        let vectors: [[Float]]
    }

    private final class Anchor {}

    private static func reference() throws -> Reference {
        let url = try #require(
            Bundle(for: Anchor.self).url(forResource: "embedder-reference", withExtension: "json")
        )
        return try JSONDecoder().decode(Reference.self, from: Data(contentsOf: url))
    }

    @Test("Vektorene stemmer med Python-referansen")
    func vectorsMatchReference() async throws {
        let reference = try Self.reference()
        let texts = reference.passages + reference.queries.map(\.text)
        let vectors = try await BorealisEmbedder().embed(texts)

        #expect(vectors.count == reference.vectors.count)
        for (ours, theirs) in zip(vectors, reference.vectors) {
            #expect(ours.count == 768)
            // 8-bit weights and float16 activations against fp32. Measured 0.9997 in
            // Python; 0.99 is where a fault in the backbone would show.
            #expect(Retrieval.cosine(ours, theirs) > 0.99)
        }
    }

    @Test("Hvert spørsmål finner sitt avsnitt")
    func everyQueryFindsItsPassage() async throws {
        let reference = try Self.reference()
        let embedder = BorealisEmbedder()
        let passages = try await embedder.embed(reference.passages)
        let queries = try await embedder.embed(reference.queries.map(\.text))

        for (query, vector) in zip(reference.queries, queries) {
            let best = passages.indices.max {
                Retrieval.cosine(vector, passages[$0]) < Retrieval.cosine(vector, passages[$1])
            }
            #expect(best == query.expected, "«\(query.text)»")
        }
    }
}
#endif
