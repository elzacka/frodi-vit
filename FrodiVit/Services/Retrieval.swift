import Foundation
import SwiftData

/// Velger utdragene som gjelder spørsmålet, innenfor tegnbudsjettet.
///
/// Rent regnestykke, uten modell og uten base, så det lar seg teste med tall.
/// `Grounding` under er delen som snakker med begge.
enum Retrieval {
    struct Candidate {
        let vector: [Float]
        let length: Int
    }

    nonisolated static func cosine(_ a: [Float], _ b: [Float]) -> Float {
        zip(a, b).reduce(0) { $0 + $1.0 * $1.1 }
    }

    /// Plassene til de valgte kandidatene, i den rekkefølgen de kom inn.
    ///
    /// Beste først, så lenge det er plass, og det som ikke får plass hoppes
    /// over til fordel for et kortere utdrag lenger ned. Rekkefølgen ut er
    /// den opprinnelige, ikke etter poeng: modellen skal lese dokumentet slik
    /// det står, ikke stokket etter hvor mye hvert stykke ligner spørsmålet.
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

/// Det et svar bygger på: utdragene, og navnene på dokumentene de kom fra.
struct GroundingContext {
    var texts: [String] = []
    var sources: [String] = []
}

/// Binder gjenfinningen til basen og modellen.
///
/// Et dokument uten utdrag — lastet opp før gjenfinningen fantes, eller mens
/// appen ble lukket midt i — deles og innebygges her først. Én vei inn, uansett
/// hvordan dokumentet kom dit.
@MainActor
enum Grounding {
    private static let embedder = BorealisEmbedder()

    /// Deler dokumentet og lagrer én vektor per utdrag. Gjør ingenting om det
    /// alt er gjort.
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

    /// Utdragene som gjelder spørsmålet, i dokumentrekkefølge.
    ///
    /// Uten gjenfinningsmodell i pakken går hele tekstene videre som før, og
    /// `BorealisAssistant.prompt` kutter dem mot budsjettet. Da står det ingen
    /// kilde under svaret — det ville vært å påstå et utvalg som ikke er gjort.
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
