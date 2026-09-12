import Foundation
import SwiftData

/// Picks the passages relevant to the question, within the character budget.
///
/// Pure arithmetic, with no model and no store, so it can be tested with numbers.
/// `Grounding` below is the part that talks to both.
enum Retrieval {
    struct Candidate {
        let vector: [Float]
        let length: Int
    }

    nonisolated static func cosine(_ a: [Float], _ b: [Float]) -> Float {
        zip(a, b).reduce(0) { $0 + $1.0 * $1.1 }
    }

    /// The positions of the chosen candidates, in the order they came in.
    ///
    /// Best first, as long as there is room, and what does not fit is skipped in
    /// favour of a shorter passage further down. The order out is the original one,
    /// not by score: the model should read the document as it stands, not shuffled
    /// by how much each piece resembles the question.
    nonisolated static func select(
        query: [Float], from candidates: [Candidate], budget: Int
    ) -> [Int] {
        let ranked = candidates.indices.sorted {
            cosine(query, candidates[$0].vector) > cosine(query, candidates[$1].vector)
        }
        var chosen: [Int] = []
        var used = 0
        for index in ranked where used + candidates[index].length <= budget {
            chosen.append(index)
            used += candidates[index].length
        }
        return chosen.sorted()
    }
}

/// What an answer builds on: the passages, and the names of the documents they came from.
struct GroundingContext {
    var texts: [String] = []
    var sources: [String] = []
}

/// Binds retrieval to the store and the model.
///
/// A document without passages — uploaded before retrieval existed, or while the
/// app was closed midway — is split and embedded here first. One way in, however
/// the document got there.
@MainActor
enum Grounding {
    private static let embedder = BorealisEmbedder()

    /// Splits the document and stores one vector per passage. Does nothing if it
    /// is already done.
    static func index(_ document: Document, in context: ModelContext) async throws {
        guard document.passages.isEmpty, BorealisEmbedder.isBundled else { return }
        let pieces = TextSplitter.split(try document.text())
        let vectors = try await embedder.embed(pieces)
        for (index, (piece, vector)) in zip(pieces, vectors).enumerated() {
            let passage = try Passage(index: index, text: piece, vector: vector)
            passage.document = document
            context.insert(passage)
        }
        try context.save()
    }

    /// The passages relevant to the question, in document order.
    ///
    /// Without a retrieval model in the bundle the whole texts go on as before, and
    /// `BorealisAssistant.prompt` cuts them against the budget. Then no source is
    /// shown under the answer; that would be claiming a selection that was not made.
    static func context(
        for question: String, documents: [Document], in context: ModelContext
    ) async throws -> GroundingContext {
        guard !documents.isEmpty else { return GroundingContext() }
        guard BorealisEmbedder.isBundled else {
            return GroundingContext(texts: documents.compactMap { try? $0.text() })
        }

        for document in documents {
            try await index(document, in: context)
        }

        let passages = documents.flatMap { document in
            document.passages.sorted { $0.index < $1.index }
        }
        let query = try await embedder.embed([question])[0]
        let candidates = passages.map { passage in
            Retrieval.Candidate(vector: passage.floats, length: passage.characterCount)
        }
        let chosen = Retrieval.select(
            query: query, from: candidates, budget: BorealisAssistant.contextCharacterLimit
        )

        var result = GroundingContext()
        for index in chosen {
            let passage = passages[index]
            result.texts.append(try passage.text())
            if let name = passage.document?.name, !result.sources.contains(name) {
                result.sources.append(name)
            }
        }
        return result
    }
}
