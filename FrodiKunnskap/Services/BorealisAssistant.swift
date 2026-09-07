import Foundation
import MLXLMCommon
import MLXLLM

/// Svarer med borealis-open-1b, kjørt i appen med MLX.
///
/// Modellen ligger som mappereferanse i app-pakken og lastes derfra. Det
/// finnes ingen nedlastingsvei: `MLXHuggingFace` er ikke lenket inn, så en
/// manglende fil feiler i stedet for å hente.
@MainActor
final class BorealisAssistant: Assistant {
    /// Navnet på mappen `Scripts/fetch-model.sh` legger modellen i.
    ///
    /// Mappereferansen i `project.yml` peker på `Resources/Model`, så hele den
    /// mappen havner i app-pakken med navnet sitt i behold. Modellen ligger
    /// altså under `Model/`, ikke i bunnen av pakken.
    nonisolated static let modelDirectoryName = "borealis-open-1b"
    nonisolated static let modelParentName = "Model"

    /// Lastes ved første spørsmål, ikke ved oppstart. En halv gigabyte vekter
    /// skal ikke ligge i minnet mens du bare ser på en tom samtale.
    private var session: ChatSession?

    /// Finnes modellen i pakken i det hele tatt?
    ///
    /// Uten dette faller appen tilbake på en uforståelig feil fra MLX når
    /// noen har hoppet over `fetch-model.sh`.
    /// Ren filsjekk, uten tilstand, så den kan leses fra hvor som helst —
    /// blant annet fra testene, som ikke kjører på hovedaktøren.
    nonisolated static var isBundled: Bool {
        modelDirectory != nil
    }

    nonisolated static var modelDirectory: URL? {
        guard let url = Bundle.main.url(
            forResource: modelDirectoryName,
            withExtension: nil,
            subdirectory: modelParentName
        ) else { return nil }
        // Mappen kan finnes uten å være komplett, om et skript ble avbrutt.
        // Da er det ærligere å si at modellen mangler.
        return FileManager.default.fileExists(
            atPath: url.appendingPathComponent("config.json").path
        ) ? url : nil
    }

    /// Systemledetekst. Norsk, og på bokmål.
    ///
    /// Modellen er norskspreget fra før, så dette er en dytt, ikke en garanti.
    /// Vi avviser ikke svar som kommer på feil språk, slik tale til tekst-appen
    /// avviser feil språkmodell: der gir feil språk uforståelig tekst, her ville
    /// et avvist svar bare etterlate deg med ingenting.
    private static let instructions = """
        Du er Fróði, en hjelpsom assistent som svarer på norsk bokmål.
        Svar kort og klart. Er du usikker, si det heller enn å gjette.
        """

    func answer(to question: String, given context: [String]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task { @MainActor in
                do {
                    let session = try await session(for: context)
                    for try await piece in session.streamResponse(to: question) {
                        continuation.yield(piece)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: Self.translate(error))
                }
            }
        }
    }

    /// Én økt gjenbrukes på tvers av spørsmål, slik at MLX beholder KV-bufferet
    /// og ikke leser hele samtalen om igjen for hvert svar.
    private func session(for context: [String]) async throws -> ChatSession {
        if let session { return session }

        guard let directory = Self.modelDirectory else {
            throw AssistantError.modelMissing
        }

        let model = try await loadModelContainer(
            from: directory, using: LocalTokenizerLoader()
        )
        let session = ChatSession(model, instructions: Self.instructions)
        self.session = session
        return session
    }

    /// MLX melder tomt minne som en vanlig feil. Skjermen skal si hva du kan
    /// gjøre med det, ikke gjengi meldingen fra rammeverket.
    private static func translate(_ error: Error) -> Error {
        if error is AssistantError { return error }
        let text = error.localizedDescription.lowercased()
        if text.contains("memory") || text.contains("allocat") {
            return AssistantError.outOfMemory
        }
        return AssistantError.underlying(error.localizedDescription)
    }
}
