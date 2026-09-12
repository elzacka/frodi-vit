import Foundation
import Testing
@testable import FrodiVit

/// Holder Swift-ryggraden opp mot vektorer regnet i Python fra fp32-vektene,
/// tosidig og med silu. Avviker de, er det ryggraden som er feil — ikke
/// modellen.
///
/// Fasiten ligger i `Fixtures/embedder-reference.json`, laget 12. september
/// 2026 med `mlx_lm` og de originale vektene fra Nasjonalbiblioteket. Åtte
/// avsnitt, sju spørsmål med hvert sitt riktige avsnitt.
///
/// Kan ikke kjøres i simulatoren: MLX får ikke laget en Metal-enhet der og
/// avbryter før første token. Derfor kompileres den bare for enhet.
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
            // 8-bit vekter og float16-aktiveringer mot fp32. Målt 0,9997 i
            // Python; 0,99 er der en feil i ryggraden ville vist seg.
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
